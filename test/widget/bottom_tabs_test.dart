import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/envelopes/home_screen.dart';
import 'package:kopilka_app/features/root/bottom_tab_bar.dart';
import 'package:kopilka_app/features/root/root_screen.dart';
import 'package:kopilka_app/features/transactions/journal_screen.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';
import 'package:kopilka_app/features/workdays/calendar_screen.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

import '../support/harness.dart';

/// Alt sekme çubuğu: üç sekme + "+" seçim sayfası, kaydırmayla gizlenme,
/// sekme durumunun korunması, sekmede geri düğmesinin olmaması, dar
/// ekranlarda taşmama.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final now = DateTime.now();
  final envelopes = <Envelope>[
    testEnvelope(id: 'e1', name: 'Market ve Temel Gıda', balance: 4500),
    testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', balance: 1200),
    testEnvelope(
      id: 'usd',
      name: 'Dolar Birikimi',
      emoji: '💵',
      balance: 1750,
      currency: 'USD',
    ),
  ];
  // Yeterince uzun bir liste: ana ekran 600dp yükseklikte kaydırılabilsin.
  final transactions = <Tx>[
    for (var i = 0; i < 8; i++)
      Tx(
        id: 't$i',
        type: TxType.expense,
        amount: 100.0 + i,
        date: now.subtract(Duration(days: i)),
        envelopeId: 'e1',
        envelopeName: 'Market ve Temel Gıda',
        note: 'Alışveriş $i',
      ),
  ];
  final workDays = <WorkDay>[
    for (var i = 0; i < 5; i++)
      WorkDay(
        id: 'd$i',
        date: DateTime(now.year, now.month, now.day).subtract(
          Duration(days: i),
        ),
        amount: 1500 + i * 100,
      ),
  ];

  Future<void> pumpRoot(
    WidgetTester tester, {
    Widget screen = const RootScreen(),
    AppLanguage language = AppLanguage.tr,
    Size size = const Size(360, 600),
    bool pro = false,
  }) async {
    final db = FakeFirebaseFirestore();
    for (final e in envelopes) {
      await seedEnvelope(db, e);
    }
    await pumpBudgyScreen(
      tester,
      screen,
      db: db,
      envelopes: envelopes,
      transactions: transactions,
      workDays: workDays,
      language: language,
      logicalSize: size,
      pro: pro,
    );
  }

  final tabHome = find.text(RS.tr.tabHome);
  final tabJournal = find.text(RS.tr.tabJournal);
  final tabCalendar = find.text(RS.tr.tabCalendar);
  final addButton = find.byKey(kBottomTabAddKey);
  final journalTitle = find.text(Strings.tr.historyTitle);
  final calendarTitle = find.text(Strings.tr.workDaysTitle);
  final badge = find.text(RS.tr.paywallProPill);
  final paywall = find.text(RS.tr.paywallBrand);

  bool barVisible(WidgetTester tester) =>
      tester.widget<BottomTabBar>(find.byType(BottomTabBar)).visible;

  /// Ana ekranın dikey listesi (yatay hesap listesi değil).
  Finder homeList() => find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  );

  double homeOffset(WidgetTester tester) => tester
      .state<ScrollableState>(homeList().first)
      .position
      .pixels;

  Offset slideOf(WidgetTester tester) => tester
      .widget<SlideTransition>(
        find.descendant(
          of: find.byType(BottomTabBar),
          matching: find.byType(SlideTransition),
        ),
      )
      .position
      .value;

  // ── sekmeler ─────────────────────────────────────────────────────────

  group('sekmeler', () {
    testWidgets('üç sekme görünür; dokununca içerik değişir', (tester) async {
      await pumpRoot(tester);

      expect(tabHome, findsOneWidget);
      expect(tabJournal, findsOneWidget);
      expect(tabCalendar, findsOneWidget);
      expect(addButton, findsOneWidget);
      // Başlangıç: ana ekran sahnede, diğerleri sahne dışı.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(journalTitle, findsNothing);
      expect(calendarTitle, findsNothing);

      await tester.tap(tabJournal);
      await tester.pumpAndSettle();
      expect(journalTitle, findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(tabCalendar);
      await tester.pumpAndSettle();
      expect(calendarTitle, findsOneWidget);
      expect(journalTitle, findsNothing);

      await tester.tap(tabHome);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('sekme durumu korunur: ana ekranın kaydırması yerinde kalır', (
      tester,
    ) async {
      await pumpRoot(tester);

      await tester.drag(find.byType(HomeScreen), const Offset(0, -250));
      await tester.pumpAndSettle();
      // Aşağı okurken çubuk gizlendi; kısa bir yukarı çekişle geri getir
      // (liste hâlâ tepede değil) ki sekmeye dokunulabilsin.
      await tester.drag(find.byType(HomeScreen), const Offset(0, 60));
      await tester.pumpAndSettle();
      final scrolled = homeOffset(tester);
      expect(scrolled, greaterThan(0));
      expect(barVisible(tester), isTrue);

      await tester.tap(tabCalendar);
      await tester.pumpAndSettle();
      expect(calendarTitle, findsOneWidget);

      await tester.tap(tabHome);
      await tester.pumpAndSettle();
      expect(homeOffset(tester), scrolled);
    });

    testWidgets('sekmede geri düğmesi yok (journal + takvim)', (tester) async {
      await pumpRoot(tester);

      await tester.tap(tabJournal);
      await tester.pumpAndSettle();
      expect(find.byType(BudgyBackButton), findsNothing);

      await tester.tap(tabCalendar);
      await tester.pumpAndSettle();
      expect(find.byType(BudgyBackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });
  });

  // ── kaydırmayla gizlenme ──────────────────────────────────────────────

  group('kaydırma', () {
    testWidgets('aşağı okurken gizlenir, yukarı kaydırınca döner', (
      tester,
    ) async {
      await pumpRoot(tester);
      expect(barVisible(tester), isTrue);

      // İçerik yukarı (okumaya devam) → çubuk gider.
      await tester.drag(find.byType(HomeScreen), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(barVisible(tester), isFalse);

      // Biraz geri (yukarı okuma) → çubuk döner, en üstte olmasa da.
      await tester.drag(find.byType(HomeScreen), const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(homeOffset(tester), greaterThan(0));
      expect(barVisible(tester), isTrue);
    });

    testWidgets('en üstteyken her zaman görünür', (tester) async {
      await pumpRoot(tester);

      await tester.drag(find.byType(HomeScreen), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(barVisible(tester), isFalse);

      // Programatik olarak tepeye dön: yön bildirimi yok, yalnız konum.
      tester.state<ScrollableState>(homeList().first).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(homeOffset(tester), 0);
      expect(barVisible(tester), isTrue);

      // En üstte aşağı doğru (yukarı okuma) çekmek de görünür bırakır.
      await tester.drag(find.byType(HomeScreen), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(barVisible(tester), isTrue);
    });

    testWidgets('gizliyken dokunuşu yutmaz, sekme değişince geri gelir', (
      tester,
    ) async {
      await pumpRoot(tester);
      await tester.drag(find.byType(HomeScreen), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(barVisible(tester), isFalse);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: find.byType(BottomTabBar),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );

      // Sekme değişimi çubuğu geri getirir (yeni sekmenin kaydırma geçmişi
      // eskisiyle ilgisiz).
      await tester.tap(tabJournal, warnIfMissed: false);
      await tester.pumpAndSettle();
      // Gizli çubuğa dokunuş ulaşmaz: hâlâ ana ekranda.
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('hareket azaltmada anında gizlenir, ticker askıda kalmaz', (
      tester,
    ) async {
      // pumpBudgyScreen disableAnimations: true ile kurar.
      await pumpRoot(tester);
      expect(slideOf(tester), Offset.zero);

      await tester.drag(find.byType(HomeScreen), const Offset(0, -250));
      // Tek kare: sıfır süreli geçiş hedefte olmalı.
      await tester.pump();
      expect(barVisible(tester), isFalse);
      expect(slideOf(tester), const Offset(0, 1.5));
      // Askıda ticker olsaydı pumpAndSettle zaman aşımına düşerdi.
      await tester.pumpAndSettle();
      expect(slideOf(tester), const Offset(0, 1.5));
    });

    testWidgets('hareket açıkken yaklaşık 200 ms içinde kayar', (tester) async {
      await pumpRoot(
        tester,
        screen: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: false),
            child: const RootScreen(),
          ),
        ),
      );
      expect(slideOf(tester), Offset.zero);

      await tester.drag(find.byType(HomeScreen), const Offset(0, -250));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = slideOf(tester).dy;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1.5));

      await tester.pump(const Duration(milliseconds: 200));
      expect(slideOf(tester), const Offset(0, 1.5));
      await tester.pumpAndSettle();
    });
  });

  // ── "+" seçim sayfası ─────────────────────────────────────────────────

  group('"+" seçim sayfası', () {
    Future<void> openSheet(WidgetTester tester, {bool pro = false}) async {
      await pumpRoot(tester, pro: pro);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
    }

    testWidgets('dört kart; hiçbirinde Pro rozeti yok', (tester) async {
      await openSheet(tester);

      expect(find.text(RS.tr.addSheetTitle), findsOneWidget);
      expect(find.text(RS.tr.addExpenseManual), findsOneWidget);
      expect(find.text(RS.tr.addIncomeManual), findsOneWidget);
      expect(find.text(RS.tr.addScanReceipt), findsOneWidget);
      expect(find.text(RS.tr.addByVoice), findsOneWidget);
      // Rozet kaldırıldı: dört kart aynı görünüyor, kilit basınca anlaşılıyor.
      expect(badge, findsNothing);
    });

    testWidgets('Pro kullanıcı da aynı dört kartı görür', (tester) async {
      await openSheet(tester, pro: true);

      expect(find.text(RS.tr.addScanReceipt), findsOneWidget);
      expect(find.text(RS.tr.addByVoice), findsOneWidget);
      expect(badge, findsNothing);
    });

    testWidgets('elle gider → hızlı giriş ekranı', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text(RS.tr.addExpenseManual));
      await tester.pumpAndSettle();

      expect(find.byType(QuickEntryScreen), findsOneWidget);
      expect(find.text(RS.tr.addSheetTitle), findsNothing);
    });

    testWidgets('elle gelir → hızlı giriş ekranı', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text(RS.tr.addIncomeManual));
      await tester.pumpAndSettle();

      expect(find.byType(QuickEntryScreen), findsOneWidget);
    });

    // "1.0 ÜCRETSİZ": fiş tarama ve sesli giriş herkese açık, paywall yok
    // (bkz. pro_state.dart, kProEnabled). Abonelik geri gelince bu dört test
    // eski kilitli hâle (Pro değilse paywall) geri yazılmalı.

    testWidgets('fiş tara: abonesi olmayan için paywall yok, tarama akışı', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text(RS.tr.addScanReceipt));
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
      // Testte API anahtarı yok: akışın ilk adımı bunu söyler — kilit yok.
      expect(find.text(RS.tr.aiKeyMissing), findsOneWidget);
    });

    testWidgets('fiş tara: Pro ise de tarama akışı', (tester) async {
      await openSheet(tester, pro: true);
      await tester.tap(find.text(RS.tr.addScanReceipt));
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
      expect(find.text(RS.tr.aiKeyMissing), findsOneWidget);
    });

    testWidgets('sesle ekle: abonesi olmayan için paywall yok', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text(RS.tr.addByVoice));
      await tester.pumpAndSettle();
      expect(paywall, findsNothing);
      expect(find.text(Strings.tr.aiAddTitle), findsOneWidget);
    });

    testWidgets('sesle ekle: Pro ise de paywall yok', (tester) async {
      await openSheet(tester, pro: true);
      await tester.tap(find.text(RS.tr.addByVoice));
      await tester.pumpAndSettle();
      expect(paywall, findsNothing);
    });
  });

  // ── push ile açılınca geri düğmesi ────────────────────────────────────

  group('push modu', () {
    for (final entry in <String, Widget Function()>{
      'journal': () => const JournalScreen(),
      'takvim': () => const CalendarScreen(),
    }.entries) {
      testWidgets('${entry.key}: push edilince geri düğmesi var', (
        tester,
      ) async {
        await pumpRoot(
          tester,
          screen: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => entry.value()),
                  ),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();

        expect(find.byType(BudgyBackButton), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        expect(find.text('aç'), findsOneWidget);
      });
    }

    testWidgets('embedded: tek başına da geri düğmesi çizmez', (tester) async {
      await pumpRoot(tester, screen: const JournalScreen(embedded: true));
      expect(find.byType(BudgyBackButton), findsNothing);

      await pumpRoot(tester, screen: const CalendarScreen(embedded: true));
      expect(find.byType(BudgyBackButton), findsNothing);
    });
  });

  // ── dar ekran × dil ───────────────────────────────────────────────────

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('${width.toInt()}dp · ${lang.code}: sekmeler ve sayfa taşmaz', (
        tester,
      ) async {
        await pumpRoot(tester, language: lang, size: Size(width, 800));
        expect(tester.takeException(), isNull);

        final rs = RS.of(lang.code);
        await tester.tap(find.text(rs.tabJournal));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(rs.tabCalendar));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(addButton);
        await tester.pumpAndSettle();
        expect(find.text(rs.addSheetTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
