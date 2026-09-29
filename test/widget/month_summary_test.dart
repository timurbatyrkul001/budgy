import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/formatters.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/insights/month_summary_card.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

import '../support/harness.dart';

void main() {
  group('Ay özeti kartı', () {
    testWidgets('kazanç, harcama, kategori ve gün sayısını yazar',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MonthSummaryCard(
          summary: const MonthSummary(
            monthLabel: 'EYLÜL 2026',
            earned: 33700,
            spent: 31930,
            daysWorked: 10,
            topCategory: 'Yemek',
          ),
          rs: RS.tr,
          str: Strings.tr,
        ),
      ));

      expect(find.text('EYLÜL 2026'), findsOneWidget);
      expect(find.text(formatMoney(33700)), findsOneWidget);
      expect(find.text(formatMoney(31930)), findsOneWidget);
      expect(find.text('Yemek'), findsOneWidget);
      expect(find.text('10 gün çalışıldı'), findsOneWidget);
      // Paylaşılan görselde marka adı olmazsa paylaşımın tanıtım değeri yok.
      expect(find.text('Budgy'), findsOneWidget);
    });

    testWidgets('kategori yoksa o satır hiç çizilmez', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MonthSummaryCard(
          summary: const MonthSummary(
            monthLabel: 'EYLÜL 2026',
            earned: 1000,
            spent: 0,
            daysWorked: 1,
            topCategory: null,
          ),
          rs: RS.tr,
          str: Strings.tr,
        ),
      ));

      expect(find.text(RS.tr.summaryTop), findsNothing);
    });
  });

  group('Analiz ekranında paylaş düğmesi', () {
    testWidgets('veri varken görünür', (tester) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        pro: true,
        workDays: [
          WorkDay(
              id: 'd1',
              date: DateTime(DateTime.now().year, DateTime.now().month, 1),
              amount: 2500),
        ],
      );

      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    });

    testWidgets('boş ayda düğme hiç çizilmez', (tester) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        pro: true,
      );

      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });
  });
}
