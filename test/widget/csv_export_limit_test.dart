import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/settings/data_management_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// CSV dışa aktarma EKRANDAKİ listeden beslenmiyor.
///
/// Önce besleniyordu ve o liste 1000 kayıtla sınırlıydı: 1500 işlemi olan
/// biri 500'ü eksik bir dosyayı "tüm verim" sanıp saklıyordu. Bir süre
/// bunun için kartta sabit bir uyarı duruyordu — ama doğru çözüm uyarmak
/// değil, eksik vermemekti.
///
/// Şimdi dışa aktarma kendi, çok daha yüksek tavanıyla tek seferlik okuma
/// yapıyor. Dolayısıyla kartta artık uyarı YOK; uyarı yalnız o tavana
/// gerçekten ulaşılırsa, dosya yazıldıktan sonra şerit olarak çıkıyor.
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

  test('dışa aktarma tavanı ekran listesinin tavanından çok yüksek', () {
    // Ekrandaki geçmiş 1000'le sınırlı (budget_repository,
    // journalFullProvider). Dosya onunla aynı tavanı PAYLAŞMAMALI —
    // paylaştığı sürece eksik dosya üretiyordu.
    expect(kCsvExportLimit, greaterThan(1000));
  });

  // Ekranda sabit uyarı kalmadı: hangi sayıda işlem olursa olsun kullanıcı
  // "dosyan eksik olabilir" diye bir şey görmüyor, çünkü eksik değil.
  for (final count in [0, 999, 1000, 1500]) {
    testWidgets('$count işlem: kartta uyarı yok', (tester) async {
      await pump(tester, count);
      expect(find.text(warning(AppLanguage.tr)), findsNothing);
      expect(find.text(RS.tr.exportCsvHint), findsOneWidget);
    });
  }

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('${width.toInt()}dp · ${lang.code}: kart taşmaz', (
        tester,
      ) async {
        await pump(tester, 1500, language: lang, width: width);
        expect(tester.takeException(), isNull);
        expect(find.text(RS.of(lang.code).exportCsvHint), findsOneWidget);
      });
    }
  }
}
