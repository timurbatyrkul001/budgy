import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/accounts/accounts_screen.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/envelopes/envelope_detail_screen.dart';
import 'package:kopilka_app/features/envelopes/home_screen.dart';
import 'package:kopilka_app/features/goals/goals_screen.dart';

import '../support/harness.dart';

/// Ana ekrandaki "Hesaplar" şeridi artık `Account` modelini gösterir
/// (kartlar + nakit, her biri kendi biriminde); döviz kumbaraları ve
/// hedefler ayrı "Birikim" bölümüne indi. Burada: şerit içeriği, "+"
/// düğmesinin hesap editörünü açması, Birikim bölümünün yalnız kumbara ya
/// da hedef varken çizilmesi, geçişler ve dar ekranda üç dilde taşmama.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  const cash = Account(
    id: Account.cashId,
    name: 'Nakit',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 1234,
  );
  const enpara = Account(
    id: 'enpara',
    name: 'Enpara',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 5678,
    sortOrder: 1,
  );
  const kapital = Account(
    id: 'kapital',
    name: 'Kapital Bank',
    currency: 'AZN',
    kind: AccountKind.card,
    balance: 91,
    sortOrder: 2,
  );

  final categories = <Envelope>[
    testEnvelope(id: 'e1', name: 'Market', balance: 4500),
    testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', balance: 1200),
  ];
  final usdWallet = testEnvelope(
    id: 'usd',
    name: 'Dolar Birikimi',
    emoji: '💵',
    balance: 1750,
    currency: 'USD',
    sortOrder: 5,
  );
  final goal = testEnvelope(
    id: 'g1',
    name: 'Tatil',
    emoji: '🏖️',
    balance: 3000,
    targetAmount: 10000,
    isGoal: true,
    sortOrder: 6,
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    Iterable<Account> accounts = const [cash, enpara, kapital],
    List<Envelope>? envelopes,
    AppLanguage language = AppLanguage.tr,
    double width = 360,
    double cashBalance = 0,
  }) async {
    final db = FakeFirebaseFirestore();
    final envs = envelopes ?? [...categories, usdWallet, goal];
    for (final e in envs) {
      await seedEnvelope(db, e);
    }
    for (final a in accounts) {
      await db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());
    }
    // Gerçek `accountsRepositoryProvider` `uidProvider`'a bağlı ve testte
    // fırlatır; harness'ta hesap deposu için override yok, ek olarak
    // veriyoruz (accounts_screen_test ile aynı desen).
    final repo = AccountsRepository(db, testUid);
    await pumpBudgyScreen(
      tester,
      const HomeScreen(),
      db: db,
      envelopes: envs,
      language: language,
      cashBalance: cashBalance,
      logicalSize: Size(width, 800),
      extraOverrides: [
        accountsRepositoryProvider.overrideWithValue(repo),
        accountsProvider.overrideWith((ref) => repo.watchAccounts()),
      ],
    );
  }

  /// Şeritteki [target]'ı görünür kılıp dokunur. Ana ekran tembel bir
  /// ListView: bölüm sayfanın altında kalmış olabilir (dikey kaydır), şeridin
  /// sonu da kurulmamış olabilir (yatay kaydır — [anchor] şeridin ilk
  /// kutucuğu, sürükleme onun üstünde başlar).
  Future<void> tapInStrip(
    WidgetTester tester, {
    required Key anchor,
    required Key target,
  }) async {
    await tester.dragUntilVisible(
      find.byKey(anchor),
      find.byType(HomeScreen),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    if (find.byKey(target).evaluate().isEmpty) {
      await tester.drag(find.byKey(anchor), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(target));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(target));
    await tester.pumpAndSettle();
  }

  const cashKey = ValueKey('home-account-cash');
  const walletKey = ValueKey('home-wallet-usd');

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
  }

  group('hesaplar şeridi', () {
    testWidgets('kartlar + nakit, her biri kendi biriminde', (tester) async {
      await pumpHome(tester);

      expect(find.byKey(const ValueKey('home-account-cash')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-account-enpara')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-account-kapital')),
        findsOneWidget,
      );
      expect(find.text('Enpara'), findsOneWidget);
      expect(find.text('Kapital Bank'), findsOneWidget);
      expect(find.text('1,234 ₺'), findsOneWidget);
      expect(find.text('5,678 ₺'), findsOneWidget);
      // Üçüncü kutucuk şeridin kurulu kısmının dışında; yaklaştır.
      await tester.drag(find.byKey(cashKey), const Offset(-300, 0));
      await tester.pumpAndSettle();
      // Manat kartı ₺'ye çevrilmez, ₺ simgesiyle de yazılmaz.
      expect(find.text('91 ₼'), findsOneWidget);
      expect(find.text('91 ₺'), findsNothing);
      // Kumbara hesap şeridinde DEĞİL.
      expect(find.byKey(const ValueKey('home-account-usd')), findsNothing);
    });

    testWidgets('hesap belgesi yokken sentetik nakit: cüzdan bakiyesi', (
      tester,
    ) async {
      await pumpHome(tester, accounts: const [], cashBalance: 750);

      expect(find.byKey(const ValueKey('home-account-cash')), findsOneWidget);
      expect(find.text(RS.tr.cash), findsOneWidget);
      expect(find.text('750 ₺'), findsOneWidget);
    });

    testWidgets('"+" hesap editörünü açar (döviz cüzdanı değil)', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapInStrip(tester, anchor: cashKey, target: kHomeAccountsAddKey);

      expect(find.text(RS.tr.accountNewTitle), findsOneWidget);
      expect(find.byType(ManageAccountsScreen), findsNothing);
    });

    testWidgets('"Tümü" ve hesaba dokunma → hesap yönetimi ekranı', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapInStrip(tester, anchor: cashKey, target: kHomeAccountsSeeAllKey);
      expect(find.byType(ManageAccountsScreen), findsOneWidget);

      await goBack(tester);
      expect(find.byType(ManageAccountsScreen), findsNothing);

      await tapInStrip(
        tester,
        anchor: cashKey,
        target: const ValueKey('home-account-enpara'),
      );
      expect(find.byType(ManageAccountsScreen), findsOneWidget);
    });
  });

  group('birikim bölümü', () {
    testWidgets('kumbara + hedef varken çizilir', (tester) async {
      await pumpHome(tester);
      await tester.dragUntilVisible(
        find.byKey(walletKey),
        find.byType(HomeScreen),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.tr.savingsTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('home-wallet-usd')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-goal-g1')), findsOneWidget);
      expect(find.text('Dolar Birikimi'), findsOneWidget);
      expect(find.text(r'1,750 $'), findsOneWidget);
      expect(find.text('Tatil'), findsOneWidget);
      expect(find.byKey(kHomeSavingsAddKey), findsOneWidget);
    });

    testWidgets('yalnız kumbara varken de çizilir', (tester) async {
      await pumpHome(tester, envelopes: [...categories, usdWallet]);
      await tester.dragUntilVisible(
        find.byKey(walletKey),
        find.byType(HomeScreen),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.tr.savingsTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('home-wallet-usd')), findsOneWidget);
    });

    testWidgets('ne kumbara ne hedef → bölüm hiç yok', (tester) async {
      await pumpHome(tester, envelopes: categories);
      // Sayfanın sonuna kadar kaydır: tembel liste bölümü yalnız
      // görünmediği için değil, hiç olmadığı için bulamamalı.
      await tester.drag(find.byType(HomeScreen), const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(find.text(Strings.tr.savingsTitle), findsNothing);
      expect(find.byKey(kHomeSavingsAddKey), findsNothing);
      expect(find.byKey(kHomeSavingsSeeAllKey), findsNothing);
      // Hesap şeridi yerinde.
      expect(find.byKey(cashKey), findsOneWidget);
    });

    testWidgets('arşivli kumbara / hedef sayılmaz', (tester) async {
      await pumpHome(
        tester,
        envelopes: [
          ...categories,
          testEnvelope(
            id: 'usd',
            name: 'Dolar',
            currency: 'USD',
            archived: true,
          ),
          testEnvelope(id: 'g1', name: 'Tatil', isGoal: true, archived: true),
        ],
      );
      await tester.drag(find.byType(HomeScreen), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.text(Strings.tr.savingsTitle), findsNothing);
    });

    testWidgets('kumbaraya dokunma → zarf detayı', (tester) async {
      await pumpHome(tester);
      await tapInStrip(tester, anchor: walletKey, target: walletKey);

      expect(find.byType(EnvelopeDetailScreen), findsOneWidget);
      expect(
        tester
            .widget<EnvelopeDetailScreen>(find.byType(EnvelopeDetailScreen))
            .envelopeId,
        'usd',
      );
    });

    testWidgets('"Tümü" → hedefler ekranı', (tester) async {
      await pumpHome(tester);
      await tapInStrip(
        tester,
        anchor: walletKey,
        target: kHomeSavingsSeeAllKey,
      );
      expect(find.byType(GoalsScreen), findsOneWidget);
    });

    testWidgets('"+" döviz cüzdanı sayfasını açar', (tester) async {
      await pumpHome(tester);
      await tapInStrip(tester, anchor: walletKey, target: kHomeSavingsAddKey);

      // Sayfa başlığı rs.addCurrencyWallet'ın "+ "siz hâli.
      final title = RS.tr.addCurrencyWallet.replaceFirst(RegExp(r'^\+\s*'), '');
      expect(find.text(title), findsOneWidget);
      expect(find.text(RS.tr.accountNewTitle), findsNothing);
    });
  });

  // ── dar ekran × dil ───────────────────────────────────────────────────

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('${width.toInt()}dp · ${lang.code}: iki şerit taşmaz', (
        tester,
      ) async {
        await pumpHome(tester, language: lang, width: width);
        expect(tester.takeException(), isNull);

        final rs = RS.of(lang.code);
        final str = switch (lang) {
          AppLanguage.tr => Strings.tr,
          AppLanguage.en => Strings.en,
          AppLanguage.ru => Strings.ru,
        };
        expect(find.text(rs.accounts), findsOneWidget);

        // Hesap şeridinin sonuna kadar: "+" kutucuğu da ölçülsün.
        await tester.dragUntilVisible(
          find.byKey(cashKey),
          find.byType(HomeScreen),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byKey(cashKey), const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(find.byKey(kHomeAccountsAddKey), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Birikim şeridi: başlık, kumbara, hedef, iki satırlık "+" etiketi.
        await tester.dragUntilVisible(
          find.byKey(walletKey),
          find.byType(HomeScreen),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        expect(find.text(str.savingsTitle), findsOneWidget);
        await tester.drag(find.byKey(walletKey), const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(find.text(rs.addSavingsWallet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
