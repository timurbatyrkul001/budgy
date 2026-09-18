import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/envelopes/onboarding_story_screen.dart';

import '../support/harness.dart';

/// Karşılama ekranı, onboarding'in son adımı.
///
/// Buradaki sosyal giriş butonları bir dönem yalnızca `onStart`'ı çağırıyordu:
/// "Apple ile kaydol"a basan kullanıcı hiçbir hesap açmıyor, anonim devam
/// ediyordu. Bu testler o yanıltıcı davranışın geri gelmesini engelliyor.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  Future<int> pumpWelcome(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.tr,
    Size size = const Size(360, 800),
  }) async {
    var startCalls = 0;
    await pumpBudgyScreen(
      tester,
      WelcomeScreen(onStart: () => startCalls++),
      db: FakeFirebaseFirestore(),
      language: language,
      logicalSize: size,
    );
    return startCalls;
  }

  testWidgets('Facebook butonu yok — hiçbir yerde uygulanmamıştı',
      (tester) async {
    await pumpWelcome(tester);
    expect(find.textContaining('Facebook'), findsNothing);
  });

  testWidgets('Apple ve Google butonları var', (tester) async {
    await pumpWelcome(tester);
    final str = Strings.tr;
    expect(find.text(str.signUpApple), findsOneWidget);
    expect(find.text(str.continueGoogle), findsOneWidget);
  });

  testWidgets('sosyal butonlar onStart\'a KISA DEVRE yapmaz', (tester) async {
    var startCalls = 0;
    await pumpBudgyScreen(
      tester,
      WelcomeScreen(onStart: () => startCalls++),
      db: FakeFirebaseFirestore(),
    );

    // Apple'a dokunmak doğrudan onboarding'i bitirmemeli; gerçek giriş
    // denenmeli (testte Firebase yok, bu yüzden hata yolundan döner).
    await tester.tap(find.text(Strings.tr.signUpApple));
    await tester.pump();
    expect(startCalls, 0,
        reason: 'giriş yapılmadan onboarding tamamlanmış sayılmamalı');
  });

  testWidgets('hesapsız devam bağlantısı onStart\'ı çağırır', (tester) async {
    var startCalls = 0;
    await pumpBudgyScreen(
      tester,
      WelcomeScreen(onStart: () => startCalls++),
      db: FakeFirebaseFirestore(),
    );

    await tester.tap(find.text(Strings.tr.continueWithoutAccount));
    await tester.pump();
    expect(startCalls, 1);
  });

  testWidgets('hesapsız devamın yanında veri uyarısı gösterilir',
      (tester) async {
    await pumpWelcome(tester);
    expect(find.text(Strings.tr.withoutAccountNote), findsOneWidget);
  });

  for (final lang in AppLanguage.values) {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'karşılama ekranı ${width.toInt()}dp · ${lang.code} taşmıyor',
        (tester) async {
          await pumpWelcome(
            tester,
            language: lang,
            size: Size(width, 800),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
