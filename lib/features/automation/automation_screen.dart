import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_avatar.dart';
import '../../core/category_catalog.dart';
import '../../core/category_rules.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope_l10n.dart';
import '../settings/app_settings.dart';
import '../transactions/category_sheet.dart';

/// Kategori otomasyonu: "Kuralların" (kullanıcı, zarfa göre gruplu) +
/// "Yerleşik kurallar (N)" (kategoriye göre, açık/toplam sayısı).
/// Kategoriye dokun → anahtar kelimeler; "+" → kelime + kategori.
class AutomationScreen extends ConsumerWidget {
  const AutomationScreen({super.key});

  Future<void> _addRule(BuildContext context, WidgetRef ref) async {
    final pick = await showCategorySheet(context);
    if (pick == null || !context.mounted) return;
    final keyword = await showKeywordSheet(context, title: pick.name);
    if (keyword == null || !context.mounted) return;
    await guardWrite(
      context,
      ref.read(strProvider),
      () => ref.read(budgetRepositoryProvider).addRule(
          keyword: keyword, envelopeId: pick.id, envelopeName: pick.name),
      reason: 'addRule',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final rules = ref.watch(userRulesProvider).value ?? const <UserRule>[];
    final disabled = ref.watch(disabledBuiltinsProvider).value ?? const <String>{};
    final envelopes = {
      for (final e in ref.watch(envelopesProvider).value ?? const []) e.id: e,
    };
    // Kullanıcı kuralları zarfa göre.
    final byEnvelope = <String, List<UserRule>>{};
    for (final r in rules) {
      byEnvelope.putIfAbsent(r.envelopeId, () => []).add(r);
    }
    final disabledNorm = {for (final d in disabled) normalizeText(d)};

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                const BudgyBackButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(rs.automation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      onTap: () => _addRule(context, ref)),
                ),
              ],
            ),
            Text(rs.automationHint,
                style: const TextStyle(fontSize: 13.5, height: 1.4, color: Ex.textSoft)),
            const SizedBox(height: 16),
            if (byEnvelope.isNotEmpty) ...[
              _Label(rs.yourRules),
              ExCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Column(
                  children: [
                    for (final (i, e) in byEnvelope.entries.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: Ex.border),
                      _RuleCategoryRow(
                        avatar: CategoryAvatar(
                            envelope: envelopes[e.key], emoji: '🏷️', tintSeed: e.key, size: 36),
                        name: envelopes[e.key]?.displayName(str) ??
                            e.value.first.envelopeName,
                        count: '${e.value.length}',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RuleKeywordsScreen(
                            title: envelopes[e.key]?.displayName(str) ??
                                e.value.first.envelopeName,
                            envelopeId: e.key,
                            envelopeName: e.value.first.envelopeName,
                          ),
                        )),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _Label(tpl(rs.builtinRulesTpl, {'n': '${builtinRuleCount()}'})),
            ExCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                children: [
                  for (final (i, e) in kBuiltinRules.entries.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Ex.border),
                    Builder(builder: (context) {
                      final item = catalogItem(e.key);
                      final enabled = e.value
                          .where((k) => !disabledNorm.contains(normalizeText(k)))
                          .length;
                      return _RuleCategoryRow(
                        avatar: CategoryAvatar(catalogKey: e.key, emoji: '🏷️', size: 36),
                        name: item?.name(str.localeCode) ?? e.key,
                        count: enabled == e.value.length
                            ? '${e.value.length}'
                            : '$enabled/${e.value.length}',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RuleKeywordsScreen(
                            title: item?.name(str.localeCode) ?? e.key,
                            catalogKey: e.key,
                          ),
                        )),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Ex.textMuted)),
      );
}

class _RuleCategoryRow extends StatelessWidget {
  const _RuleCategoryRow({
    required this.avatar,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final Widget avatar;
  final String name;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Ex.text)),
            ),
            Text(count, style: const TextStyle(fontSize: 13, color: Ex.textMuted)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Anahtar kelime giriş sayfası; metni döndürür (boş → null).
Future<String?> showKeywordSheet(BuildContext context,
        {required String title, String initial = ''}) =>
    showExSheet<String>(context, _KeywordSheet(title: title, initial: initial));

class _KeywordSheet extends ConsumerStatefulWidget {
  const _KeywordSheet({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  ConsumerState<_KeywordSheet> createState() => _KeywordSheetState();
}

class _KeywordSheetState extends ConsumerState<_KeywordSheet> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    return SheetFrame(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(rs.keyword),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Ex.text),
            decoration: InputDecoration(hintText: rs.keywordHint),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim().isEmpty ? null : v.trim()),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: rs.save,
            onTap: () {
              final v = _ctrl.text.trim();
              Navigator.of(context).pop(v.isEmpty ? null : v);
            },
          ),
        ],
      ),
    );
  }
}

/// Bir kategorinin anahtar kelimeleri: yerleşikler (aç/kapat) ve/veya
/// kullanıcı kuralları (düzenle / sil); altta "+ Anahtar kelime ekle".
class RuleKeywordsScreen extends ConsumerWidget {
  const RuleKeywordsScreen({
    super.key,
    required this.title,
    this.catalogKey,
    this.envelopeId,
    this.envelopeName,
  });

  final String title;

  /// Yerleşik kategori (kCatalog anahtarı) — varsa yerleşik kelimeler listelenir.
  final String? catalogKey;

  /// Kullanıcı kurallarının zarfı.
  final String? envelopeId;
  final String? envelopeName;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final repo = ref.read(budgetRepositoryProvider);
    // Yerleşik kategori için kullanıcı kuralı: aynı katalog zarfına bağla
    // (yoksa yarat).
    String? envId = envelopeId;
    String? envName = envelopeName;
    if (envId == null && catalogKey != null) {
      final all = ref.read(envelopesProvider).value ?? const [];
      final existing = all.where((e) => e.presetKey == catalogKey).firstOrNull;
      final item = catalogItem(catalogKey!);
      if (existing != null) {
        envId = existing.id;
        envName = existing.displayName(str);
      } else if (item != null) {
        envName = item.name(str.localeCode);
        envId = await repo.addPresetEnvelope(
            key: item.key, name: envName, emoji: item.emoji, sortOrder: all.length);
      }
    }
    if (envId == null || envName == null || !context.mounted) return;
    final keyword = await showKeywordSheet(context, title: title);
    if (keyword == null || !context.mounted) return;
    await guardWrite(
      context,
      str,
      () => repo.addRule(keyword: keyword, envelopeId: envId!, envelopeName: envName!),
      reason: 'addRule',
    );
  }

  Future<void> _editUserRule(BuildContext context, WidgetRef ref, UserRule r) async {
    final str = ref.read(strProvider);
    final rs = ref.read(rsProvider);
    final action = await showExSheet<String>(
      context,
      SheetFrame(
        title: r.keyword,
        child: Column(
          children: [
            _Action(icon: Icons.edit_rounded, label: rs.edit,
                onTap: () => Navigator.of(context).pop('edit')),
            _Action(icon: Icons.delete_outline_rounded, label: str.deleteWord,
                danger: true, onTap: () => Navigator.of(context).pop('delete')),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final repo = ref.read(budgetRepositoryProvider);
    if (action == 'delete') {
      await guardWrite(context, str, () => repo.deleteRule(r.id), reason: 'deleteRule');
    } else {
      final kw = await showKeywordSheet(context, title: title, initial: r.keyword);
      if (kw == null || !context.mounted) return;
      await guardWrite(context, str, () => repo.updateRuleKeyword(r.id, kw),
          reason: 'editRule');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final disabled = ref.watch(disabledBuiltinsProvider).value ?? const <String>{};
    final disabledNorm = {for (final d in disabled) normalizeText(d)};
    final builtins = catalogKey == null ? const <String>[] : kBuiltinRules[catalogKey] ?? const [];
    // Bu kategoriye bağlı kullanıcı kuralları: zarf id ile ya da (yerleşik
    // kategori için) preset anahtarıyla eşleşen zarf.
    final all = ref.watch(envelopesProvider).value ?? const [];
    final catalogEnvId = catalogKey == null
        ? null
        : all.where((e) => e.presetKey == catalogKey).firstOrNull?.id;
    final mine = (ref.watch(userRulesProvider).value ?? const <UserRule>[])
        .where((r) => r.envelopeId == (envelopeId ?? catalogEnvId))
        .toList();

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const BudgyBackButton(),
            Text(title,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: Ex.text)),
            const SizedBox(height: 14),
            if (mine.isNotEmpty) ...[
              _Label(rs.yourRules),
              ExCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Column(
                  children: [
                    for (final (i, r) in mine.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: Ex.border),
                      InkWell(
                        onTap: () => _editUserRule(context, ref, r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 18, color: Ex.mint),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(r.keyword,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Ex.text)),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (builtins.isNotEmpty) ...[
              _Label(tpl(rs.builtinRulesTpl, {'n': '${builtins.length}'})),
              ExCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Column(
                  children: [
                    for (final (i, kw) in builtins.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: Ex.border),
                      Builder(builder: (context) {
                        final on = !disabledNorm.contains(normalizeText(kw));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(kw,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: on ? Ex.text : Ex.textFaint)),
                              ),
                              if (!on)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(rs.ruleDisabled,
                                      style: const TextStyle(
                                          fontSize: 12, color: Ex.textFaint)),
                                ),
                              Switch(
                                value: on,
                                activeThumbColor: Ex.brand,
                                onChanged: (v) => guardWrite(
                                  context,
                                  str,
                                  () => ref
                                      .read(budgetRepositoryProvider)
                                      .setBuiltinEnabled(kw, v),
                                  reason: 'toggleBuiltin',
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            GhostButton(label: rs.addKeyword, onTap: () => _add(context, ref)),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
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
  Widget build(BuildContext context) => Padding(
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
