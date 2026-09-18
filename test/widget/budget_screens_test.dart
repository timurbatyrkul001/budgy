import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/budget/budget_period.dart';
import 'package:kopilka_app/features/budget/budget_screen.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Bütçe ekranları (boş / tutar / kategori) ve Analiz dar ekranda taşmaz;
/// tutar adımı Devam'ı 0'da kilitler; kategori adımı Kaydet ile ayarı ve
/// zarf limitlerini yazar.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final now = DateTime.now();
  final envelopes = [
    testEnvelope(id: 'e1', name: 'Market ve Temel Gıda', targetAmount: 8000),
    testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', sortOrder: 1),
  ];
  final txs = [
    Tx(id: 't1', type: TxType.expense, amount: 1200, date: now, envelopeId: 'e1'),
    Tx(id: 't2', type: TxType.expense, amount: 300,
        date: now.subtract(const Duration(days: 2)), envelopeId: 'e2'),
    Tx(id: 't3', type: TxType.expense, amount: 640,
        date: now.subtract(const Duration(days: 1))),
  ];

  final screens = <String, Widget>{
    'Bütçe (boş)': const BudgetScreen(),
    'Bütçe tutar (haftalık)':
        const BudgetAmountStep(initialPeriod: BudgetPeriod.weekly),
    'Bütçe tutar (aylık)':
        const BudgetAmountStep(initialPeriod: BudgetPeriod.monthly),
    'Kategori bütçeleri': const BudgetCategoriesStep(
        settings: BudgetSettings(amount: 15000, period: BudgetPeriod.monthly),
        autoSuggest: true),
    'Analiz (geçen ay, boş)': const StatsScreen(initialMonthOffset: -1),
  };

  for (final width in [320.0, 360.0]) {
    for (final entry in screens.entries) {
      for (final lang in AppLanguage.values) {
        testWidgets('${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
          await pumpBudgyScreen(
            tester,
            entry.value,
            db: FakeFirebaseFirestore(),
            envelopes: envelopes,
            transactions: txs,
            language: lang,
            logicalSize: Size(width, 800),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('bütçe varken özet görünür (eski monthlyBudget göçü)',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const BudgetScreen(),
      db: FakeFirebaseFirestore(),
      envelopes: envelopes,
      transactions: txs,
      language: AppLanguage.tr,
      profile: const {'monthlyBudget': 15000},
    );
    expect(find.text(RS.tr.monthlyBudget), findsOneWidget);
    expect(find.text(RS.tr.noBudget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutar adımı: 0 iken Devam kapalı, rakamla açılır',
      (tester) async {
    await pumpBudgyScreen(tester, const BudgetAmountStep(),
        db: FakeFirebaseFirestore(), language: AppLanguage.en);
    FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, RS.en.continueLabel));
    expect(button().onPressed, isNull);
    await tester.tap(find.widgetWithText(InkWell, '5').last);
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('kategori adımı Kaydet: ayar + zarf limitleri yazılır',
      (tester) async {
    final db = FakeFirebaseFirestore();
    for (final e in envelopes) {
      await seedEnvelope(db, e);
    }
    await pumpBudgyScreen(
      tester,
      const BudgetCategoriesStep(
          settings: BudgetSettings(
              amount: 2000, period: BudgetPeriod.weekly, weekStart: 3)),
      db: db,
      envelopes: envelopes,
      transactions: txs,
      language: AppLanguage.tr,
    );
    // Ulaşım limiti gir.
    await tester.enterText(find.byType(TextField).last, '500');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, RS.tr.save));
    await tester.pumpAndSettle();

    final settings = (await db.doc('users/$testUid/settings/main').get()).data()!;
    expect(settings['budgetAmount'], 2000);
    expect(settings['budgetPeriod'], 'weekly');
    expect(settings['budgetWeekStart'], 3);
    expect(settings['monthlyBudget'], isNull);
    final e2 = (await db.doc('users/$testUid/envelopes/e2').get()).data()!;
    expect(e2['targetAmount'], 500);
    expect(find.byType(BudgetCategoriesStep), findsNothing);
  });

  testWidgets('Analiz: veri varken kategori satırları ve içgörüler',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const StatsScreen(),
      db: FakeFirebaseFirestore(),
      envelopes: envelopes,
      transactions: txs,
      language: AppLanguage.en,
    );
    expect(find.text(RS.en.topCategory), findsOneWidget);
    expect(find.text(RS.en.notEnoughData), findsNothing);
    expect(find.text('Market ve Temel Gıda'), findsWidgets);
  });
}
