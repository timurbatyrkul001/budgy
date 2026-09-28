import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';

import '../support/harness.dart';

void main() {
  group('Pro kilidi', () {
    testWidgets('abonesi olmayan analizde kilit kartını görür',
        (tester) async {
      await pumpBudgyScreen(tester, const StatsScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.tr);

      expect(find.text(RS.tr.proLocked), findsOneWidget);
      // İçerik silinmiyor, bulanıklaştırılıyor — başlık hâlâ ağaçta.
      expect(find.text(RS.tr.spending), findsWidgets);
    });

    testWidgets('Pro kullanıcı kilit görmez', (tester) async {
      await pumpBudgyScreen(tester, const StatsScreen(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.tr, pro: true);

      expect(find.text(RS.tr.proLocked), findsNothing);
    });

    testWidgets('kilit kartına basınca paywall açılır', (tester) async {
      await pumpBudgyScreen(tester, const StatsScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.tr);

      await tester.tap(find.widgetWithText(
          FilledButton, RS.tr.paywallTrialTpl.replaceFirst('{days}', '14')));
      await tester.pumpAndSettle();

      // Paywall açıldı: planlar, geri yükleme ve otomatik yenileme uyarısı.
      expect(find.text(RS.tr.paywallYearly), findsOneWidget);
      expect(find.text(RS.tr.paywallMonthly), findsOneWidget);
      expect(find.text(RS.tr.paywallRestore), findsOneWidget);
      // Apple'ın zorunlu tuttuğu iki metin.
      expect(find.text(RS.tr.paywallAutoRenew), findsOneWidget);
      expect(find.text(RS.tr.paywallTerms), findsOneWidget);
    });
  });

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('paywall · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
        await pumpBudgyScreen(tester, const StatsScreen(),
            db: FakeFirebaseFirestore(),
            language: lang,
            logicalSize: Size(width, 800));

        final rs = RS.of(lang.code);
        await tester.tap(find.widgetWithText(FilledButton,
            rs.paywallTrialTpl.replaceFirst('{days}', '14')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
