import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';

import '../support/harness.dart';

/// 3 adımlı onboarding dar ekranda taşmamalı. Önizleme modu: 3. adım
/// örnek tutar + iki döviz cüzdanıyla (en dolu hâl) açılır, hiçbir şey
/// yazılmaz.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  for (final step in [0, 1, 2]) {
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

  testWidgets('cüzdan adımında ek döviz satırı kaldırılabilir', (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 2),
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
