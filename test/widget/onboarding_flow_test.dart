import 'dart:ui';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/category_catalog.dart';
import 'package:kopilka_app/core/category_rules.dart';
import 'package:kopilka_app/core/currency_info.dart';
import 'package:kopilka_app/core/formatters.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';

import '../support/harness.dart';

/// 6 sayfalı onboarding dar ekranda taşmamalı. Önizleme modu: 6. adım
/// örnek tutar + iki döviz cüzdanıyla (en dolu hâl) açılır, hiçbir şey
/// yazılmaz.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  for (final step in [0, 1, 2, 3, 4, 5]) {
    for (final width in [320.0, 360.0]) {
      for (final lang in AppLanguage.values) {
        testWidgets(
          'onboarding adım ${step + 1} · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
            await pumpBudgyScreen(
              tester,
              OnboardingFlow(preview: true, initialStep: step),
              db: FakeFirebaseFirestore(),
              language: lang,
              logicalSize: Size(width, 800),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('karşılama: üç örnek kart (katalog adı + bölge para birimi), Başla → 2. adım',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 0),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    await tester.pumpAndSettle(); // giriş animasyonları biter (döngü yok)
    expect(find.text(RS.en.onbTitle), findsOneWidget);
    expect(find.text(RS.en.onbSubtitle), findsOneWidget);
    for (final label in ['Coffee', 'Groceries', 'Taxi']) {
      expect(find.text(label), findsOneWidget);
    }
    // Test ortamında bölge yok → USD; tutarlar dolar simgesiyle.
    final code = currencyForRegion(PlatformDispatcher.instance.locale.countryCode);
    for (final a in sampleIntroAmounts(code)) {
      expect(find.text(formatMoneyIn(a, code)), findsOneWidget);
    }
    expect(find.text(RS.en.haveAccount), findsOneWidget);

    await tester.tap(find.text(RS.en.getStarted));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.onbTitle), findsNothing);
    // Karşılamadan sonra artık tanıtım sayfaları gelir (2/6: hızlı giriş).
    expect(find.text(RS.en.introFastTitle), findsOneWidget);
  });

  testWidgets('karşılama: TR dilinde katalog adları Türkçe', (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 0),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
    );
    await tester.pumpAndSettle();
    expect(find.text(RS.tr.onbTitle), findsOneWidget);
    expect(find.text(catalogItem('coffee')!.name('tr')), findsOneWidget);
    expect(find.text(catalogItem('groceries')!.name('tr')), findsOneWidget);
    expect(find.text(catalogItem('taxi')!.name('tr')), findsOneWidget);
  });

  testWidgets('1 → 6: Başla, üç Devam, para birimi → cüzdan adımı', (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 0),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(RS.en.getStarted));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.introFastTitle), findsOneWidget);
    // Tanıtım kopyası gerçek kural sayısını söyler.
    await tester.tap(find.text(RS.en.continueLabel));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.introRulesTitle), findsOneWidget);
    final n = kBuiltinRuleCount ~/ 10 * 10;
    expect(n, greaterThanOrEqualTo(100));
    expect(find.textContaining('$n+'), findsOneWidget);
    // migros gerçek kuralla Groceries'e çözülür.
    expect(find.text('migros'), findsOneWidget);
    expect(find.text(catalogItem('groceries')!.name('en')), findsOneWidget);
    await tester.tap(find.text(RS.en.continueLabel));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.introBudgetTitle), findsOneWidget);
    await tester.tap(find.text(RS.en.continueLabel));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.currencyTitle), findsOneWidget);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    expect(find.text(RS.en.walletTitle), findsOneWidget);
    expect(find.text(RS.en.letsGo), findsOneWidget);
    // Geri: cüzdan → para birimi.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text(RS.en.currencyTitle), findsOneWidget);
  });

  test('sampleIntroAmounts: her para birimi için üç yuvarlak tutar', () {
    for (final code in ['TRY', 'USD', 'EUR', 'RUB', 'KZT', 'GBP']) {
      final a = sampleIntroAmounts(code);
      expect(a, hasLength(3));
      expect(a.every((x) => x > 0 && x == x.roundToDouble()), isTrue);
    }
  });

  testWidgets('cüzdan adımında ek döviz satırı kaldırılabilir', (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 5),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
    );
    expect(find.text('US Dollar'), findsOneWidget);
    expect(find.text('Euro'), findsOneWidget);
    expect(find.text(RS.tr.otherCurrencies), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('US Dollar'), findsNothing);
    expect(find.text('Euro'), findsOneWidget);
  });
}
