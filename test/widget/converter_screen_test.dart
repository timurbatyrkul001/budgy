import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/converter/converter_screen.dart';
import 'package:kopilka_app/features/converter/currency_picker_screen.dart';
import 'package:kopilka_app/features/envelopes/home_screen.dart';

import '../support/harness.dart';

/// Çevirici + seçici dar ekranda taşmaz; yazılan tutar diğer satırı
/// hesaplar; kur yokken "—" ve çevrimdışı uyarısı; ana ekranda iki yıldızlı
/// çip sığar.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final snap = FxSnapshot(
    base: 'TRY',
    rates: const {'USD': 0.025, 'EUR': 0.02, 'KZT': 12.5, 'JPY': 3.5},
    fetchedAt: DateTime.now().subtract(const Duration(hours: 4)),
  );

  final screens = <String, Widget>{
    'Çevirici (2 satır)': const CurrencyConverterScreen(
        initialRows: ['USD', 'TRY'], initialExpression: '100'),
    'Çevirici (6 satır)': const CurrencyConverterScreen(
        initialRows: ['USD', 'TRY', 'EUR', 'KZT', 'JPY', 'GBP'],
        initialExpression: '1234.56'),
    'Seçici': const CurrencyPickerScreen(exclude: {'TRY'}),
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
            language: lang,
            fxSnapshot: snap,
            logicalSize: Size(width, 800),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('tutar yazınca ikinci satır hesaplanır (100 USD → 4,000 TRY)',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const CurrencyConverterScreen(initialRows: ['USD', 'TRY']),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
      fxSnapshot: snap,
    );
    for (final k in ['1', '0', '0']) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('4,000.00'), findsOneWidget);
    expect(find.textContaining('4 h ago'), findsOneWidget);
  });

  testWidgets('kur yokken "—" ve çevrimdışı uyarısı; sıfır uydurulmaz',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const CurrencyConverterScreen(
          initialRows: ['USD', 'TRY'], initialExpression: '5'),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text(RS.tr.ratesOffline), findsOneWidget);
  });

  testWidgets('seçici: arama filtreler, kullanılan kod listede yok',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const CurrencyPickerScreen(exclude: {'TRY'}),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
      fxSnapshot: snap,
    );
    await tester.enterText(find.byType(TextField), 'tenge');
    await tester.pumpAndSettle();
    expect(find.text('Kazakhstani Tenge'), findsOneWidget);
    expect(find.text('Turkish Lira'), findsNothing);
    expect(find.text('US Dollar'), findsNothing);
  });

  testWidgets('ana ekran: iki yıldızlı çip 320dp\'de taşmaz', (tester) async {
    await pumpBudgyScreen(
      tester,
      const HomeScreen(),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.ru,
      fxSnapshot: snap,
      profile: const {'starredCurrencies': ['EUR', 'KZT']},
      logicalSize: const Size(320, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('50.00'), findsOneWidget, reason: '1 EUR = 50 TRY');
    expect(find.text('0.08'), findsOneWidget, reason: '1 KZT = 0.08 TRY');
  });
}
