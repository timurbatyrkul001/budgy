import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/pro/pro_state.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';

import '../support/harness.dart';

/// "1.0 ÜCRETSİZ" hâli: analiz ekranı herkese açık, paywall yok (bkz.
/// pro_state.dart, [kProEnabled]).
///
/// Bu dosya eskiden paywall'ın kendisini doğruluyordu (marka kilidi, üç
/// plan, fiyatlar, deneme düğmesi, yasal bağlantılar, dar ekranda taşma).
/// Satın alma bağlanmadan paywall gösterilemeyeceği için şimdi tersini
/// doğruluyor: abonesi olmayan kullanıcı analizi kilitsiz görür, hiçbir
/// yoldan paywall/fiyat/deneme düğmesi çıkmaz.
///
/// ABONELİK GERİ GELİNCE ([kProEnabled] = true) bu dosya YENİDEN YAZILMALI:
/// paywall'ın eski testleri git geçmişinde duruyor.
void main() {
  final trialButton = find.widgetWithText(
    FilledButton,
    RS.tr.paywallTrialTpl.replaceFirst('{days}', '14'),
  );

  group('Analiz · kilit yok', () {
    testWidgets('abonesi olmayan analizi kilitsiz görür', (tester) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );

      expect(find.text(RS.tr.spending), findsWidgets);
      expect(find.text(RS.tr.proLocked), findsNothing);
      expect(trialButton, findsNothing);
      expect(find.text(RS.tr.paywallBrand), findsNothing);
      expect(find.text(RS.tr.paywallProPill), findsNothing);
    });

    testWidgets('Pro kullanıcı da aynı ekranı görür', (tester) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        pro: true,
      );

      expect(find.text(RS.tr.spending), findsWidgets);
      expect(find.text(RS.tr.proLocked), findsNothing);
    });

    testWidgets('fiyat, plan ve satın alma metinleri hiçbir yerde yok', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );

      // İnceleyenin görmemesi gereken her şey: plan adları, fiyat etiketi,
      // deneme/satın alma düğmeleri, otomatik yenileme notu.
      for (final t in [
        RS.tr.paywallYearly,
        RS.tr.paywallMonthly,
        RS.tr.paywallLifetime,
        RS.tr.paywallStartTrialTpl.replaceFirst('{days}', '14'),
        RS.tr.paywallAutoRenew,
        RS.tr.paywallBenefitsTitle,
      ]) {
        expect(find.text(t), findsNothing, reason: t);
      }
      // Plan fiyatları (ekrandaki tutarlar ₺ taşır; fiyat etiketlerinin
      // kendisi aranıyor).
      for (final plan in ProPlan.values) {
        expect(find.textContaining(plan.priceLabel), findsNothing,
            reason: plan.priceLabel);
      }
    });
  });

  // Eski paywall taşma testlerinin yerine: kilitsiz analiz ekranı dar
  // ekranda ve her dilde taşmadan çizilir.
  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('analiz · ${width.toInt()}dp · ${lang.code} taşmıyor', (
        tester,
      ) async {
        await pumpBudgyScreen(
          tester,
          const StatsScreen(),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: Size(width, 800),
        );

        expect(find.text(RS.of(lang.code).proLocked), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
