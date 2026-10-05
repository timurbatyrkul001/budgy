import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/automation/automation_screen.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/pro/pro_state.dart';
import 'package:kopilka_app/features/recurring/recurring_screen.dart';
import 'package:kopilka_app/features/root/bottom_tab_bar.dart';
import 'package:kopilka_app/features/root/root_screen.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';

import '../support/harness.dart';

/// "1.0 ÜCRETSİZ" hâli: Pro kilitleri KAPALI (bkz. pro_state.dart,
/// [kProEnabled]). Satın alma altyapısı olmadan App Store'a çıkıldığı için
/// bütün Pro özellikleri herkese açık; paywall hiçbir yoldan açılmaz.
///
/// Bu dosya eskiden kilitlerin ÇALIŞTIĞINI doğruluyordu (bulanık ekran,
/// kilit kartı, basınca paywall). Şimdi tersini doğruluyor: abonesi olmayan
/// sıradan kullanıcı (harness'te `pro: false`) kilit görmez, özellik doğrudan
/// açılır ve davranış kilitleri (nottan kategori, tekrarlayan işlem üretimi)
/// herkes için çalışır.
///
/// ABONELİK GERİ GELİNCE ([kProEnabled] = true) bu testler YENİDEN
/// YAZILMALI: eski kilitli davranışın testleri git geçmişinde duruyor.
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
  final lockCard = find.text(RS.tr.proLocked);
  final paywall = find.text(RS.tr.paywallBrand);
  final badge = find.text(RS.tr.paywallProPill);

  test('kProEnabled 1.0 için kapalı', () {
    // Bayrak yanlışlıkla açılırsa bu dosyadaki her test anlamını yitirir;
    // en önce bunu söyle.
    expect(kProEnabled, isFalse,
        reason: 'Satın alma bağlanmadan Pro açılamaz (App Store reddi)');
  });

  // ── A. eski ekran kilitleri: artık yok ────────────────────────────────

  for (final entry in <String, (Widget, String)>{
    'Tekrarlayan işlemler': (const RecurringScreen(), RS.tr.recurringTitle),
    'Kategori otomasyonu': (const AutomationScreen(), RS.tr.automation),
  }.entries) {
    final (screen, title) = entry.value;

    group('${entry.key} · kilit yok', () {
      testWidgets('abonesi olmayan kilit kartı görmez, içerik açık', (
        tester,
      ) async {
        await pumpBudgyScreen(
          tester,
          screen,
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr,
        );

        expect(find.text(title), findsOneWidget);
        expect(lockCard, findsNothing);
        expect(trialButton, findsNothing);
        expect(badge, findsNothing);
        expect(paywall, findsNothing);
      });

      testWidgets('Pro kullanıcı da aynı ekranı görür', (tester) async {
        await pumpBudgyScreen(
          tester,
          screen,
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr,
          pro: true,
        );

        expect(find.text(title), findsOneWidget);
        expect(lockCard, findsNothing);
        expect(trialButton, findsNothing);
      });
    });
  }

  testWidgets('otomasyonda "+" herkes için çalışır: kategori sayfası açılır', (
    tester,
  ) async {
    await pumpBudgyScreen(
      tester,
      const AutomationScreen(),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
    );
    // Eskiden bulanık katman (IgnorePointer) dokunuşu yutuyordu; şimdi
    // düğme gerçekten basılır ve kural ekleme akışı başlar.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text(RS.tr.pickCategory), findsOneWidget);
    expect(paywall, findsNothing);
    expect(lockCard, findsNothing);
  });

  // ── B. eski eylem kilitleri: "+" seçim sayfası (fiş tarama + sesli) ───
  //
  // 1.0'da AI de kapalı ([kAiEnabled] false, pro_state.dart): fiş tarama ve
  // sesle ekleme kartları hiç çizilmiyor, dolayısıyla kilitlenecek eylem de
  // yok. Bu grup artık "iki kart, rozet yok, paywall yok, AI izi yok" hâlini
  // doğruluyor. 1.1'de AI ve abonelik geri gelince dört kart + Pro değilse
  // paywall davranışı yeniden yazılmalı; eski testler git geçmişinde.

  group('"+" seçim sayfası · kilit yok, AI yok', () {
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

    test('kAiEnabled 1.0 için kapalı', () {
      expect(kAiEnabled, isFalse,
          reason: 'AI 1.1\'de Pro ile birlikte açılacak (docs/PRO_PLAN.md)');
    });

    for (final pro in [false, true]) {
      testWidgets(
          'pro=$pro: iki kart; fiş tarama ve sesli giriş kartı yok, rozet ve '
          'paywall yok', (tester) async {
        await openSheet(tester, pro: pro);

        expect(find.text(RS.tr.addExpenseManual), findsOneWidget);
        expect(find.text(RS.tr.addIncomeManual), findsOneWidget);
        expect(scanCard, findsNothing);
        expect(micCard, findsNothing);
        expect(badge, findsNothing);
        expect(paywall, findsNothing);
        // AI'nın hiçbir izi yok: ne "giriş yap" uyarısı ne AI giriş sayfası.
        expect(find.text(RS.tr.aiKeyMissing), findsNothing);
        expect(find.text(Strings.tr.aiAddTitle), findsNothing);
      });
    }
  });

  // ── B. eski eylem kilidi: hızlı girişte tekrar düğmesi ────────────────

  group('hızlı giriş · tekrar düğmesi', () {
    final repeatButton = find.byIcon(Icons.repeat_rounded);

    testWidgets('abonesi olmayan basınca sıklık sayfası açılır, paywall yok', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const QuickEntryScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );

      expect(repeatButton, findsOneWidget);
      expect(badge, findsNothing);

      await tester.tap(repeatButton);
      await tester.pumpAndSettle();

      expect(paywall, findsNothing);
      expect(find.text(RS.tr.repeat), findsOneWidget);
      expect(find.text(RS.tr.monthly), findsOneWidget);
    });
  });

  // ── C. davranış kilidi: nottan kategori otomasyonu herkes için ────────

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

    testWidgets('abonesi olmayan için de kural kategoriyi seçer', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      final tx = await saveWithNote(tester, db, pro: false);
      expect(tx['amount'], 90);
      expect(tx['note'], 'kahve');
      expect(
        tx['envelopeId'],
        isNotNull,
        reason: '1.0: kategori otomasyonu herkes için açık',
      );
      expect(paywall, findsNothing, reason: 'kayıt akışı bölünmez');
    });

    testWidgets('Pro ise de kural kategoriyi seçer', (tester) async {
      final db = FakeFirebaseFirestore();
      final tx = await saveWithNote(tester, db, pro: true);
      expect(tx['envelopeId'], isNotNull);
    });
  });

  // ── D. davranış kilidi: tekrarlayan işlemler herkes için üretilir ─────
  //
  // Kök ekran açılışta vadesi gelen kuralları işler (recurringMaterializer).
  // Eskiden yalnız Pro için izleniyordu; abonesi olmayanın kuralları sessizce
  // dururdu. 1.0'da herkes için izlenmeli — yoksa tekrarlar hiç oluşmaz.

  group('kök ekran · tekrarlayan işlem üretimi', () {
    for (final pro in [false, true]) {
      testWidgets('pro=$pro: materializer açılışta izlenir', (tester) async {
        await pumpBudgyScreen(
          tester,
          const RootScreen(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr,
          pro: pro,
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(RootScreen)),
        );
        expect(
          container.exists(recurringMaterializerProvider),
          isTrue,
          reason: 'kök ekran kuralları herkes için işlemeli',
        );
        expect(container.read(proUnlockedProvider), isTrue);
      });
    }
  });
}
