import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/formatters.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/budget/budget_period.dart';
import 'package:kopilka_app/features/budget/budget_screen.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';
import 'package:kopilka_app/features/pro/pro_state.dart';
import 'package:kopilka_app/features/root/bottom_tab_bar.dart';
import 'package:kopilka_app/features/root/root_screen.dart';
import 'package:kopilka_app/features/settings/settings_appearance_screen.dart';
import 'package:kopilka_app/features/transactions/ai_add_sheet.dart';
import 'package:kopilka_app/features/transactions/receipt_scan.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// "1.0 AI'SIZ" hâli (bkz. pro_state.dart, [kAiEnabled]): fiş tarama,
/// yaz/söyle hızlı giriş ve bütçe önerisini inceltme KAPALI — ve arayüzde
/// hiçbir izi yok: kart yok, "yakında" yok, uyarı yok, ayar satırı yok,
/// onboarding vaadi yok. Bütçe "Öner" ise AI'sız da tam çalışır (yerel
/// autoSplit).
///
/// AI 1.1'de geri gelince ([kAiEnabled] = true) bu dosya anlamını yitirir:
/// dört kartlı "+" sayfası, sesli giriş dili satırı ve AI'lı onboarding
/// metinleri için eski testler git geçmişinde.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  test('kAiEnabled 1.0 için kapalı', () {
    // Bayrak yanlışlıkla açılırsa her AI çağrısı Anthropic'e gider ve
    // faturayı biz öderiz; üstelik fonksiyon deploy edilmedi. En önce bunu söyle.
    expect(kAiEnabled, isFalse,
        reason: 'AI 1.1\'de Pro ile birlikte açılacak (docs/PRO_PLAN.md)');
  });

  RS rsOf(AppLanguage lang) => RS.of(lang.code);
  Strings strOf(AppLanguage lang) => switch (lang) {
        AppLanguage.en => Strings.en,
        AppLanguage.tr => Strings.tr,
        AppLanguage.ru => Strings.ru,
      };

  // ── "+" seçim sayfası ─────────────────────────────────────────────────

  group('"+" seçim sayfası', () {
    /// Kartın dokunma yüzeyi (InkWell) — etiketten yukarı en yakın olan.
    Finder card(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

    for (final width in [320.0, 360.0]) {
      for (final lang in AppLanguage.values) {
        testWidgets(
            '${width.toInt()}dp · ${lang.code}: iki kart yan yana, eşit; '
            'AI kartı ve metni yok', (tester) async {
          await pumpBudgyScreen(
            tester,
            const RootScreen(),
            db: FakeFirebaseFirestore(),
            language: lang,
            logicalSize: Size(width, 800),
          );
          await tester.tap(find.byKey(kBottomTabAddKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final rs = rsOf(lang);
          final str = strOf(lang);
          expect(find.text(rs.addSheetTitle), findsOneWidget);
          expect(find.text(rs.addExpenseManual), findsOneWidget);
          expect(find.text(rs.addIncomeManual), findsOneWidget);
          // AI'nın hiçbir izi yok.
          expect(find.text(rs.addScanReceipt), findsNothing);
          expect(find.text(rs.addByVoice), findsNothing);
          expect(find.byIcon(Icons.document_scanner_outlined), findsNothing);
          expect(find.byIcon(Icons.mic_rounded), findsNothing);
          expect(find.text(rs.aiKeyMissing), findsNothing);
          expect(find.text(str.aiAddTitle), findsNothing);
          expect(find.text(rs.paywallBrand), findsNothing);

          // Tek sıra iki kart: aynı hizada, aynı genişlikte, ekrana sığıyor —
          // "delikli 2×2" değil, tasarımın kendisi gibi.
          final a = tester.getRect(card(rs.addExpenseManual));
          final b = tester.getRect(card(rs.addIncomeManual));
          expect(a.top, moreOrLessEquals(b.top, epsilon: 0.5));
          expect(a.width, moreOrLessEquals(b.width, epsilon: 1));
          expect(a.height, moreOrLessEquals(b.height, epsilon: 0.5));
          expect(a.left, greaterThanOrEqualTo(0));
          expect(b.right, lessThanOrEqualTo(width));
          expect(b.left, greaterThan(a.right));
        });
      }
    }
  });

  // ── giriş noktaları: ikinci kilit ──────────────────────────────────────
  //
  // "+" sayfası kartları çizmese de fonksiyonlar doğrudan çağrılırsa
  // (ileride başka bir yol eklenirse) yine hiçbir şey olmamalı: sayfa yok,
  // uyarı yok.

  group('AI giriş noktaları', () {
    Future<void> pumpButton(
      WidgetTester tester,
      Future<void> Function(BuildContext context, WidgetRef ref) onTap,
    ) =>
        pumpBudgyScreen(
          tester,
          Scaffold(
            body: Center(
              child: Consumer(
                builder: (context, ref, _) {
                  ref.watch(rsProvider);
                  return TextButton(
                    onPressed: () => onTap(context, ref),
                    child: const Text('aç'),
                  );
                },
              ),
            ),
          ),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr,
        );

    testWidgets('startReceiptScan: kaynak sayfası da uyarı da yok', (
      tester,
    ) async {
      await pumpButton(tester, startReceiptScan);
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.text(RS.tr.scanTitle), findsNothing);
      expect(find.text(RS.tr.camera), findsNothing);
      expect(find.text(RS.tr.aiKeyMissing), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('showAiAdd: sayfa açılmaz', (tester) async {
      await pumpButton(tester, (context, _) => showAiAdd(context));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.text(Strings.tr.aiAddTitle), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  // ── Ayarlar → Görünüm ─────────────────────────────────────────────────

  group('Ayarlar → Görünüm', () {
    for (final lang in AppLanguage.values) {
      testWidgets('${lang.code}: sesli giriş dili satırı yok, açıklama sessiz',
          (tester) async {
        await pumpBudgyScreen(
          tester,
          const SettingsAppearanceScreen(),
          db: FakeFirebaseFirestore(),
          language: lang,
        );
        final rs = rsOf(lang);
        expect(find.text(rs.voiceLanguage), findsNothing);
        expect(find.text(rs.voiceAppLanguage), findsNothing);
        expect(find.byIcon(Icons.mic_rounded), findsNothing);
        expect(find.text(rs.hubAppearanceBodyNoVoice), findsOneWidget);
        expect(find.text(rs.hubAppearanceBody), findsNothing);
        // Kalan satırlar yerinde.
        expect(find.text(rs.keypadLayout), findsOneWidget);
        expect(find.text(strOf(lang).languageTitle), findsOneWidget);
        expect(find.text(strOf(lang).currencyTitle), findsOneWidget);
      });
    }
  });

  // ── Onboarding ────────────────────────────────────────────────────────

  group('Onboarding', () {
    testWidgets('hızlı giriş tanıtımı: sesle/fiş vaadi yok, maket çipleri yok',
        (tester) async {
      await pumpBudgyScreen(
        tester,
        const OnboardingFlow(preview: true, initialStep: 1),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.en,
      );
      expect(find.text(RS.en.introFastTitle), findsOneWidget);
      expect(find.text(RS.en.introFastSubtitleNoAi), findsOneWidget);
      expect(find.text(RS.en.introFastSubtitle), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.document_scanner_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"alışkanlık" cevabı: sesle/fiş vaadi yok', (tester) async {
      await pumpBudgyScreen(
        tester,
        const OnboardingFlow(preview: true, initialStep: 4),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.en,
      );
      await tester.tap(find.text(RS.en.qMoodGood));
      await tester.pumpAndSettle();
      await tester.tap(find.text(RS.en.next));
      await tester.pumpAndSettle();
      await tester.tap(find.text(RS.en.qHardHabit));
      await tester.pumpAndSettle();
      await tester.tap(find.text(RS.en.next));
      await tester.pumpAndSettle();

      expect(find.text(RS.en.rHabitTitle), findsOneWidget);
      expect(find.text(RS.en.rHabitBodyNoAi), findsOneWidget);
      expect(find.text(RS.en.rHabitBody), findsNothing);
    });

    test('AI\'sız metinler üç dilde gerçekten AI\'dan söz etmiyor', () {
      // Metin sonradan düzenlenirse vaadin geri sızmadığını yakalar.
      const banned = [
        'scan', 'receipt', 'say it', 'voice', // en
        'fiş', 'sesle', 'sesli', 'tara', // tr
        'чек', 'голос', 'надикт', 'скан', // ru
      ];
      for (final rs in [RS.en, RS.tr, RS.ru]) {
        for (final text in [
          rs.introFastSubtitleNoAi,
          rs.rHabitBodyNoAi,
          rs.hubAppearanceBodyNoVoice,
        ]) {
          final lower = text.toLowerCase();
          for (final word in banned) {
            expect(lower, isNot(contains(word)), reason: '"$text"');
          }
        }
      }
    });
  });

  // ── Bütçe dağılımı ────────────────────────────────────────────────────

  group('Bütçe · Öner', () {
    final now = DateTime.now();
    final envelopes = <Envelope>[
      testEnvelope(id: 'e1', name: 'Market ve Temel Gıda'),
      testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', sortOrder: 1),
    ];
    final txs = <Tx>[
      Tx(id: 't1', type: TxType.expense, amount: 1200, date: now, envelopeId: 'e1'),
      Tx(
        id: 't2',
        type: TxType.expense,
        amount: 300,
        date: now.subtract(const Duration(days: 2)),
        envelopeId: 'e2',
      ),
    ];

    testWidgets('AI olmadan yerel dağılım alanları doldurur; bekleme ve hata yok',
        (tester) async {
      await pumpBudgyScreen(
        tester,
        const BudgetCategoriesStep(
          settings: BudgetSettings(amount: 15000, period: BudgetPeriod.monthly),
        ),
        db: FakeFirebaseFirestore(),
        envelopes: envelopes,
        transactions: txs,
        language: AppLanguage.tr,
      );
      // Başta alanlar boş.
      for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(f.controller!.text, isEmpty);
      }

      await tester.tap(find.text(RS.tr.suggest));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(RS.tr.notEnoughData), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      // Bekleme etiketi ("…") hiç kalmadı: AI çağrısı yok, sonuç anında.
      expect(find.text('…'), findsNothing);
      expect(find.text(RS.tr.suggest), findsOneWidget);

      // autoSplit: 1200:300 → 12000 / 3000, toplam 15000.
      final values = [
        for (final f in tester.widgetList<TextField>(find.byType(TextField)))
          parseAmount(f.controller!.text),
      ];
      expect(values, hasLength(2));
      expect(values, everyElement(isNotNull));
      expect(values.map((v) => v!).reduce((a, b) => a + b), 15000);
      expect(values, containsAll([12000.0, 3000.0]));
    });
  });
}
