import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/theme.dart';
import 'package:kopilka_app/features/onboarding/onboarding_finale.dart';

/// Onboarding finali: tema seçimi arka planı canlı değiştirir ve seçilen
/// kimliği verir; karşılama animasyonu biter, onDone'u bir kez çağırır,
/// controller sızdırmaz; üç dilde 320dp'de taşma yok.
void main() {
  /// Sayfayı Firebase'siz açar. `pumpBudgyScreen` hareketi kapatıyor; burada
  /// animasyonun gerçekten oynadığı da test edildiği için [reduceMotion]
  /// seçilebilir.
  Future<void> pumpFinale(
    WidgetTester tester,
    Widget page, {
    AppLanguage language = AppLanguage.en,
    Size size = const Size(360, 800),
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languageProvider.overrideWith((ref) => Stream.value(language)),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          locale: Locale(language.code),
          supportedLocales: [for (final l in AppLanguage.values) Locale(l.code)],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: Scaffold(body: page),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Sayfa zemini: en dıştaki AnimatedContainer'ın gradyanı.
  LinearGradient backgroundOf(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first);
    return (box.decoration! as BoxDecoration).gradient! as LinearGradient;
  }

  group('ThemePickerPage', () {
    testWidgets('kart seçilince arka plan o dünyaya döner, onNext id verir',
        (tester) async {
      String? picked;
      await pumpFinale(tester, ThemePickerPage(onNext: (id) => picked = id));
      await tester.pumpAndSettle();

      // Başlangıç: şafak (açık zemin).
      final dawn = kOnboardingWorlds.firstWhere((w) => w.id == 'dawn');
      expect(backgroundOf(tester).colors, [dawn.top, dawn.bottom]);

      await tester.tap(find.byKey(const ValueKey('world-night')));
      await tester.pump();
      // Geçişin ortası: hedef gradyan hemen widget'a yazılır, çizim akar.
      final night = kOnboardingWorlds.firstWhere((w) => w.id == 'night');
      expect(backgroundOf(tester).colors, [night.top, night.bottom]);
      await tester.pumpAndSettle();
      expect(backgroundOf(tester).colors, [night.top, night.bottom]);

      // Koyu zeminde düğme kâğıt rengine döner (siyah lacivertte kaybolurdu).
      final pill = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).last);
      expect((pill.decoration! as ShapeDecoration).color, night.ink);

      await tester.tap(find.text("Let's do this"));
      expect(picked, 'night');
    });

    testWidgets('hareket azaltmada geçiş anında', (tester) async {
      await pumpFinale(tester, ThemePickerPage(onNext: (_) {}),
          reduceMotion: true);
      await tester.tap(find.byKey(const ValueKey('world-night')));
      await tester.pump();
      final box = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).first);
      expect(box.duration, Duration.zero);
      final night = kOnboardingWorlds.firstWhere((w) => w.id == 'night');
      expect(backgroundOf(tester).colors, [night.top, night.bottom]);
    });

    for (final lang in AppLanguage.values) {
      testWidgets('320dp · ${lang.code} taşmıyor', (tester) async {
        await pumpFinale(tester, ThemePickerPage(onNext: (_) {}),
            language: lang, size: const Size(320, 800), reduceMotion: true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Dört dünya kartı da kuruluyor (ilk üçü görünür, dördüncü kayar).
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(3));
        await tester.drag(find.byKey(const ValueKey('world-dawn')),
            const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('world-ocean')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('WelcomeBurstPage', () {
    /// ProviderScope + localizations kurulumu boş sayfada bile bir geçici
    /// geri çağrı bırakıyor; sayfanın kendi ticker'ını ölçmek için taban
    /// aynı kurulumda alınır.
    Future<int> baseline(WidgetTester tester) async {
      await pumpFinale(tester, const SizedBox());
      await tester.pumpAndSettle();
      return SchedulerBinding.instance.transientCallbackCount;
    }

    testWidgets('animasyon biter, onDone bir kez çağrılır, ticker kalmaz',
        (tester) async {
      final base = await baseline(tester);
      var done = 0;
      await pumpFinale(tester, WelcomeBurstPage(onDone: () => done++));
      // Yarı yol: henüz bitmedi, animasyon sürüyor (ticker aktif).
      await tester.pump(const Duration(milliseconds: 600));
      expect(done, 0);
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(base));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpAndSettle();
      expect(done, 1);
      // Controller durdu: pumpAndSettle takılmadı, ticker tabana döndü.
      expect(SchedulerBinding.instance.transientCallbackCount, base);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Ekrandan kaldırılınca controller dispose edilir (sızıntı yok).
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('hareket azaltmada paralar yerleşik, onDone hemen',
        (tester) async {
      final base = await baseline(tester);
      var done = 0;
      await pumpFinale(tester, WelcomeBurstPage(onDone: () => done++),
          reduceMotion: true);
      // İlk kare sonrası post-frame callback çalıştı; ticker hiç başlamadı.
      await tester.pump();
      expect(done, 1);
      expect(SchedulerBinding.instance.transientCallbackCount, base);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    for (final lang in AppLanguage.values) {
      testWidgets('320dp · ${lang.code} taşmıyor', (tester) async {
        await pumpFinale(tester, WelcomeBurstPage(onDone: () {}),
            language: lang, size: const Size(320, 800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
