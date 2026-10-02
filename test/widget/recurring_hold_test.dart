import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/recurring/recurring.dart';
import 'package:kopilka_app/features/recurring/recurring_screen.dart';

import '../support/harness.dart';

/// Bekleyen tekrarlayan kural (holdReason) ekranda GÖRÜNÜR: rozet + sebebe
/// göre açıklama. Hesap sorunu "ne yapmalı" söyler, kur sorunu "bekle" der;
/// ikisi aynı metin DEĞİL. Bilinmeyen sebep genel metne düşer.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final next = DateTime.now().add(const Duration(days: 3));

  RecurringRule rule({
    required String id,
    String? holdReason,
    String? accountName = 'Garanti Bonus Kredi Kartı',
    String? note,
  }) => RecurringRule(
    id: id,
    amount: 1250,
    type: 'expense',
    currency: 'TRY',
    freq: Recurrence.monthly,
    nextDate: next,
    anchorDay: next.day,
    envelopeName: 'Market ve Temel Gıda',
    note: note,
    accountId: 'acc1',
    accountName: accountName,
    holdReason: holdReason,
  );

  Future<void> pump(
    WidgetTester tester,
    List<RecurringRule> rules, {
    AppLanguage language = AppLanguage.tr,
    double width = 360,
  }) => pumpBudgyScreen(
    tester,
    const RecurringScreen(),
    db: FakeFirebaseFirestore(),
    language: language,
    recurringRules: rules,
    logicalSize: Size(width, 800),
  );

  group('sebep → metin', () {
    test('iki bilinen sebep farklı, bilinmeyen genel', () {
      for (final rs in [RS.tr, RS.en, RS.ru]) {
        final account = recurringHoldText(rs, RecurringRule.holdAccountMissing);
        final fx = recurringHoldText(rs, RecurringRule.holdFxUnavailable);
        final other = recurringHoldText(rs, 'somethingNew');
        expect(account, rs.recurringHoldAccountMissing);
        expect(fx, rs.recurringHoldFxUnavailable);
        expect(other, rs.recurringHoldGeneric);
        expect(account, isNot(fx));
        expect(other, isNot(account));
        expect(other, isNot(fx));
      }
    });
  });

  group('ekran', () {
    testWidgets('sorunsuz kural: rozet de açıklama da yok', (tester) async {
      await pump(tester, [rule(id: 'r1')]);
      expect(find.text(RS.tr.recurringHold), findsNothing);
      expect(find.text(RS.tr.recurringHoldAccountMissing), findsNothing);
      expect(find.text(RS.tr.recurringHoldFxUnavailable), findsNothing);
    });

    testWidgets('hesap yok: rozet + "arşivden geri getir" açıklaması', (
      tester,
    ) async {
      await pump(tester, [
        rule(id: 'r1', holdReason: RecurringRule.holdAccountMissing),
      ]);
      expect(find.text(RS.tr.recurringHold), findsOneWidget);
      expect(find.text(RS.tr.recurringHoldAccountMissing), findsOneWidget);
      expect(find.text(RS.tr.recurringHoldFxUnavailable), findsNothing);
    });

    testWidgets('kur yok: rozet + "bekle" açıklaması', (tester) async {
      await pump(tester, [
        rule(id: 'r1', holdReason: RecurringRule.holdFxUnavailable),
      ]);
      expect(find.text(RS.tr.recurringHold), findsOneWidget);
      expect(find.text(RS.tr.recurringHoldFxUnavailable), findsOneWidget);
      expect(find.text(RS.tr.recurringHoldAccountMissing), findsNothing);
    });

    testWidgets('bilinmeyen sebep sessiz kalmaz: genel açıklama', (
      tester,
    ) async {
      await pump(tester, [rule(id: 'r1', holdReason: 'futureReason')]);
      expect(find.text(RS.tr.recurringHold), findsOneWidget);
      expect(find.text(RS.tr.recurringHoldGeneric), findsOneWidget);
    });

    testWidgets('karışık liste: yalnız bekleyen kurallar işaretli', (
      tester,
    ) async {
      await pump(tester, [
        rule(id: 'ok'),
        rule(id: 'acc', holdReason: RecurringRule.holdAccountMissing),
        rule(id: 'fx', holdReason: RecurringRule.holdFxUnavailable),
      ]);
      expect(find.text(RS.tr.recurringHold), findsNWidgets(2));
      expect(find.text(RS.tr.recurringHoldAccountMissing), findsOneWidget);
      expect(find.text(RS.tr.recurringHoldFxUnavailable), findsOneWidget);
    });
  });

  // ── dar ekran × dil: uzun açıklamalar ve rozet taşmıyor ───────────────

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('${width.toInt()}dp · ${lang.code}: bekleyen kurallar taşmaz', (
        tester,
      ) async {
        await pump(
          tester,
          [
            rule(
              id: 'acc',
              holdReason: RecurringRule.holdAccountMissing,
              note: 'Uzun bir açıklama notu, kira ve aidat ödemesi birlikte',
            ),
            rule(id: 'fx', holdReason: RecurringRule.holdFxUnavailable),
            rule(id: 'other', holdReason: 'futureReason'),
          ],
          language: lang,
          width: width,
        );
        expect(tester.takeException(), isNull);
        final rs = RS.of(lang.code);
        expect(find.text(rs.recurringHold), findsNWidgets(3));
        expect(find.text(rs.recurringHoldAccountMissing), findsOneWidget);
        expect(find.text(rs.recurringHoldFxUnavailable), findsOneWidget);
        expect(find.text(rs.recurringHoldGeneric), findsOneWidget);
      });
    }
  }
}
