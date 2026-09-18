import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ai/expense_parser.dart';
import '../../core/category_avatar.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';

/// Fiş tarama: kaynak seç (kamera/galeri) → fotoğraf → AI ile oku →
/// önizle → kaydet. Anahtar yoksa kısa bir uyarı gösterip çıkar.
Future<void> startReceiptScan(BuildContext context, WidgetRef ref) async {
  final rs = ref.read(rsProvider);
  if (!ExpenseParser.aiAvailable) {
    showErrorSnack(context, rs.aiKeyMissing);
    return;
  }
  final source =
      await showExSheet<ImageSource>(context, const _SourcePicker());
  if (source == null || !context.mounted) return;

  XFile? file;
  try {
    file = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
  } catch (_) {
    if (context.mounted) showErrorSnack(context, rs.scanFailed);
    return;
  }
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  final mediaType =
      file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  if (!context.mounted) return;
  await showExSheet(context, _ReceiptSheet(bytes: bytes, mediaType: mediaType));
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
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final str = ref.read(strProvider);
    final envelopes = ref
        .read(allocatableEnvelopesProvider)
        .forParser((e) => e.displayName(str));
    try {
      final items = await ExpenseParser().parseReceipt(
        widget.bytes,
        mediaType: widget.mediaType,
        envelopes: envelopes,
        languageCode: str.localeCode,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _failed = items.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
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
                child: _items == null && !_failed
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
                        _failed ? rs.scanFailed : '',
                        style: const TextStyle(fontSize: 15, color: Ex.red),
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
