import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_catalog.dart';
import '../../core/l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope_l10n.dart';
import 'app_settings.dart';

/// Otomasyon eşleşmesini gerçek bir zarfa çevirir. Kullanıcı kuralı →
/// zarf id (varsa); yerleşik kural → aynı preset anahtarlı zarf, yoksa
/// katalogdan YARATILIR (aksi halde kural işe yaramazdı).
Future<({String id, String name})?> resolveCategoryFromText(
    WidgetRef ref, String text) async {
  final match = ref.read(ruleMatcherProvider)(text);
  if (match == null) return null;
  final str = ref.read(strProvider);
  final all = ref.read(envelopesProvider).value ?? const [];
  if (match.envelopeId != null) {
    final e = all.where((e) => e.id == match.envelopeId).firstOrNull;
    return e == null || e.archived ? null : (id: e.id, name: e.displayName(str));
  }
  final key = match.catalogKey!;
  final existing = all.where((e) => e.presetKey == key && !e.archived).firstOrNull;
  if (existing != null) return (id: existing.id, name: existing.displayName(str));
  final item = catalogItem(key);
  if (item == null) return null;
  final name = item.name(str.localeCode);
  final id = await ref.read(budgetRepositoryProvider).addPresetEnvelope(
      key: key, name: name, emoji: item.emoji, sortOrder: all.length);
  return (id: id, name: name);
}

/// Parser yedeği için eşzamanlı sürüm: yalnız var olan zarflara bağlar
/// (yaratmaz — parse sırasında yazma yapılmaz).
({String id, String name})? Function(String) categoryResolverSync(WidgetRef ref) {
  return (text) {
    final match = ref.read(ruleMatcherProvider)(text);
    if (match == null) return null;
    final str = ref.read(strProvider);
    final all = ref.read(envelopesProvider).value ?? const [];
    final e = match.envelopeId != null
        ? all.where((e) => e.id == match.envelopeId).firstOrNull
        : all.where((e) => e.presetKey == match.catalogKey && !e.archived).firstOrNull;
    return e == null ? null : (id: e.id, name: e.displayName(str));
  };
}
