import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/core/theme.dart';
import 'package:kopilka_app/features/home/fx_providers.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/reminders/reminders_repository.dart';
import 'package:kopilka_app/features/settings/app_settings.dart';
import 'package:kopilka_app/features/settings/settings_hub.dart';
import 'package:kopilka_app/features/transactions/tx.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

/// Widget testlerinde kullanılan sabit kullanıcı kimliği.
const testUid = 'test-user';

Envelope testEnvelope({
  required String id,
  String name = 'Zarf',
  String emoji = '🍔',
  double balance = 0,
  int sortOrder = 0,
  String currency = 'TRY',
  double? targetAmount,
  bool archived = false,
  bool isGoal = false,
  String? presetKey,
  String? section,
  int? colorIndex,
}) {
  return Envelope(
    id: id,
    name: name,
    emoji: emoji,
    balance: balance,
    sortOrder: sortOrder,
    currency: currency,
    targetAmount: targetAmount,
    archived: archived,
    isGoal: isGoal,
    presetKey: presetKey,
    section: section,
    colorIndex: colorIndex,
  );
}

/// Bir Budgy ekranını Firebase'e hiç dokunmadan açar.
///
/// Gerçek [budgetRepositoryProvider] `uidProvider`'a, o da Firebase Auth'a
/// bağlı — testte oturum olmadığı için fırlatır. Burada repository sahte bir
/// Firestore ile kurulur, dil sabitlenir ve stream'ler hazır değerle beslenir.
/// Tema ve localization delegate'leri gerçek uygulamadakiyle aynı; aksi halde
/// `context.budgy` ve Material metinleri testte patlar.
Future<void> pumpBudgyScreen(
  WidgetTester tester,
  Widget screen, {
  required FakeFirebaseFirestore db,
  List<Envelope> envelopes = const [],
  List<Tx> transactions = const [],
  List<WorkDay> workDays = const [],
  double cashBalance = 0,
  AppLanguage language = AppLanguage.tr,
  String currency = 'TRY',
  Map<String, dynamic> profile = const {},
  FxSnapshot? fxSnapshot,
  Size logicalSize = const Size(360, 800),
}) async {
  // Varsayılan test yüzeyi 800x600 — Budgy ekranları uzun, alt çubuktaki
  // Kaydet düğmesi bu boyutta görünürün dışında kalıp dokunulamıyor.
  // Gerçekçi bir telefon boyutu (varsayılan 360x800 mantıksal) kullanıyoruz.
  tester.view.physicalSize = logicalSize * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        budgetRepositoryProvider
            .overrideWithValue(BudgetRepository(db, testUid)),
        languageProvider.overrideWith((ref) => Stream.value(language)),
        currencyProvider.overrideWith((ref) => Stream.value(currency)),
        envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
        journalProvider.overrideWith((ref) => Stream.value(transactions)),
        journalFullProvider.overrideWith((ref) => Stream.value(transactions)),
        recentTxsProvider.overrideWith((ref) => Stream.value(transactions)),
        allWorkDaysProvider.overrideWith((ref) => Stream.value(workDays)),
        cashBalanceProvider
            .overrideWith((ref) => Stream.value(cashBalance)),
        profileProvider.overrideWith((ref) => Stream.value(profile)),
        // Bildirim zamanlayıcısı platform kanallarına dokunuyor; testte
        // no-op'a çeviriyoruz (yoksa MissingPluginException fırlar).
        reminderSchedulerProvider.overrideWithValue(null),
        remindersProvider.overrideWith((ref) => Stream.value(const [])),
        recurringRulesProvider.overrideWith((ref) => Stream.value(const [])),
        recurringMaterializerProvider.overrideWith((ref) async => 0),
        userRulesProvider.overrideWith((ref) => Stream.value(const [])),
        disabledBuiltinsProvider.overrideWith((ref) => Stream.value(const {})),
        appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
        fxSnapshotProvider.overrideWith((ref, base) async => fxSnapshot),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        locale: Locale(language.code),
        supportedLocales: [
          for (final l in AppLanguage.values) Locale(l.code),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Yerleşim testleri animasyonun ortasını değil, YERLEŞİK durumu
        // ölçmeli. `disableAnimations` ile giriş animasyonları anında
        // tamamlanır (hepsi `reduceMotion`'a bakar) ve intro'daki döngülü
        // nokta göstergesi durur — yoksa `pumpAndSettle` sonsuza kadar
        // beklerdi. Boyutu korumak için copyWith kullanılıyor.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Sahte Firestore'a zarf belgesi yazar — repository'nin bakiyeyi
/// artırabilmesi için belgenin gerçekten var olması gerekir.
Future<void> seedEnvelope(
  FakeFirebaseFirestore db,
  Envelope envelope,
) {
  return db.doc('users/$testUid/envelopes/${envelope.id}').set({
    'name': envelope.name,
    'emoji': envelope.emoji,
    'balance': envelope.balance,
    'sortOrder': envelope.sortOrder,
    'currency': envelope.currency,
    if (envelope.targetAmount != null) 'targetAmount': envelope.targetAmount,
    if (envelope.isGoal) 'goal': true,
  });
}
