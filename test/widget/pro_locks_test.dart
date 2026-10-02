import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/automation/automation_screen.dart';
import 'package:kopilka_app/features/recurring/recurring_screen.dart';
import 'package:kopilka_app/features/root/bottom_tab_bar.dart';
import 'package:kopilka_app/features/root/root_screen.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';

import '../support/harness.dart';

/// Pro kilitleri (analiz dışındakiler; analiz için bkz. paywall_test.dart).
///
/// İki kalıp: ekran kilidi (ProGate — içerik bulanık, kilit kartı paywall'a
/// götürür) ve eylem kilidi (düğme görünür, Pro rozeti taşır, basınca
/// paywall açılır). Her kilit için üç soru: Pro olmayan kilidi görür mü,
/// Pro görmez mi, kilide basınca paywall açılır mı?
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final trialButton = find.widgetWithText(
    FilledButton,
    RS.tr.paywallTrialTpl.replaceFirst('{days}', '14'),
  );
  final paywall = find.text(RS.tr.paywallBrand);
  final badge = find.text(RS.tr.paywallProPill);

  // ── A. ekran kilidi ─────────────────────────────────────────────────────

  for (final entry in <String, Widget>{
    'Tekrarlayan işlemler': const RecurringScreen(),
    'Kategori otomasyonu': const AutomationScreen(),
  }.entries) {
    group('${entry.key} · ekran kilidi', () {
      testWidgets('abonesi olmayan kilit kartını görür, içerik ağaçta kalır', (
        tester,
      ) async {
        await pumpBudgyScreen(
          tester,
          entry.value,
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr,
        );

        expect(find.text(RS.tr.proLocked), findsOneWidget);
        expect(trialButton, findsOneWidget);
      });

      testWidgets('Pro kullanıcı kilit görmez', (tester) async {
        await pumpBudgyScreen(
          tester,
          entry.value,
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr,
          pro: true,
        );

        expect(find.text(RS.tr.proLocked), findsNothing);
        expect(trialButton, findsNothing);
      });

      testWidgets('kilit kartına basınca paywall açılır', (tester) async {
        await pumpBudgyScreen(
          tester,
          entry.value,
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr,
        );

        await tester.tap(trialButton);
        await tester.pumpAndSettle();

        expect(paywall, findsOneWidget);
      });
    });
  }

  testWidgets('tekrarlayan ekranı kilitliyken başlık bulanık ama yerinde', (
    tester,
  ) async {
    await pumpBudgyScreen(
      tester,
      const RecurringScreen(),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
    );
    // İçerik silinmiyor, bulanıklaştırılıyor.
    expect(find.text(RS.tr.recurringTitle), findsOneWidget);
  });

  testWidgets('otomasyon kilitliyken "+" düğmesine basılamaz', (tester) async {
    await pumpBudgyScreen(
      tester,
      const AutomationScreen(),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
    );
    // Bulanık katman IgnorePointer: dokunuş yutulur, kategori sayfası açılmaz.
    await tester.tap(find.byIcon(Icons.add_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(RS.tr.proLocked), findsOneWidget);
    expect(paywall, findsNothing);
  });

  // ── B. eylem kilidi: "+" seçim sayfası (fiş tarama + sesli giriş) ───────
  //
  // Dock kaldırıldı: fiş tarama ve sesli giriş artık kök ekrandaki "+"
  // düğmesinin açtığı seçim sayfasında kart. Kilit davranışı aynı.

  group('"+" seçim sayfası · eylem kilidi', () {
    final scanCard = find.text(RS.tr.addScanReceipt);
    final micCard = find.text(RS.tr.addByVoice);

    Future<void> openSheet(WidgetTester tester, {bool pro = false}) async {
      await pumpBudgyScreen(
        tester,
        const RootScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        pro: pro,
      );
      await tester.tap(find.byKey(kBottomTabAddKey));
      await tester.pumpAndSettle();
    }

    testWidgets('abonesi olmayan kilitli kartları görür; rozet yok', (
      tester,
    ) async {
      await openSheet(tester);

      // Kartlar gizlenmiyor — gizlenen özellik satılamaz. Ama rozet de yok:
      // kilidi paywall anlatıyor, listede dört kart aynı duruyor.
      expect(scanCard, findsOneWidget);
      expect(micCard, findsOneWidget);
      expect(badge, findsNothing);
    });

    testWidgets('Pro kullanıcı aynı kartları görür', (tester) async {
      await openSheet(tester, pro: true);

      expect(scanCard, findsOneWidget);
      expect(micCard, findsOneWidget);
      expect(badge, findsNothing);
    });

    testWidgets('fiş tarama: Pro değilse paywall, kaynak seçimi açılmaz', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(scanCard);
      await tester.pumpAndSettle();

      expect(paywall, findsOneWidget);
      expect(find.text(RS.tr.scanTitle), findsNothing);
      // AI anahtarı yok uyarısı bile çıkmaz: AI yoluna hiç girilmedi.
      expect(find.text(RS.tr.aiKeyMissing), findsNothing);
    });

    testWidgets('fiş tarama: Pro ise paywall açılmaz, tarama akışı başlar', (
      tester,
    ) async {
      await openSheet(tester, pro: true);

      await tester.tap(scanCard);
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
      // Testte API anahtarı yok: akış ilk adımında "anahtar yok" der. Bu,
      // kilidin geçildiğinin kanıtı — paywall değil, özelliğin kendisi konuştu.
      expect(find.text(RS.tr.aiKeyMissing), findsOneWidget);
    });

    testWidgets('sesli giriş: Pro değilse paywall', (tester) async {
      await openSheet(tester);

      await tester.tap(micCard);
      await tester.pumpAndSettle();

      expect(paywall, findsOneWidget);
    });

    testWidgets('sesli giriş: Pro ise paywall açılmaz', (tester) async {
      await openSheet(tester, pro: true);

      await tester.tap(micCard);
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
    });
  });

  // ── B. eylem kilidi: hızlı girişte tekrar düğmesi ───────────────────────

  group('hızlı giriş · tekrar düğmesi', () {
    final repeatButton = find.byIcon(Icons.repeat_rounded);

    testWidgets('abonesi olmayan düğmeyi görür (rozetsiz); basınca paywall', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const QuickEntryScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );

      // Düğme gizlenmiyor ama "Pro" etiketi de taşımıyor: kilidi paywall
      // anlatıyor. Rozetler arayüzden tamamen kaldırıldı.
      expect(repeatButton, findsOneWidget);
      expect(badge, findsNothing);

      await tester.tap(repeatButton);
      await tester.pumpAndSettle();

      expect(paywall, findsOneWidget);
      expect(
        find.text(RS.tr.repeat),
        findsNothing,
        reason: 'sıklık sayfası açılmamalı',
      );
    });

    testWidgets('Pro: basınca sıklık sayfası açılır', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const QuickEntryScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        pro: true,
      );

      expect(badge, findsNothing);

      await tester.tap(repeatButton);
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
      expect(find.text(RS.tr.repeat), findsOneWidget);
      expect(find.text(RS.tr.monthly), findsOneWidget);
    });
  });

  // ── C. sessiz atlama: nottan kategori otomasyonu ────────────────────────

  group('hızlı giriş · nottan kategori', () {
    Future<Map<String, dynamic>> saveWithNote(
      WidgetTester tester,
      FakeFirebaseFirestore db, {
      required bool pro,
    }) async {
      await pumpBudgyScreen(
        tester,
        const QuickEntryScreen(),
        db: db,
        language: AppLanguage.tr,
        pro: pro,
      );

      for (final k in ['9', '0']) {
        await tester.tap(find.widgetWithText(InkWell, k).last);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      // Not: "kahve" yerleşik kuralla Kahve kategorisine eşleşir.
      await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kahve');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, RS.tr.save));
      await tester.pumpAndSettle();

      final snap = await db
          .collection('users')
          .doc(testUid)
          .collection('transactions')
          .get();
      expect(snap.docs, hasLength(1));
      return snap.docs.single.data();
    }

    testWidgets('Pro değilse kural çalışmaz, kayıt kategorisiz düşer', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      final tx = await saveWithNote(tester, db, pro: false);
      expect(tx['amount'], 90);
      expect(tx['note'], 'kahve');
      expect(
        tx['envelopeId'],
        isNull,
        reason: 'otomasyon Pro; sessizce atlanır, hata yok',
      );
      expect(paywall, findsNothing, reason: 'kayıt akışı bölünmez');
    });

    testWidgets('Pro ise kural kategoriyi seçer', (tester) async {
      final db = FakeFirebaseFirestore();
      final tx = await saveWithNote(tester, db, pro: true);
      expect(tx['envelopeId'], isNotNull);
    });
  });
}
