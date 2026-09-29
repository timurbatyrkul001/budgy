import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/category_catalog.dart';
import 'package:kopilka_app/core/category_rules.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';
import 'package:kopilka_app/features/profile/privacy_policy_screen.dart';
import 'package:kopilka_app/features/profile/terms_of_use_screen.dart';

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

  // Kısa ekran (iPhone SE 1. nesil): karşılama sığmazsa kayar, taşmaz.
  for (final lang in AppLanguage.values) {
    testWidgets('karşılama · 320×568 · ${lang.code} taşmıyor', (tester) async {
      await pumpBudgyScreen(
        tester,
        const OnboardingFlow(preview: true, initialStep: 0),
        db: FakeFirebaseFirestore(),
        language: lang,
        logicalSize: const Size(320, 568),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(RS.of(lang.code).getStarted), 80);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'karşılama: rozet + başlık + alt başlık + yasal not, Başla → 2. adım',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 0),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    await tester.pumpAndSettle(); // giriş animasyonları biter (döngü yok)
    expect(find.text(RS.en.onbBadge), findsOneWidget);
    expect(find.text(RS.en.onbTitle), findsOneWidget);
    expect(find.text(RS.en.onbSubtitle), findsOneWidget);
    expect(find.text(RS.en.haveAccount), findsOneWidget);
    // Kolaj: gravür takvim (tek görsel) + el yazısı not.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text(RS.en.onbNote), findsOneWidget);
    // Yasal not: şablon, bağlantı sözcükleriyle doldurulmuş tek metin.
    final legal = tpl(RS.en.onbLegalTpl,
        {'terms': RS.en.onbLegalTerms, 'privacy': RS.en.onbLegalPrivacy});
    expect(find.text(legal, findRichText: true), findsOneWidget);

    await tester.tap(find.text(RS.en.getStarted));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.onbTitle), findsNothing);
    // Karşılamadan sonra artık tanıtım sayfaları gelir (2/6: hızlı giriş).
    expect(find.text(RS.en.introFastTitle), findsOneWidget);
  });

  testWidgets('karşılama: TR metinleri ve yasal bağlantılar ekran açar',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 0),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
    );
    await tester.pumpAndSettle();
    expect(find.text(RS.tr.onbBadge), findsOneWidget);
    expect(find.text(RS.tr.onbTitle), findsOneWidget);
    expect(find.text(RS.tr.onbSubtitle), findsOneWidget);

    // "Kullanım şartları" sözcüğüne dokun → Kullanım şartları ekranı.
    final legal = find.byType(RichText).last;
    final rich = tester.widget<RichText>(legal);
    final termsSpan = _findSpan(rich.text, RS.tr.onbLegalTerms)!;
    (termsSpan.recognizer as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(TermsOfUseScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(TermsOfUseScreen), findsNothing);

    // "Gizlilik politikasını" → Gizlilik politikası ekranı.
    final rich2 = tester.widget<RichText>(find.byType(RichText).last);
    final privacySpan = _findSpan(rich2.text, RS.tr.onbLegalPrivacy)!;
    (privacySpan.recognizer as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
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
    // Para birimi: ortalanmış siyah hap ("Continue with USD").
    await tester.tap(find.textContaining('Continue with'));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.walletTitle), findsOneWidget);
    expect(find.text(RS.en.letsGo), findsOneWidget);
    // Geri: cüzdan → para birimi.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text(RS.en.currencyTitle), findsOneWidget);
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

/// Zengin metinde [text] içeriğine sahip TextSpan'ı bulur (bağlantı sözcüğü).
TextSpan? _findSpan(InlineSpan root, String text) {
  TextSpan? found;
  root.visitChildren((span) {
    if (span is TextSpan && span.text == text) {
      found = span;
      return false;
    }
    return true;
  });
  return found;
}
