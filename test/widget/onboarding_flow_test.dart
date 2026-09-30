import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/category_catalog.dart';
import 'package:kopilka_app/core/category_rules.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_finale.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';
import 'package:kopilka_app/features/profile/privacy_policy_screen.dart';
import 'package:kopilka_app/features/profile/terms_of_use_screen.dart';

import '../support/harness.dart';

/// 17 sayfalı onboarding dar ekranda taşmamalı. Önizleme modu: cüzdan adımı
/// (12) örnek tutar + iki döviz cüzdanıyla, özet (10) örnek seçimlerle
/// (en dolu hâl) açılır, hiçbir şey yazılmaz.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  for (var step = 0; step <= kOnboardingLastStep; step++) {
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
    // Karşılamadan sonra artık tanıtım sayfaları gelir (2/17: hızlı giriş).
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

  testWidgets('1 → 5: Başla, üç Devam → duygu sorusu; geri çalışır',
      (tester) async {
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
    // Tanıtımdan sonra anket başlar: duygu sorusu.
    expect(find.text(RS.en.qMoodTitle), findsOneWidget);
    // Geri: duygu → bütçe tanıtımı.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text(RS.en.introBudgetTitle), findsOneWidget);
  });

  testWidgets('cüzdan adımında ek döviz satırı kaldırılabilir', (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 12),
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

  testWidgets('cevaba karşılık 5. sayfanın cevabına göre; geri gelince balon '
      'seçimi korunur', (tester) async {
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 4),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    await tester.tap(find.text(RS.en.qMoodGood));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.qMoodComfortGood), findsOneWidget);
    await tester.tap(find.text(RS.en.next));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.qHardTitle), findsOneWidget);
    await tester.tap(find.text(RS.en.qHardHabit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RS.en.next));
    await tester.pumpAndSettle();
    // "habit" cevabına "habit" karşılığı.
    expect(find.text(RS.en.rHabitTitle), findsOneWidget);
    expect(find.text(RS.en.rIncomeTitle), findsNothing);
    await tester.tap(find.text(RS.en.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RS.en.qMethodNone));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RS.en.next));
    await tester.pumpAndSettle();
    // Gider balonları: iki seç, ileri, geri → seçim duruyor.
    expect(find.text(RS.en.bubblesExpenseTitle), findsOneWidget);
    await tester.tap(find.text(catalogItem('coffee')!.name('en')));
    await tester.tap(find.text(catalogItem('taxi')!.name('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with 2'));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.bubblesIncomeTitle), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Continue with 2'), findsOneWidget);
  });

  testWidgets(
      'uçtan uca: seçimler tek seferde yazılır — kategoriler, tema, ilk gün, '
      'onboardingDone', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(),
      db: db,
      language: AppLanguage.en,
    );
    Future<void> next([String? label]) async {
      await tester.tap(find.text(label ?? RS.en.next));
      await tester.pumpAndSettle();
    }

    await next(RS.en.getStarted);
    await next(RS.en.continueLabel);
    await next(RS.en.continueLabel);
    await next(RS.en.continueLabel);
    // Anket.
    await tester.tap(find.text(RS.en.qMoodStressed));
    await tester.pumpAndSettle();
    await next();
    await tester.tap(find.text(RS.en.qHardIncome));
    await tester.pumpAndSettle();
    await next();
    expect(find.text(RS.en.rIncomeTitle), findsOneWidget);
    await next();
    await tester.tap(find.text(RS.en.qMethodSheet));
    await tester.pumpAndSettle();
    await next();
    // Balonlar: 2 gider + 1 gelir.
    await tester.tap(find.text(catalogItem('groceries')!.name('en')));
    await tester.tap(find.text(catalogItem('rent')!.name('en')));
    await tester.pumpAndSettle();
    await next('Continue with 2');
    await tester.tap(find.text(catalogItem('tips')!.name('en')));
    await tester.pumpAndSettle();
    await next('Continue with 1');
    // Özet sayı satırları semantik etiketle (rakam ayrı span).
    expect(find.text(RS.en.summaryTitle), findsOneWidget);
    expect(find.bySemanticsLabel('Expense categories: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Income sources: 1'), findsOneWidget);
    await next();
    // Para birimi → cüzdan → bildirim (şimdi değil) → dünya (gece).
    await tester.tap(find.textContaining('Continue with'));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.walletTitle), findsOneWidget);
    await next(RS.en.continueLabel);
    expect(find.text(RS.en.notifTitle), findsOneWidget);
    await next(RS.en.notifLater);
    expect(find.text(RS.en.worldTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('world-night')));
    await tester.pumpAndSettle();
    await next(RS.en.worldGo);
    // İlk gün: bugüne dokun, 350 yaz, kaydet, ileri.
    expect(find.text(RS.en.firstDayTitle), findsOneWidget);
    await tester.tap(find.text('${DateTime.now().day}'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '350');
    await tester.pumpAndSettle();
    await next(RS.en.firstDayConfirm);
    await next();
    // Patlama (hareket kapalı → anında biter, o yüzden başlığı yakalamaya
    // çalışmıyoruz) → yazma tamamlanır → hesabı bağlama sayfası.
    // "Şimdi değil" onboarding'i kapatır.
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(RS.en.saveTitle), findsOneWidget);
    await tester.tap(find.text(RS.en.saveSkip));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final settings =
        (await db.doc('users/$testUid/settings/main').get()).data()!;
    expect(settings['onboardingDone'], isTrue);
    expect(settings['themeMode'], 'dark');
    expect(settings['currency'], isNotNull);
    expect(settings['onboardingAnswers'], {
      'mood': 'stressed',
      'hardest': 'income',
      'method': 'sheet',
      'world': 'night',
    });

    // Balonlar → zarflar: preset anahtarı + katalog adı; gelir bölümü
    // katalogdan türer (kayıtlı section yok, preset 'tips' gelir).
    final envs = (await db.collection('users/$testUid/envelopes').get()).docs;
    final byKey = {for (final d in envs) d.data()['preset']: d.data()};
    expect(byKey.keys, unorderedEquals(['groceries', 'rent', 'tips']));
    expect(byKey['groceries']!['name'], catalogItem('groceries')!.en);
    expect(byKey['tips']!['emoji'], catalogItem('tips')!.emoji);
    expect(isIncomeCatalogKey('tips'), isTrue);
    // Sıra numaraları 0'dan artar.
    expect([for (final d in envs) d.data()['sortOrder']],
        unorderedEquals([0, 1, 2]));

    // İlk gün: workDays/{bugün} + cüzdana aynı tutar (setDay farkı yazar).
    final today = DateTime.now();
    final id = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final day = (await db.doc('users/$testUid/workDays/$id').get()).data();
    expect(day?['amount'], 350);
    final cash = (await db.doc('users/$testUid/accounts/cash').get()).data();
    expect(cash?['balance'], 350);
  });

  testWidgets('balon seçilmezse hazır set yazılır; ilk gün atlanınca cüzdan '
      'boş kalır; şafak açık tema', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(initialStep: 8),
      db: db,
      language: AppLanguage.tr,
    );
    Future<void> next(String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await next(RS.tr.bubblesContinue);
    await next(RS.tr.bubblesContinue);
    expect(find.text(RS.tr.summaryEmpty), findsOneWidget);
    await next(RS.tr.next);
    await tester.tap(find.textContaining('ile devam et'));
    await tester.pumpAndSettle();
    await next(RS.tr.continueLabel);
    await next(RS.tr.notifLater);
    await next(RS.tr.worldGo); // varsayılan dünya: şafak
    await next(RS.tr.firstDaySkip);
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    // Kapanış sayfası: hesap bağlamadan geçiliyor.
    await next(RS.tr.saveSkip);

    final settings =
        (await db.doc('users/$testUid/settings/main').get()).data()!;
    expect(settings['onboardingDone'], isTrue);
    expect(settings['themeMode'], 'light');
    final envs = (await db.collection('users/$testUid/envelopes').get()).docs;
    expect(
      [for (final d in envs) d.data()['preset']],
      unorderedEquals([for (final p in presetEnvelopes) p.key]),
    );
    expect((await db.doc('users/$testUid/accounts/cash').get()).exists, isFalse);
    expect(
        (await db.collection('users/$testUid/workDays').get()).docs, isEmpty);
  });

  // Tema sayfasında gökyüzü ekranın tamamını kaplamalı: kullanıcı durum
  // çubuğunun altında kâğıt şerit kalınca "kaymış" diye bildirmişti.
  testWidgets('tema sayfası · gökyüzü durum çubuğunun arkasına da geçer',
      (tester) async {
    const screen = Size(390, 844);
    await pumpBudgyScreen(
      tester,
      const OnboardingFlow(preview: true, initialStep: 14),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.tr,
      logicalSize: screen,
      safeArea: const EdgeInsets.only(top: 47, bottom: 34),
    );
    await tester.pumpAndSettle();

    // Zemini Scaffold'un gövdesindeki AnimatedContainer çiziyor: SafeArea'nın
    // dışında olduğu için ölçüsü ekranın tamamı.
    final sky = find.descendant(
      of: find.byType(Scaffold),
      matching: find.byType(AnimatedContainer),
    );
    final box = tester.getRect(sky.first);
    expect(box.size, screen);

    final dawn = kOnboardingWorlds.firstWhere((w) => w.id == 'dawn');
    final decoration = tester.widget<AnimatedContainer>(sky.first).decoration!;
    expect(
      ((decoration as BoxDecoration).gradient! as LinearGradient).colors,
      [dawn.top, dawn.bottom],
    );

    // Gece seçilince gökyüzü de geri oku da koyu zemine göre döner.
    await tester.tap(find.byKey(const ValueKey('world-night')));
    await tester.pumpAndSettle();
    final night = kOnboardingWorlds.firstWhere((w) => w.id == 'night');
    final after = tester.widget<AnimatedContainer>(sky.first).decoration!;
    expect(
      ((after as BoxDecoration).gradient! as LinearGradient).colors,
      [night.top, night.bottom],
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded)).color,
      night.ink,
    );
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
