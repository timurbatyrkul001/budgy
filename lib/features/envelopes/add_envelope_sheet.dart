import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_avatar.dart';
import '../../core/category_catalog.dart';
import '../../core/category_visual.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import 'budget_repository.dart';
import 'envelope.dart';
import 'envelope_l10n.dart';

const _emojis = [
  // Ev & faturalar
  '🏠', '🏡', '🔌', '💡', '🧾', '📱', '🌐',
  // Yeme-içme
  '🍔', '🍕', '🍽️', '☕', '🍻', '🍷', '🥗', '🍫', '🥐',
  // Dışarı / eğlence
  '🎬', '🍿', '🎮', '🎸', '🎤', '🎉', '❤️', '🌹', '🎢', '🎳',
  // Alışveriş & kişisel
  '🛍️', '👕', '👗', '👟', '💄', '💇', '⌚',
  // Sağlık & spor
  '💊', '🏥', '🦷', '💪', '⚽', '🚴',
  // Ulaşım & seyahat
  '✈️', '🚗', '⛽', '🚕', '🚌', '🏖️', '🏨',
  // Eğitim & iş
  '📚', '💻', '✏️',
  // Aile & evcil
  '🎁', '🧸', '🍼', '🐶', '🐱',
  // Para & birikim
  '💰', '💵', '🏦', '💳', '📈',
];

/// Yeni kategori (zarf). Para birimi seçilmez — döviz cüzdanları
/// showCurrencyWalletSheet ile açılır.
/// [initialSection]: bölüm önceden seçili (gelir seçicisinden "+ Yeni").
Future<void> showAddEnvelopeSheet(BuildContext context, int sortOrder,
        {String? initialSection}) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EnvelopeEditorScreen(
          sortOrder: sortOrder, previewSection: initialSection),
    ));

/// Var olanı düzenle (ad / emoji / renk / bölüm). Para birimine dokunmaz —
/// döviz cüzdanları da buradan düzenlenir, bölüm satırı onlarda gizlidir.
Future<void> showEditEnvelopeSheet(BuildContext context, Envelope envelope) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EnvelopeEditorScreen(sortOrder: 0, envelope: envelope),
    ));

/// Tam ekran kategori düzenleyici: büyük avatar (emoji ya da baş harf,
/// seçili renk) + kalem rozeti → emoji ızgarası ("baş harfi kullan" en
/// üstte); ad alanı + sağında renk noktası → 12 tonluk palet; bölüm satırı
/// → alt sayfa (Bölümsüz + katalog bölümleri); altta Oluştur / Kaydet.
class EnvelopeEditorScreen extends ConsumerStatefulWidget {
  const EnvelopeEditorScreen({
    super.key,
    required this.sortOrder,
    this.envelope,
    this.previewName,
    this.previewEmoji,
    this.previewColorIndex,
    this.previewSection,
    this.autoOpenSection = false,
  });

  final int sortOrder;
  final Envelope? envelope;

  // Önizleme/test başlangıç değerleri.
  final String? previewName;
  final String? previewEmoji;
  final int? previewColorIndex;
  final String? previewSection;
  final bool autoOpenSection;

  @override
  ConsumerState<EnvelopeEditorScreen> createState() => _EnvelopeEditorScreenState();
}

class _EnvelopeEditorScreenState extends ConsumerState<EnvelopeEditorScreen> {
  late final _name = TextEditingController(
      text: widget.previewName ??
          widget.envelope?.displayName(ref.read(strProvider)) ??
          '');
  late String _emoji = widget.previewEmoji ?? widget.envelope?.emoji ?? '';
  late Color _color = widget.previewColorIndex != null
      ? CategoryPalette.all[widget.previewColorIndex!]
      : widget.envelope != null
          ? envelopeColor(widget.envelope!)
          : CategoryPalette.all[widget.sortOrder % CategoryPalette.all.length];
  late String? _section = widget.previewSection ??
      (widget.envelope == null ? null : envelopeSection(widget.envelope!));
  bool _saving = false;

  bool get _isEditing => widget.envelope != null;
  bool get _isWallet => (widget.envelope?.currency ?? 'TRY') != 'TRY';

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    if (widget.autoOpenSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickSection());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final rs = ref.read(rsProvider);
    final picked = await showExSheet<String>(
      context,
      SheetFrame(
        title: rs.chooseEmoji,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExCard(
              onTap: () => Navigator.of(context).pop(''),
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.text_fields_rounded, size: 20, color: Ex.mint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(rs.useLetter,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: Ex.text)),
                  ),
                  if (_emoji.isEmpty)
                    const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojis)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(e),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == _emoji ? Ex.brand.withValues(alpha: 0.22) : Ex.surfaceHi,
                        shape: BoxShape.circle,
                        border: e == _emoji ? Border.all(color: Ex.brand, width: 2) : null,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _emoji = picked);
  }

  Future<void> _pickColor() async {
    final rs = ref.read(rsProvider);
    final picked = await showExSheet<Color>(
      context,
      SheetFrame(
        title: rs.color,
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final c in CategoryPalette.all)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(c),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: c == _color ? Border.all(color: Colors.white, width: 3) : null,
                  ),
                  child: c == _color
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _color = picked);
  }

  Future<void> _pickSection() async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final options = <(String?, String)>[
      (null, rs.noSection),
      for (final s in kCategoryCatalog) (s.key, s.title(str.localeCode)),
    ];
    final picked = await showExSheet<(String?,)>(
      context,
      SheetFrame(
        title: rs.sectionLabel,
        child: Column(
          children: [
            for (final (key, label) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExCard(
                  onTap: () => Navigator.of(context).pop((key,)),
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: key == _section ? Ex.mint : Ex.text)),
                      ),
                      if (key == _section)
                        const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _section = picked.$1);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final str = ref.read(strProvider);
    final colorIndex = paletteIndexOf(_color);
    final ok = await guardWrite(context, str, () async {
      final e = widget.envelope;
      if (e == null) {
        await repo.addEnvelope(name, _emoji, widget.sortOrder,
            section: _section, colorIndex: colorIndex);
      } else {
        await repo.updateEnvelope(
          e.id,
          name: name,
          emoji: _emoji,
          section: _isWallet ? null : _section,
          colorIndex: colorIndex,
          // Adı değiştiyse artık "kendi" kategorisi (dil değişince ezilmesin).
          dropPreset: e.presetKey != null && name != e.displayName(str),
        );
      }
    }, reason: 'saveEnvelope');
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final name = _name.text.trim();
    final sectionLabel = switch (_section) {
      null => rs.noSection,
      final k => kCategoryCatalog
              .where((s) => s.key == k)
              .firstOrNull
              ?.title(str.localeCode) ??
          rs.noSection,
    };
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Önizleme avatarı: emoji ya da baş harf, seçili renkte.
    final preview = Envelope(
      id: widget.envelope?.id ?? 'new',
      name: name.isEmpty ? '?' : name,
      emoji: _emoji,
      balance: 0,
      sortOrder: 0,
      colorIndex: paletteIndexOf(_color),
    );

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassSquareButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Text(
                        _isEditing ? rs.editCategoryTitle : rs.newCategoryTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: Ex.text)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CategoryAvatar(envelope: preview, size: 96),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Material(
                            color: Ex.surfaceHi,
                            shape: const CircleBorder(side: BorderSide(color: Ex.bg, width: 3)),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickEmoji,
                              child: const SizedBox(
                                width: 34,
                                height: 34,
                                child: Icon(Icons.edit_rounded, size: 16, color: Ex.text),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name.isEmpty ? rs.categoryName : name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: name.isEmpty ? Ex.textFaint : Ex.text),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          autofocus: !_isEditing && widget.previewName == null,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                          style: const TextStyle(
                              color: Ex.text, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(hintText: rs.categoryName),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Renk noktası → palet.
                      Material(
                        color: Ex.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Ex.iconRadius),
                          side: const BorderSide(color: Ex.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _pickColor,
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Center(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration:
                                    BoxDecoration(color: _color, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isWallet) ...[
                    const SizedBox(height: 16),
                    ExCard(
                      onTap: _pickSection,
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          Text(rs.sectionLabel,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Ex.text)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(sectionLabel,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _section == null ? Ex.textMuted : Ex.mint)),
                          ),
                          const Icon(Icons.unfold_more_rounded, size: 20, color: Ex.textMuted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(rs.sectionHint,
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.35, color: Ex.textMuted)),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 12 + bottom),
              child: PrimaryButton(
                label: _isEditing ? rs.save : str.create,
                onTap: name.isEmpty || _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
