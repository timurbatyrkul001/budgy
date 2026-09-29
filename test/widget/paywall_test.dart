import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';

import '../support/harness.dart';

void main() {
  group('Pro kilidi', () {
    testWidgets('abonesi olmayan analizde kilit kartını görür', (tester) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );

      expect(find.text(RS.tr.proLocked), findsOneWidget);
      // İçerik silinmiyor, bulanıklaştırılıyor — başlık hâlâ ağaçta.
      expect(find.text(RS.tr.spending), findsWidgets);
    });

    testWidgets('Pro kullanıcı kilit görmez', (tester) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        pro: true,
      );

      expect(find.text(RS.tr.proLocked), findsNothing);
    });

    testWidgets('kilit kartına basınca paywall açılır', (tester) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );

      await tester.tap(
        find.widgetWithText(
          FilledButton,
          RS.tr.paywallTrialTpl.replaceFirst('{days}', '14'),
        ),
      );
      await tester.pumpAndSettle();

      // Paywall açıldı: marka kilidi ("Budgy" + "Pro" hapı), üç plan.
      // Geri yükleme düğmesi bilerek yok.
      expect(find.text(RS.tr.paywallBrand), findsOneWidget);
      expect(find.text(RS.tr.paywallProPill), findsOneWidget);
      expect(find.text(RS.tr.paywallYearly), findsOneWidget);
      expect(find.text(RS.tr.paywallMonthly), findsOneWidget);
      expect(find.text(RS.tr.paywallLifetime), findsOneWidget);
      // Yıllık varsayılan: indirim rozeti ve deneme düğmesi görünür.
      expect(
        find.text(RS.tr.paywallSaveTpl.replaceFirst('{n}', '32')),
        findsOneWidget,
      );
      expect(
        find.text(RS.tr.paywallStartTrialTpl.replaceFirst('{days}', '14')),
        findsOneWidget,
      );
      // Apple'ın zorunlu tuttuğu metinler: otomatik yenileme, şartlar,
      // gizlilik.
      expect(find.text(RS.tr.paywallAutoRenew), findsOneWidget);
      expect(find.text(RS.tr.paywallTerms), findsOneWidget);
      expect(find.text(RS.tr.privacyPolicy), findsOneWidget);
      // "Neler var" üst başlığı ve beş bölüm başlığı — referanstaki gibi
      // normal yazımla çizilir, büyük harfe çevrilmez.
      expect(find.text(RS.tr.paywallBenefitsTitle), findsOneWidget);
      for (final g in [
        RS.tr.paywallGroupSpaces,
        RS.tr.paywallGroupMoney,
        RS.tr.paywallGroupAutomation,
        RS.tr.paywallGroupEntry,
        RS.tr.paywallGroupInsights,
      ]) {
        expect(find.text(g), findsOneWidget);
      }
    });

    testWidgets('ömür boyu seçilince deneme yerine tek seferlik satın alma', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );

      await tester.tap(
        find.widgetWithText(
          FilledButton,
          RS.tr.paywallTrialTpl.replaceFirst('{days}', '14'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(RS.tr.paywallLifetime));
      await tester.pumpAndSettle();

      // Tek seferlik üründe deneme yok: düğme fiyatı söyler, not abonelik
      // yerine tek ödemeyi anlatır.
      expect(
        find.text(
          RS.tr.paywallBuyLifetimeTpl.replaceFirst('{price}', '₺3.999,99'),
        ),
        findsOneWidget,
      );
      expect(find.text(RS.tr.paywallLifetimeNote), findsOneWidget);
      expect(find.text(RS.tr.paywallAutoRenew), findsNothing);
    });
  });

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('paywall · ${width.toInt()}dp · ${lang.code} taşmıyor', (
        tester,
      ) async {
        await pumpBudgyScreen(
          tester,
          const StatsScreen(),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: Size(width, 800),
        );

        final rs = RS.of(lang.code);
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            rs.paywallTrialTpl.replaceFirst('{days}', '14'),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
