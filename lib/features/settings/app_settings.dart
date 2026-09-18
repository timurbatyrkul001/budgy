import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_rules.dart';
import '../auth/auth_gate.dart';
import '../envelopes/budget_repository.dart';

/// Uygulama ayarları (settings/main): tuş takımı düzeni, ses dili — ve
/// kategori otomasyonu (users/{uid}/rules + settings/automation).

/// "1-2-3 üstte" mi? Varsayılan: hayır (hesap makinesi düzeni, 7-8-9 üstte).
final keypadOneTwoThreeOnTopProvider = Provider<bool>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  return p['keypadLayout'] == 'top';
});

/// Sesli giriş dili (STT localeId, örn. "tr_TR"). null = uygulama dili.
final voiceLocaleProvider = Provider<String?>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  final v = p['voiceLocale'] as String?;
  return v == null || v.isEmpty ? null : v;
});

/// Uygulama diline karşılık gelen STT dili.
String voiceLocaleFor(String localeCode) => switch (localeCode) {
      'tr' => 'tr_TR',
      'ru' => 'ru_RU',
      _ => 'en_US',
    };

List<String> _stringList(Object? v) =>
    v is List ? [for (final x in v) '$x'] : const [];

/// Yıldızlı paralar (ana ekran kur çipi), sıralı; en fazla 2.
final starredCurrenciesProvider = Provider<List<String>>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  return _stringList(p['starredCurrencies']);
});

/// Çeviricide son kullanılan paralar (en yeni başta, 5).
final recentCurrenciesProvider = Provider<List<String>>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  return _stringList(p['recentCurrencies']);
});

/// Çevirici satırları (son açılış), yoksa boş.
final converterRowsProvider = Provider<List<String>>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  return _stringList(p['converterRows']);
});

/// Kullanıcının kendi kuralları (sırayla).
final userRulesProvider = StreamProvider<List<UserRule>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(budgetRepositoryProvider).watchRules();
});

/// Kapatılmış yerleşik anahtar kelimeler (settings/automation → disabled).
final disabledBuiltinsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const {});
  return ref.watch(budgetRepositoryProvider).watchDisabledBuiltins();
});

/// Metne uyan kural — kullanıcı kuralları + açık yerleşikler.
final ruleMatcherProvider = Provider<RuleMatch? Function(String?)>((ref) {
  final rules = ref.watch(userRulesProvider).value ?? const [];
  final disabled = ref.watch(disabledBuiltinsProvider).value ?? const {};
  return (text) =>
      matchCategory(text, userRules: rules, disabledBuiltins: disabled);
});

/// Repo tarafı: kurallar ve otomasyon ayarı.
extension AutomationRepo on BudgetRepository {
  CollectionReference<Map<String, dynamic>> get _rules =>
      db.collection('users').doc(uid).collection('rules');

  DocumentReference<Map<String, dynamic>> get _automation =>
      db.collection('users').doc(uid).collection('settings').doc('automation');

  Stream<List<UserRule>> watchRules() => _rules
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs
          .map((d) => UserRule(
                id: d.id,
                keyword: d.data()['keyword'] as String? ?? '',
                envelopeId: d.data()['envelopeId'] as String? ?? '',
                envelopeName: d.data()['envelopeName'] as String? ?? '',
              ))
          .toList());

  Future<void> addRule({
    required String keyword,
    required String envelopeId,
    required String envelopeName,
  }) =>
      _rules.add({
        'keyword': keyword.trim(),
        'envelopeId': envelopeId,
        'envelopeName': envelopeName,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateRuleKeyword(String id, String keyword) =>
      _rules.doc(id).update({'keyword': keyword.trim()});

  Future<void> deleteRule(String id) => _rules.doc(id).delete();

  Stream<Set<String>> watchDisabledBuiltins() => _automation.snapshots().map(
        (d) => {
          for (final k in (d.data()?['disabled'] as List? ?? const [])) '$k',
        },
      );

  Future<void> setBuiltinEnabled(String keyword, bool enabled) =>
      _automation.set({
        'disabled': enabled
            ? FieldValue.arrayRemove([keyword])
            : FieldValue.arrayUnion([keyword]),
      }, SetOptions(merge: true));
}
