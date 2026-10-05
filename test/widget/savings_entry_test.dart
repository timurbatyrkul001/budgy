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

/// Döviz cüzdanı açma yolu, Birikim bölümü boşken.
///
/// Ana ekrandaki "Birikim" bölümü ne kumbara ne hedef yokken HİÇ çizilmez
/// (sahibin kararı: boş bölüm gürültü) ve "+ döviz cüzdanı" kutucuğu onunla
/// birlikte kaybolur. Onboarding'i cüzdansız bitiren kullanıcının cüzdan
/// açacak bir kapısı kalmıyordu. Bu dosya o deliği kapatan yolu kilitler:
///
///   Ana ekran › Hesaplar › Tümü (her zaman görünür)
///     → Hesap yönetimi › "Döviz biriktiriyor musun?" yön levhası
///       → Hedefler/Birikim ekranı › "+ Döviz cüzdanı ekle"
///         → döviz cüzdanı sayfası → Firestore'da yeni USD zarfı.
///
/// Ayrıca: Hedefler ekranı cüzdanları da listeler (ekleyince görünsün) ve
/// 320/360dp'de üç dilde taşmaz.
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

  // Yalnız kategori zarfları: cüzdan da hedef de YOK.
  final categoriesOnly = <Envelope>[
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

  /// Cüzdan sayfasının başlığı: rs.addCurrencyWallet'ın "+ "siz hâli.
  String sheetTitle(RS rs) =>
      rs.addCurrencyWallet.replaceFirst(RegExp(r'^\+\s*'), '');

  /// Hesap deposu override'ları (harness'ta yok; home_accounts_strip_test ile
  /// aynı desen).
  List<dynamic> accountOverrides(FakeFirebaseFirestore db) {
    final repo = AccountsRepository(db, testUid);
    return [
      accountsRepositoryProvider.overrideWithValue(repo),
      accountsProvider.overrideWith((ref) => repo.watchAccounts()),
    ];
  }

  Future<FakeFirebaseFirestore> pump(
    WidgetTester tester,
    Widget screen, {
    required List<Envelope> envelopes,
    Iterable<Account> accounts = const [cash],
    AppLanguage language = AppLanguage.tr,
    double width = 360,
  }) async {
    final db = FakeFirebaseFirestore();
    for (final e in envelopes) {
      await seedEnvelope(db, e);
    }
    for (final a in accounts) {
      await db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());
    }
    await pumpBudgyScreen(
      tester,
      screen,
      db: db,
      envelopes: envelopes,
      language: language,
      logicalSize: Size(width, 800),
      extraOverrides: accountOverrides(db),
    );
    return db;
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  group('cüzdansız + hedefsiz kullanıcı', () {
    testWidgets(
        'ana ekrandan ulaşılabilir yol: Hesaplar › Tümü → yön levhası → '
        'Hedefler → "+ döviz cüzdanı" → USD zarfı yazılır', (tester) async {
      final db = await pump(tester, const HomeScreen(),
          envelopes: categoriesOnly);
      final rs = RS.tr;

      // Ön koşul: Birikim bölümü gerçekten yok, eski "+" de yok.
      await tester.drag(find.byType(HomeScreen), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.text(Strings.tr.savingsTitle), findsNothing);
      expect(find.byKey(kHomeSavingsAddKey), findsNothing);
      await tester.drag(find.byType(HomeScreen), const Offset(0, 1200));
      await tester.pumpAndSettle();

      // 1. Hesaplar şeridi her zaman görünür → "Tümü".
      await tapKey(tester, kHomeAccountsSeeAllKey);
      expect(find.byType(ManageAccountsScreen), findsOneWidget);

      // 2. Yön levhası: "cüzdan hesap değil, Birikim'de".
      expect(find.text(rs.savingsSignpostTitle), findsOneWidget);
      await tapKey(tester, kAccountsSavingsSignpostKey);
      expect(find.byType(GoalsScreen), findsOneWidget);

      // 3. Boş Birikim ekranında bile cüzdan düğmesi var.
      expect(find.text(Strings.tr.goalsEmpty), findsOneWidget);
      await tapKey(tester, kGoalsAddWalletKey);
      expect(find.text(sheetTitle(rs)), findsOneWidget);

      // 4. Kaydet → varsayılan (ana birim dışındaki ilk) USD, tutar 0.
      await tester.tap(find.text(rs.save));
      await tester.pumpAndSettle();
      expect(find.text(sheetTitle(rs)), findsNothing);

      final docs = await db
          .collection('users')
          .doc(testUid)
          .collection('envelopes')
          .where('currency', isEqualTo: 'USD')
          .get();
      expect(docs.docs, hasLength(1));
      final data = docs.docs.single.data();
      expect(data['goal'], isNull);
      expect(data['balance'], 0);
      expect(data['name'], tpl(rs.currencyWalletTpl, {'code': 'USD'}));
      expect(data['emoji'], '💵');
    });

    testWidgets('Hedefler ekranı tek başına: boş durum + cüzdan düğmesi',
        (tester) async {
      await pump(tester, const GoalsScreen(), envelopes: const []);
      final rs = RS.tr;

      expect(find.text(Strings.tr.goalsEmpty), findsOneWidget);
      expect(find.byKey(kGoalsAddWalletKey), findsOneWidget);
      expect(find.text(rs.addCurrencyWallet), findsOneWidget);
      // Hedef düğmesi yerinde kaldı.
      expect(find.text(Strings.tr.newGoal.replaceFirst('+ ', '')),
          findsOneWidget);

      await tapKey(tester, kGoalsAddWalletKey);
      expect(find.text(sheetTitle(rs)), findsOneWidget);
    });

    testWidgets('hesap yönetimi: yön levhası yalnız nakitle de var ve '
        'Hedefler ekranını açar', (tester) async {
      await pump(tester, const ManageAccountsScreen(), envelopes: const []);
      final rs = RS.tr;

      expect(find.text(rs.accountEmptyTitle), findsOneWidget);
      expect(find.text(rs.savingsSignpostTitle), findsOneWidget);
      expect(find.text(rs.savingsSignpostBody), findsOneWidget);
      await tapKey(tester, kAccountsSavingsSignpostKey);
      expect(find.byType(GoalsScreen), findsOneWidget);
    });
  });

  group('Hedefler ekranı cüzdanları listeler', () {
    testWidgets('cüzdan + hedef: iki grup, bakiye kendi biriminde',
        (tester) async {
      await pump(tester, const GoalsScreen(), envelopes: [usdWallet, goal]);
      final rs = RS.tr;

      expect(find.text(rs.walletsSection), findsOneWidget);
      expect(find.byKey(const ValueKey('goals-wallet-usd')), findsOneWidget);
      expect(find.text('Dolar Birikimi'), findsOneWidget);
      expect(find.text(r'1,750 $'), findsOneWidget);
      // Hedef grubu alt başlığı + ekran başlığı = iki "Hedefler".
      expect(find.text(Strings.tr.goalsTitle), findsNWidgets(2));
      expect(find.text('Tatil'), findsOneWidget);
      expect(find.text(Strings.tr.goalsEmpty), findsNothing);
    });

    testWidgets('yalnız hedef varken eski görünüm: alt başlık yok',
        (tester) async {
      await pump(tester, const GoalsScreen(), envelopes: [goal]);
      expect(find.text(RS.tr.walletsSection), findsNothing);
      expect(find.text(Strings.tr.goalsTitle), findsOneWidget);
      expect(find.text('Tatil'), findsOneWidget);
    });

    testWidgets('arşivli cüzdan listelenmez', (tester) async {
      await pump(tester, const GoalsScreen(), envelopes: [
        testEnvelope(
            id: 'usd', name: 'Eski', currency: 'USD', archived: true),
      ]);
      expect(find.byKey(const ValueKey('goals-wallet-usd')), findsNothing);
      expect(find.text(Strings.tr.goalsEmpty), findsOneWidget);
    });

    testWidgets('cüzdana dokunma → zarf detayı', (tester) async {
      await pump(tester, const GoalsScreen(), envelopes: [usdWallet, goal]);
      await tapKey(tester, const ValueKey('goals-wallet-usd'));
      expect(find.byType(EnvelopeDetailScreen), findsOneWidget);
      expect(
        tester
            .widget<EnvelopeDetailScreen>(find.byType(EnvelopeDetailScreen))
            .envelopeId,
        'usd',
      );
    });
  });

  // ── dar ekran × dil ───────────────────────────────────────────────────

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      // Boş ve dolu hâl AYRI testlerde: aynı testte ikinci pump kök
      // ProviderScope'u yeniden kullanır ve override'lar (zarf listesi)
      // ilk hâlde kalır.
      testWidgets(
          'Hedefler boş · ${width.toInt()}dp · ${lang.code}: iki düğme taşmaz',
          (tester) async {
        final rs = RS.of(lang.code);
        await pump(tester, const GoalsScreen(),
            envelopes: const [], language: lang, width: width);
        expect(tester.takeException(), isNull);
        expect(find.text(rs.addCurrencyWallet), findsOneWidget);
        expect(find.byKey(kGoalsAddWalletKey), findsOneWidget);
      });

      testWidgets(
          'Hedefler dolu · ${width.toInt()}dp · ${lang.code}: liste + cüzdan '
          'sayfası taşmaz', (tester) async {
        final rs = RS.of(lang.code);
        await pump(tester, const GoalsScreen(),
            envelopes: [usdWallet, goal], language: lang, width: width);
        expect(tester.takeException(), isNull);
        expect(find.text(rs.walletsSection), findsOneWidget);

        // Cüzdan sayfası da bu genişlikte.
        await tapKey(tester, kGoalsAddWalletKey);
        expect(tester.takeException(), isNull);
        expect(find.text(sheetTitle(rs)), findsOneWidget);
      });

      testWidgets(
          'hesap yönetimi yön levhası · ${width.toInt()}dp · ${lang.code} '
          'taşmaz', (tester) async {
        final rs = RS.of(lang.code);
        await pump(tester, const ManageAccountsScreen(),
            envelopes: const [], language: lang, width: width);
        await tester.ensureVisible(find.byKey(kAccountsSavingsSignpostKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(rs.savingsSignpostTitle), findsOneWidget);
        expect(find.text(rs.savingsSignpostBody), findsOneWidget);
      });
    }
  }
}
