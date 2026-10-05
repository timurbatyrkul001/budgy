import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/ai/expense_parser.dart';
import '../../core/category_avatar.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/image_picking.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../pro/pro_state.dart';

// [imagePickerProvider] ve [pickerErrorMessage] core/image_picking.dart'a
// taşındı (avatar fotoğrafı da kullanıyor; AI bayrağından bağımsız). Eski
// içe aktaranlar bozulmasın diye buradan yeniden dışa açılıyor.
export '../../core/image_picking.dart'
    show imagePickerProvider, pickerErrorMessage;

/// Fiş okuyucu — gerçekte [ExpenseParser]; testte sahte (hak bitti, ağ
/// yok gibi hataları fırlatmak için).
final receiptParserProvider = Provider<ExpenseParser>((_) => ExpenseParser());

/// Fiş tarama: kaynak seç (kamera/galeri) → fotoğraf → AI ile oku →
/// önizle → kaydet. Giriş yoksa kısa bir uyarı gösterip çıkar.
Future<void> startReceiptScan(BuildContext context, WidgetRef ref) async {
  // 1.0: AI kapalı — sessizce çık. Uyarı yok, "yakında" yok: kullanıcı
  // özelliğin varlığını öğrenmemeli. "+" sayfası kartı zaten çizmiyor; bu
  // ikinci kilit. Bkz. pro_state.dart, kAiEnabled.
  if (!kAiEnabled) return;
  final rs = ref.read(rsProvider);
  if (!ExpenseParser.aiAvailable) {
    showErrorSnack(context, rs.aiKeyMissing);
    return;
  }
  await pickAndScanReceipt(context, ref);
}

/// [startReceiptScan]'ın giriş kapısından sonraki kısmı: kaynak seç →
/// fotoğraf al → tarama sayfası. Ayrı tutuldu ki testte AI girişi
/// olmadan da akış (izin reddi metinleri, AI hataları) sınanabilsin.
@visibleForTesting
Future<void> pickAndScanReceipt(BuildContext context, WidgetRef ref) async {
  final source =
      await showExSheet<ImageSource>(context, const _SourcePicker());
  if (source == null || !context.mounted) return;

  XFile? file;
  try {
    file = await ref
        .read(imagePickerProvider)
        .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
  } catch (e) {
    // İzin reddi "fiş okunamadı" DEĞİL — kullanıcı fişi yeniden çekmesin,
    // ayara gitsin. Hangi izin, hangi platform: metin ona göre.
    if (context.mounted) {
      showErrorSnack(
        context,
        pickerErrorMessage(ref.read(rsProvider), e, source),
      );
    }
    return;
  }
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  final mediaType =
      file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  if (!context.mounted) return;
  await showExSheet(context, _ReceiptSheet(bytes: bytes, mediaType: mediaType));
}

/// AI çağrısının hatasını insan diline çevirir. Üç ayrı şey üç ayrı metin:
/// hak bitti (yeniden çekmek işe yaramaz, tarih verilir), ağ/sunucu
/// (sonra dene), giriş yok. Yalnız bilinmeyen hata "fiş okunamadı" olur.
String receiptErrorMessage(RS rs, Object error, String localeCode) {
  if (error is AiLimitReached) {
    final resetsAt = error.resetsAt;
    if (resetsAt == null) return rs.aiLimitReached;
    return tpl(rs.aiLimitResetTpl, {
      'date': DateFormat('d MMMM', localeCode).format(resetsAt.toLocal()),
    });
  }
  if (error is AiNetworkError) return rs.aiNetworkError;
  if (error is AiUnavailable) return rs.aiKeyMissing;
  return rs.scanFailed;
}

class _SourcePicker extends ConsumerWidget {
  const _SourcePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    Widget option(IconData icon, String label, ImageSource source) => ExCard(
          onTap: () => Navigator.of(context).pop(source),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Ex.brand.withValues(alpha: 0.16),
                  borderRadius: Ex.squircle(40),
                ),
                child: Icon(icon, size: 21, color: Ex.mint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Ex.text)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
            ],
          ),
        );
    return SheetFrame(
      title: rs.scanTitle,
      child: Column(
        children: [
          option(Icons.photo_camera_rounded, rs.camera, ImageSource.camera),
          const SizedBox(height: 10),
          option(Icons.photo_library_rounded, rs.gallery, ImageSource.gallery),
        ],
      ),
    );
  }
}

class _ReceiptSheet extends ConsumerStatefulWidget {
  const _ReceiptSheet({required this.bytes, required this.mediaType});

  final Uint8List bytes;
  final String mediaType;

  @override
  ConsumerState<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<_ReceiptSheet> {
  List<ParsedItem>? _items;

  /// Okuma bitmedi ya da başarılıysa null; aksi hâlde kullanıcıya
  /// gösterilecek metin (sebebe göre farklı).
  String? _error;

  /// Hata kullanıcının fotoğrafından değil (hak bitti, ağ yok, giriş yok):
  /// kırmızı değil kehribar — "yeniden çek" çağrışımı yapmasın.
  bool _errorIsExternal = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final str = ref.read(strProvider);
    final rs = ref.read(rsProvider);
    final envelopes = ref
        .read(allocatableEnvelopesProvider)
        .forParser((e) => e.displayName(str));
    try {
      final items = await ref.read(receiptParserProvider).parseReceipt(
        widget.bytes,
        mediaType: widget.mediaType,
        envelopes: envelopes,
        languageCode: str.localeCode,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        // Boş liste = AI fotoğrafta toplam bulamadı (fiş değil / bulanık):
        // bu kullanıcının düzeltebileceği bir şey, öyle söylenir.
        _error = items.isEmpty ? rs.scanNoTotal : null;
        _errorIsExternal = false;
      });
    } catch (e) {
      // Hak bitti / ağ yok / giriş yok — hepsi "fiş okunamadı" DEĞİL.
      // Özellikle hak bittiğinde kullanıcı fişi tekrar tekrar çekmesin.
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = receiptErrorMessage(rs, e, str.localeCode);
        _errorIsExternal = e is AiLimitReached ||
            e is AiNetworkError ||
            e is AiUnavailable;
      });
    }
  }

  /// ai_add_sheet ile aynı kayıt yolu: gelir cüzdana, gider kategoriyle.
  Future<void> _save() async {
    final repo = ref.read(budgetRepositoryProvider);
    final str = ref.read(strProvider);
    setState(() => _saving = true);
    try {
      for (final item in _items ?? const <ParsedItem>[]) {
        if (item.kind == 'income') {
          await repo.addCashIncome(
            amount: item.amount,
            note: item.note.isEmpty ? null : item.note,
          );
        } else {
          await repo.addExpense(
            envelopeId: item.envelopeId,
            envelopeName: item.envelopeName,
            amount: item.amount,
            note: item.note.isEmpty ? null : item.note,
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showErrorSnack(context, str.errorSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final items = _items ?? const <ParsedItem>[];

    return SheetFrame(
      title: rs.scanTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(widget.bytes,
                    width: 64, height: 84, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _items == null && _error == null
                    ? Row(
                        children: [
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Ex.mint),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(rs.scanning,
                                style: const TextStyle(
                                    fontSize: 15, color: Ex.textSoft)),
                          ),
                        ],
                      )
                    : Text(
                        _error ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: _errorIsExternal ? Ex.amber : Ex.red,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (i, item) in items.indexed)
            _ItemCard(
              item: item,
              str: str,
              onRemove: () => setState(() => _items = [...items]..removeAt(i)),
            ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: tpl(rs.saveAllTpl, {'n': '${items.length}'}),
            onTap: items.isEmpty || _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// Çözülen tek işlemin önizleme kartı.
class _ItemCard extends ConsumerWidget {
  const _ItemCard({
    required this.item,
    required this.str,
    required this.onRemove,
  });

  final ParsedItem item;
  final Strings str;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = item.kind == 'income';
    final envelope = (ref.watch(envelopesProvider).value ?? const <Envelope>[])
        .where((e) => e.id == item.envelopeId)
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: Ex.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ex.border),
      ),
      child: Row(
        children: [
          if (isIncome)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Ex.income.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.south_west_rounded, size: 20, color: Ex.income),
            )
          else if (envelope != null)
            CategoryAvatar(envelope: envelope, size: 40)
          else
            const CategoryAvatar.none(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isIncome ? '+' : '−'}${formatMoney(item.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isIncome ? Ex.income : Ex.text,
                  ),
                ),
                Text(
                  [
                    if (item.note.isNotEmpty) item.note,
                    if (item.envelopeName != null)
                      item.envelopeName!
                    else if (!isIncome)
                      str.withoutEnvelope,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Ex.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20, color: Ex.textFaint),
          ),
        ],
      ),
    );
  }
}
