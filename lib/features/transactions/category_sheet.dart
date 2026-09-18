import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_avatar.dart';
import '../../core/category_catalog.dart';
import '../../core/category_visual.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/add_envelope_sheet.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';

/// Seçilen kategori (= zarf). Katalogdan seçilen madde ilk kullanımda
/// zarf olarak yaratılır (preset anahtarıyla — dil değişince adı değişir,
/// ikinci kez yaratılmaz).
class CategoryPick {
  const CategoryPick({
    required this.id,
    required this.name,
    required this.emoji,
    this.catalogKey,
  });

  final String id;
  final String name;
  final String emoji;

  /// Katalog/preset anahtarı (renkli simge için); özel kategoride null.
  final String? catalogKey;
}

/// Kategori sayfası: arama üstte, bölüm başlığı kartın DIŞINDA, kart içinde
/// 3'lü satır — büyük renkli daire + altında 2 satıra sarabilen etiket.
/// Önce "Kendi kategorilerin", sonra katalog; altta "+ Yeni kategori".
///
/// Arama referanstaki gibi altta değil: alt sayfada klavye açılınca alttaki
/// alan klavyenin altında kalıyor / sayfayı zıplatıyor; üstte sabit alan
/// klavyeyle çakışmıyor.
Future<CategoryPick?> showCategorySheet(BuildContext context,
        {String? selectedId, double initialScroll = 0}) =>
    showExSheet<CategoryPick>(
        context, _CategorySheet(selectedId: selectedId, initialScroll: initialScroll));

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.selectedId, this.initialScroll = 0});

  final String? selectedId;
  final double initialScroll;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _scroll = ScrollController(initialScrollOffset: widget.initialScroll);
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _matches(String name) =>
      _query.isEmpty || name.toLowerCase().contains(_query.toLowerCase());

  void _pickEnvelope(Envelope e, Strings str) => Navigator.of(context).pop(
      CategoryPick(
          id: e.id, name: e.displayName(str), emoji: e.emoji, catalogKey: e.presetKey));

  /// Katalog maddesi: varsa mevcut zarf, yoksa şimdi yarat.
  Future<void> _pickCatalog(CatalogItem item, List<Envelope> mine) async {
    final str = ref.read(strProvider);
    final existing = mine.where((e) => e.presetKey == item.key).firstOrNull;
    if (existing != null) return _pickEnvelope(existing, str);
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(budgetRepositoryProvider);
    final all = ref.read(envelopesProvider).value ?? const [];
    final name = item.name(str.localeCode);
    try {
      final id = await repo.addPresetEnvelope(
          key: item.key, name: name, emoji: item.emoji, sortOrder: all.length);
      if (mounted) {
        Navigator.of(context).pop(
            CategoryPick(id: id, name: name, emoji: item.emoji, catalogKey: item.key));
      }
    } catch (_) {
      if (mounted) {
        showErrorSnack(context, str.errorSaveFailed);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    // Kullanıcının kategorileri: aktif, hedef olmayan ₺ zarflar.
    final mine = ref.watch(allocatableEnvelopesProvider);
    // Bölümü olan kullanıcı kategorileri o bölümün kartına girer (katalog
    // maddelerinden önce); bölümsüzler "Kendi kategorilerin"de kalır.
    final grouped = groupBySection(mine);
    final mineFiltered =
        (grouped[null] ?? const []).where((e) => _matches(e.displayName(str))).toList();
    final ownedKeys = {for (final e in mine) e.presetKey};

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: SheetFrame(
        title: rs.pickCategory,
        scroll: false,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(color: Ex.text),
              decoration: InputDecoration(
                hintText: rs.searchCategory,
                prefixIcon: const Icon(Icons.search_rounded, color: Ex.textMuted),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (mineFiltered.isNotEmpty)
                    _Section(
                      title: rs.yourCategories,
                      children: [
                        for (final e in mineFiltered)
                          _Tile(
                            avatar: CategoryAvatar(
                                envelope: e, size: 56, selected: e.id == widget.selectedId),
                            label: e.displayName(str),
                            selected: e.id == widget.selectedId,
                            onTap: () => _pickEnvelope(e, str),
                          ),
                      ],
                    ),
                  for (final section in kCategoryCatalog)
                    ..._section(section, ownedKeys, mine,
                        grouped[section.key] ?? const [], str),
                  const SizedBox(height: 4),
                  GhostButton(
                    label: rs.newCategory,
                    onTap: () => showAddEnvelopeSheet(
                        context, ref.read(envelopesProvider).value?.length ?? 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(CatalogSection section, Set<String?> ownedKeys,
      List<Envelope> mine, List<Envelope> own, Strings str) {
    final ownFiltered = own.where((e) => _matches(e.displayName(str))).toList();
    final items = section.items
        .where((i) => !ownedKeys.contains(i.key))
        .where((i) => _matches(i.name(str.localeCode)))
        .toList();
    if (items.isEmpty && ownFiltered.isEmpty) return const [];
    return [
      _Section(
        title: section.title(str.localeCode),
        children: [
          for (final e in ownFiltered)
            _Tile(
              avatar: CategoryAvatar(
                  envelope: e, size: 56, selected: e.id == widget.selectedId),
              label: e.displayName(str),
              selected: e.id == widget.selectedId,
              onTap: () => _pickEnvelope(e, str),
            ),
          for (final i in items)
            _Tile(
              avatar: CategoryAvatar(catalogKey: i.key, size: 56),
              label: i.name(str.localeCode),
              selected: false,
              onTap: _busy ? null : () => _pickCatalog(i, mine),
            ),
        ],
      ),
    ];
  }
}

/// Başlık kartın dışında; kart içinde 3'lü ızgara.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      // Kart her zaman tam genişlik — satır dolu olmasa da.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Ex.textMuted)),
          ),
          ExCard(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth / 3;
                return Wrap(
                  runSpacing: 6,
                  children: [
                    for (final c in children) SizedBox(width: w, child: c),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.avatar,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget avatar;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          children: [
            avatar,
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: selected ? Ex.mint : Ex.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
