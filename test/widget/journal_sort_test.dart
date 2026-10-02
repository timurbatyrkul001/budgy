import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/transactions/journal_filter.dart';
import 'package:kopilka_app/features/transactions/journal_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Geçmiş › "Sırala ve Filtrele": üç sıralama doğru sırayı verir, aynı
/// satıra tekrar dokunmak yönü çevirir, karışık para biriminde donmuş
/// tutar kullanılır, kategorisizler iki yönde de sonda, hesap/dönem
/// çipleri listeyi daraltır, tek hesapta hesap bölümü yok, dar ekranda
/// üç dilde taşmaz.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  // Sabit "bugün": ayın SON günü ki "Bu ay" (1–31 Mart) ile "30 gün"
  // (2–31 Mart) ayrışsın — 1 Mart ilkinde var, ikincisinde yok.
  final now = DateTime(2026, 3, 31, 12);

  final envelopes = <Envelope>[
    testEnvelope(id: 'e1', name: 'Market', balance: 1000),
    testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', balance: 500),
  ];

  const cash = Account(
    id: Account.cashId,
    name: 'Nakit',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 200,
  );
  const enpara = Account(
    id: 'enpara',
    name: 'Enpara Maaş Hesabı',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 1500,
    sortOrder: 1,
  );
  const archived = Account(
    id: 'old',
    name: 'Eski Kart',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 0,
    sortOrder: 2,
    archived: true,
  );

  // Ana birimde tutarlar: a=50, b=200, c=120 (eski kayıt, hesapsız),
  // d=400 (10 ₼ donmuş kurla 400 ₺ — ham 10 en küçük, çevrilmiş en büyük).
  final txs = <Tx>[
    Tx(
      id: 'a',
      type: TxType.expense,
      amount: 50,
      date: DateTime(2026, 3, 30),
      envelopeId: 'e1',
      envelopeName: 'Market',
      note: 'Ekmek',
      accountId: Account.cashId,
    ),
    Tx(
      id: 'b',
      type: TxType.expense,
      amount: 200,
      date: DateTime(2026, 3, 10),
      envelopeId: 'e2',
      envelopeName: 'Ulaşım',
      note: 'Taksi',
      accountId: 'enpara',
    ),
    Tx(
      id: 'c',
      type: TxType.expense,
      amount: 120,
      date: DateTime(2026, 3, 1),
      note: 'Kategorisiz',
    ),
    Tx(
      id: 'd',
      type: TxType.expense,
      amount: 10,
      currency: 'AZN',
      date: DateTime(2026, 2, 20),
      envelopeId: 'e1',
      envelopeName: 'Market',
      note: 'Bakü market',
      accountId: 'enpara',
      baseAmount: 400,
      baseCurrency: 'TRY',
      fxRate: 40,
    ),
  ];

  Strings strOf(AppLanguage lang) => switch (lang) {
        AppLanguage.en => Strings.en,
        AppLanguage.tr => Strings.tr,
        AppLanguage.ru => Strings.ru,
      };

  Future<void> pumpJournal(
    WidgetTester tester, {
    List<Account> accounts = const [cash, enpara, archived],
    List<Tx>? transactions,
    AppLanguage language = AppLanguage.tr,
    double width = 360,
  }) async {
    final db = FakeFirebaseFirestore();
    for (final e in envelopes) {
      await seedEnvelope(db, e);
    }
    // Harness'ta hesap sağlayıcısı için override yok (gerçek olan
    // uidProvider'a bağlı). Ekranı kendi scope'una sarıyoruz; alt sayfa
    // sağlayıcı okumadığı için modal rotanın scope'u önemli değil.
    await pumpBudgyScreen(
      tester,
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream.value(accounts.where((a) => !a.archived).toList()),
          ),
        ],
        child: JournalScreen(now: now),
      ),
      db: db,
      envelopes: envelopes,
      transactions: transactions ?? txs,
      language: language,
      logicalSize: Size(width, 800),
    );
  }

  final sheet = find.byType(JournalSortFilterSheet);
  Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
  }

  Future<void> apply(WidgetTester tester, Strings str) async {
    final button = inSheet(find.text(str.applyFilter));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  }

  Future<void> tapInSheet(WidgetTester tester, Finder f) async {
    final target = inSheet(f);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Ekrandaki işlem satırlarının kimlikleri, görünen sırayla.
  List<String> ids(WidgetTester tester) =>
      tester.widgetList<TxTile>(find.byType(TxTile)).map((w) => w.tx.id).toList();

  bool filterButtonLit(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(Icons.tune_rounded)).color == Ex.onBrand;

  final str = Strings.tr;
  final down = find.byIcon(Icons.arrow_downward_rounded);
  final up = find.byIcon(Icons.arrow_upward_rounded);

  // ── saf mantık ───────────────────────────────────────────────────────

  group('saf mantık', () {
    test('tarih: varsayılan yeniden eskiye, çevirince eskiden yeniye', () {
      expect(
        sortJournal(txs, JournalSort.def, mainCurrency: 'TRY').map((t) => t.id),
        ['a', 'b', 'c', 'd'],
      );
      expect(
        sortJournal(txs, JournalSort.def.tapped(JournalSortKey.date),
                mainCurrency: 'TRY')
            .map((t) => t.id),
        ['d', 'c', 'b', 'a'],
      );
    });

    test('tutar: karışık birimde donmuş baseAmount ile karşılaştırır', () {
      const desc = JournalSort(key: JournalSortKey.amount);
      expect(sortJournal(txs, desc, mainCurrency: 'TRY').map((t) => t.id),
          ['d', 'b', 'c', 'a']);
      expect(
        sortJournal(txs, desc.tapped(JournalSortKey.amount), mainCurrency: 'TRY')
            .map((t) => t.id),
        ['a', 'c', 'b', 'd'],
      );
    });

    test('kategori: A→Z ve Z→A, kategorisizler iki yönde de sonda', () {
      const asc = JournalSort(key: JournalSortKey.category, descending: false);
      expect(sortJournal(txs, asc, mainCurrency: 'TRY').map((t) => t.id),
          ['a', 'd', 'b', 'c']);
      expect(
        sortJournal(txs, asc.tapped(JournalSortKey.category), mainCurrency: 'TRY')
            .map((t) => t.id),
        ['b', 'a', 'd', 'c'],
      );
    });

    test('eşit tutarda ikincil anahtar tarih: sıra kararlı', () {
      final same = [
        for (final (id, day) in [('x', 3), ('y', 9), ('z', 6)])
          Tx(
            id: id,
            type: TxType.expense,
            amount: 100,
            date: DateTime(2026, 3, day),
          ),
      ];
      const byAmount = JournalSort(key: JournalSortKey.amount);
      // Girdi sırası ne olursa olsun aynı çıktı.
      for (final input in [same, same.reversed.toList()]) {
        expect(
          sortJournal(input, byAmount, mainCurrency: 'TRY').map((t) => t.id),
          ['y', 'z', 'x'],
        );
      }
    });

    test('"Bu ay" takvim ayıdır, "30 gün" değil', () {
      List<String> run(JournalPeriod p) => applyJournalFilter(
            txs,
            JournalFilter(period: p),
            now: now,
          ).map((t) => t.id).toList();
      // 31 Mart: ay 1 Mart'ı kapsar; 30 günlük pencere 2 Mart'tan başlar.
      expect(run(JournalPeriod.thisMonth), ['a', 'b', 'c']);
      expect(run(JournalPeriod.last30), ['a', 'b']);
      expect(run(JournalPeriod.all), ['a', 'b', 'c', 'd']);
    });

    test('hesap filtresi: kimlik ve "hesapsız" nöbetçisi', () {
      List<String> run(String? acc) => applyJournalFilter(
            txs,
            JournalFilter(accountId: acc),
            now: now,
          ).map((t) => t.id).toList();
      expect(run('enpara'), ['b', 'd']);
      expect(run(kJournalNoAccount), ['c']);
      expect(run(null), ['a', 'b', 'c', 'd']);
    });

    test('hesap çipleri: arşivli yok, hesapsız yalnız kayıt varsa', () {
      List<String?> chips(bool hasNoAccount) => buildAccountChips(
            accounts: const [cash, enpara, archived],
            hasNoAccountTxs: hasNoAccount,
            str: str,
            cashLabel: 'Nakit',
          ).map((c) => c.id).toList();
      expect(chips(false), [null, Account.cashId, 'enpara']);
      expect(chips(true), [null, Account.cashId, 'enpara', kJournalNoAccount]);
      expect(showAccountSection(const [cash]), isFalse);
      expect(showAccountSection(const [cash, archived]), isFalse);
      expect(showAccountSection(const [cash, enpara]), isTrue);
    });
  });

  // ── alt sayfa: sıralama ──────────────────────────────────────────────

  group('sıralama', () {
    testWidgets('varsayılan: tarih, yeniden eskiye; ok yalnız o satırda',
        (tester) async {
      await pumpJournal(tester);
      expect(ids(tester), ['a', 'b', 'c', 'd']);
      expect(filterButtonLit(tester), isFalse);

      await openSheet(tester);
      expect(find.text(str.sortFilterTitle), findsOneWidget);
      expect(inSheet(down), findsOneWidget);
      expect(inSheet(up), findsNothing);
    });

    testWidgets('tutar: azalan, tekrar dokununca artan (döviz donmuş kurla)',
        (tester) async {
      await pumpJournal(tester);
      await openSheet(tester);
      await tapInSheet(tester, find.text(str.sortAmount));
      expect(inSheet(down), findsOneWidget);
      await apply(tester, str);
      // 10 ₼ = 400 ₺ en üstte: ham tutar olsaydı en altta olurdu.
      expect(ids(tester), ['d', 'b', 'c', 'a']);
      expect(filterButtonLit(tester), isTrue);

      await openSheet(tester);
      await tapInSheet(tester, find.text(str.sortAmount));
      expect(inSheet(up), findsOneWidget);
      expect(inSheet(down), findsNothing);
      await apply(tester, str);
      expect(ids(tester), ['a', 'c', 'b', 'd']);
    });

    testWidgets('kategori: A→Z, kategorisiz sonda; Z→A yine sonda',
        (tester) async {
      await pumpJournal(tester);
      await openSheet(tester);
      await tapInSheet(tester, find.text(str.sortCategory));
      expect(inSheet(up), findsOneWidget);
      await apply(tester, str);
      expect(ids(tester), ['a', 'd', 'b', 'c']);

      await openSheet(tester);
      await tapInSheet(tester, find.text(str.sortCategory));
      expect(inSheet(down), findsOneWidget);
      await apply(tester, str);
      expect(ids(tester), ['b', 'a', 'd', 'c']);
    });

    testWidgets('tarih satırına tekrar dokununca eskiden yeniye', (tester) async {
      await pumpJournal(tester);
      await openSheet(tester);
      await tapInSheet(tester, find.text(str.sortDate));
      expect(inSheet(up), findsOneWidget);
      await apply(tester, str);
      expect(ids(tester), ['d', 'c', 'b', 'a']);
      expect(filterButtonLit(tester), isTrue);

      // Geri çevirince varsayılan: düğme söner.
      await openSheet(tester);
      await tapInSheet(tester, find.text(str.sortDate));
      await apply(tester, str);
      expect(ids(tester), ['a', 'b', 'c', 'd']);
      expect(filterButtonLit(tester), isFalse);
    });
  });

  // ── alt sayfa: hesap ─────────────────────────────────────────────────

  group('hesap', () {
    testWidgets('çip listeyi daraltır; arşivli hesap çip olmaz', (tester) async {
      await pumpJournal(tester);
      await openSheet(tester);
      expect(inSheet(find.text(str.accountLabel.toUpperCase())), findsOneWidget);
      expect(inSheet(find.text('Eski Kart')), findsNothing);

      await tapInSheet(tester, find.text('Enpara Maaş Hesabı'));
      await apply(tester, str);
      expect(ids(tester), ['b', 'd']);
      expect(filterButtonLit(tester), isTrue);
    });

    testWidgets('"Hesapsız" çipi hesapsız kayıtları süzer', (tester) async {
      await pumpJournal(tester);
      await openSheet(tester);
      await tapInSheet(tester, find.text(str.filterNoAccount));
      await apply(tester, str);
      expect(ids(tester), ['c']);
    });

    // Ayrı test: aynı testte ikinci pumpWidget aynı ağacı günceller,
    // ekran durumu ve ProviderScope override'ları eskisinde kalır.
    testWidgets('hepsi hesaplıysa "Hesapsız" çipi yok', (tester) async {
      await pumpJournal(
        tester,
        transactions: txs.where((t) => t.accountId != null).toList(),
      );
      await openSheet(tester);
      expect(inSheet(find.text(str.filterNoAccount)), findsNothing);
      expect(inSheet(find.text(str.filterAll)), findsOneWidget);
    });

    testWidgets('tek hesapta hesap bölümü çizilmez', (tester) async {
      await pumpJournal(tester, accounts: const [cash]);
      await openSheet(tester);
      expect(inSheet(find.text(str.accountLabel.toUpperCase())), findsNothing);
      expect(inSheet(find.text(str.filterAll)), findsNothing);
      expect(inSheet(find.text('Nakit')), findsNothing);
      // Diğer bölümler yerinde.
      expect(inSheet(find.text(str.periodLabel.toUpperCase())), findsOneWidget);
      expect(inSheet(find.text(str.categoriesLabel.toUpperCase())),
          findsOneWidget);
    });
  });

  // ── alt sayfa: dönem + kategori ──────────────────────────────────────

  group('dönem', () {
    testWidgets('"Bu ay" ve "30 gün" farklı seçimler verir', (tester) async {
      await pumpJournal(tester);
      await openSheet(tester);
      await tapInSheet(tester, find.text(str.periodThisMonth));
      await apply(tester, str);
      expect(ids(tester), ['a', 'b', 'c']);

      await openSheet(tester);
      await tapInSheet(tester, find.text(str.periodLast30));
      await apply(tester, str);
      expect(ids(tester), ['a', 'b']);

      await openSheet(tester);
      await tapInSheet(tester, find.text(str.periodAllTime));
      await apply(tester, str);
      expect(ids(tester), ['a', 'b', 'c', 'd']);
      expect(filterButtonLit(tester), isFalse);
    });

    testWidgets('kategori çipi çoklu seçim', (tester) async {
      await pumpJournal(tester);
      await openSheet(tester);
      await tapInSheet(tester, find.text('Ulaşım'));
      await apply(tester, str);
      expect(ids(tester), ['b']);

      await openSheet(tester);
      await tapInSheet(tester, find.text('Market'));
      await apply(tester, str);
      expect(ids(tester), ['a', 'b', 'd']);
    });
  });

  // ── dar ekran × dil ──────────────────────────────────────────────────

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('${width.toInt()}dp · ${lang.code}: alt sayfa taşmaz',
          (tester) async {
        await pumpJournal(tester, language: lang, width: width);
        expect(tester.takeException(), isNull);

        await openSheet(tester);
        final s = strOf(lang);
        expect(find.text(s.sortFilterTitle), findsOneWidget);
        expect(inSheet(find.text(s.sortByLabel.toUpperCase())), findsOneWidget);
        expect(inSheet(find.text(s.accountLabel.toUpperCase())), findsOneWidget);
        expect(inSheet(find.text(s.periodLabel.toUpperCase())), findsOneWidget);
        expect(tester.takeException(), isNull);

        await apply(tester, s);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
