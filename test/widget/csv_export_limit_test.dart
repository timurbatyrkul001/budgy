import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/settings/data_management_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// CSV dışa aktarma `journalFullProvider`'dan beslenir, o da 1000 işlemle
/// sınırlı. Liste tavana dayandıysa kullanıcı dosyanın eksik olabileceğini
/// EKRANDA görür; altındaysa uyarı yok.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final now = DateTime.now();
  List<Tx> txs(int n) => [
    for (var i = 0; i < n; i++)
      Tx(
        id: 't$i',
        type: TxType.expense,
        amount: 10.0 + i,
        date: now.subtract(Duration(hours: i)),
        envelopeId: 'e1',
        envelopeName: 'Market',
      ),
  ];

  Future<void> pump(
    WidgetTester tester,
    int count, {
    AppLanguage language = AppLanguage.tr,
    double width = 360,
  }) => pumpBudgyScreen(
    tester,
    const DataManagementScreen(),
    db: FakeFirebaseFirestore(),
    transactions: txs(count),
    language: language,
    logicalSize: Size(width, 800),
  );

  String warning(AppLanguage lang) =>
      tpl(RS.of(lang.code).exportCsvLimitTpl, {'n': '$kCsvExportLimit'});

  test('tavan journalFullProvider ile aynı', () {
    expect(kCsvExportLimit, 1000);
  });

  testWidgets('tavanın altında: uyarı yok', (tester) async {
    await pump(tester, kCsvExportLimit - 1);
    expect(find.text(warning(AppLanguage.tr)), findsNothing);
    expect(find.text(RS.tr.exportCsvHint), findsOneWidget);
  });

  testWidgets('tavana dayandı: uyarı var, sayı metinde', (tester) async {
    await pump(tester, kCsvExportLimit);
    expect(find.text(warning(AppLanguage.tr)), findsOneWidget);
    expect(find.textContaining('1000'), findsOneWidget);
  });

  testWidgets('hiç işlem yok: uyarı yok', (tester) async {
    await pump(tester, 0);
    expect(find.text(warning(AppLanguage.tr)), findsNothing);
  });

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('${width.toInt()}dp · ${lang.code}: uyarı taşmaz', (
        tester,
      ) async {
        await pump(tester, kCsvExportLimit, language: lang, width: width);
        expect(tester.takeException(), isNull);
        expect(find.text(warning(lang)), findsOneWidget);
      });
    }
  }
}
