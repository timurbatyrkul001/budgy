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

/// Kullanıcının harcama kategorileri (hedef ve döviz cüzdanı hariç).
final expenseCategoriesProvider = Provider<List<Envelope>>((ref) {
  final all = ref.watch(envelopesProvider).value ?? const [];
  return all.where((e) => !e.isGoal && e.currency == 'TRY').toList();
});

/// Aktif harcama kategorisi sayısı (ayarlar merkezindeki rozet).
final categoryCountProvider = Provider<int>((ref) =>
    ref.watch(expenseCategoriesProvider).where((e) => !e.archived).length);

/// Kategoriler: katalog bölümleri altında kullanıcının zarfları (var olanlar
/// tam, eklenmemiş katalog maddeleri soluk — dokununca eklenir), "Kendi
/// kategorilerin" (katalog dışı), en altta "Arşiv". Arama; "+" yeni;
/// dokun → düzenle; uzun bas → arşivle / sil.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _query = '';

  bool _match(String name) =>
      _query.isEmpty || name.toLowerCase().contains(_query.toLowerCase());

  Future<void> _addFromCatalog(CatalogItem item) async {
    final str = ref.read(strProvider);
    final all = ref.read(envelopesProvider).value ?? const [];
    await guardWrite(
      context,
      str,
      () => ref.read(budgetRepositoryProvider).addPresetEnvelope(
            key: item.key,
            name: item.name(str.localeCode),
            emoji: item.emoji,
            sortOrder: all.length,
          ),
      reason: 'addCatalogCategory',
    );
  }

  Future<void> _actions(Envelope e) async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final action = await showExSheet<String>(
      context,
      SheetFrame(
        title: e.displayName(str),
        child: Column(
          children: [
            _ActionRow(
              icon: Icons.edit_rounded,
              label: rs.edit,
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            _ActionRow(
              icon: e.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
              label: e.archived ? rs.unarchive : rs.archive,
              onTap: () => Navigator.of(context).pop('archive'),
            ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: str.deleteWord,
              danger: true,
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(budgetRepositoryProvider);
    switch (action) {
      case 'edit':
        await showEditEnvelopeSheet(context, e);
      case 'archive':
        await guardWrite(context, str, () => repo.setArchived(e.id, !e.archived),
            reason: 'archiveCategory');
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Ex.surface,
            title: Text(str.deleteWord),
            content: Text(tpl(rs.deleteCategoryTpl, {'name': e.displayName(str)})),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(str.cancel)),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(str.deleteWord,
                      style: const TextStyle(color: Ex.red))),
            ],
          ),
        );
        if (ok == true && mounted) {
          await guardWrite(context, str, () => repo.deleteEnvelope(e.id),
              reason: 'deleteCategory');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final all = ref.watch(expenseCategoriesProvider);
    final active = all.where((e) => !e.archived).toList();
    final archived = all.where((e) => e.archived).toList();
    final byKey = {for (final e in active) if (e.presetKey != null) e.presetKey!: e};
    final catalogKeys = {
      for (final s in kCategoryCatalog)
        for (final i in s.items) i.key,
    };
    // Bölümüne göre: kullanıcı kategorileri (katalog dışı) seçtiği bölümün
    // kartında, bölümsüzler "Kendi kategorilerin"de.
    final grouped = groupBySection(
        active.where((e) => e.presetKey == null || !catalogKeys.contains(e.presetKey)));
    final custom = grouped[null] ?? const <Envelope>[];
    final total = ref.watch(envelopesProvider).value?.length ?? 0;

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const BudgyBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(rs.categories,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              color: Ex.text)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassSquareButton(
                      icon: Icons.add_rounded,
                      onTap: () => showAddEnvelopeSheet(context, total),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(color: Ex.text),
                decoration: InputDecoration(
                  hintText: rs.searchCategory,
                  prefixIcon: const Icon(Icons.search_rounded, color: Ex.textMuted),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (custom.where((e) => _match(e.displayName(str))).isNotEmpty)
                    _Section(
                      title: rs.yourCategories,
                      children: [
                        for (final e in custom)
                          if (_match(e.displayName(str)))
                            _CategoryRow(
                              envelope: e,
                              name: e.displayName(str),
                              onTap: () => showEditEnvelopeSheet(context, e),
                              onLongPress: () => _actions(e),
                            ),
                      ],
                    ),
                  for (final section in kCategoryCatalog)
                    if (section.items.any((i) => _match(i.name(str.localeCode))) ||
                        (grouped[section.key] ?? const [])
                            .any((e) => _match(e.displayName(str))))
                      _Section(
                        title: section.title(str.localeCode),
                        children: [
                          for (final e in grouped[section.key] ?? const <Envelope>[])
                            if (_match(e.displayName(str)))
                              _CategoryRow(
                                envelope: e,
                                name: e.displayName(str),
                                onTap: () => showEditEnvelopeSheet(context, e),
                                onLongPress: () => _actions(e),
                              ),
                          for (final i in section.items)
                            if (_match(i.name(str.localeCode)))
                              switch (byKey[i.key]) {
                                final e? => _CategoryRow(
                                    envelope: e,
                                    name: e.displayName(str),
                                    onTap: () => showEditEnvelopeSheet(context, e),
                                    onLongPress: () => _actions(e),
                                  ),
                                null => _CategoryRow(
                                    catalogKey: i.key,
                                    name: i.name(str.localeCode),
                                    muted: true,
                                    hint: rs.tapToAdd,
                                    onTap: () => _addFromCatalog(i),
                                  ),
                              },
                        ],
                      ),
                  if (archived.where((e) => _match(e.displayName(str))).isNotEmpty)
                    _Section(
                      title: rs.archived,
                      children: [
                        for (final e in archived)
                          if (_match(e.displayName(str)))
                            _CategoryRow(
                              envelope: e,
                              name: e.displayName(str),
                              muted: true,
                              onTap: () => _actions(e),
                              onLongPress: () => _actions(e),
                            ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Ex.textMuted)),
          ),
          ExCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Column(
              children: [
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: Ex.border),
                  c,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    this.envelope,
    this.catalogKey,
    required this.name,
    required this.onTap,
    this.onLongPress,
    this.muted = false,
    this.hint,
  });

  final Envelope? envelope;
  final String? catalogKey;
  final String name;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool muted;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            CategoryAvatar(
                envelope: envelope, catalogKey: catalogKey, size: 36, muted: muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: muted ? Ex.textMuted : Ex.text)),
                  if (hint != null)
                    Text(hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Ex.textFaint)),
                ],
              ),
            ),
            Icon(muted && hint != null ? Icons.add_rounded : Icons.chevron_right_rounded,
                size: 20, color: muted && hint != null ? Ex.mint : Ex.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? Ex.red : Ex.mint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: danger ? Ex.red : Ex.text)),
            ),
          ],
        ),
      ),
    );
  }
}
