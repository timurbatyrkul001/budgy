import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/core/tokens.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';
import 'package:kopilka_app/features/settings/settings_appearance_screen.dart';
import 'package:kopilka_app/features/settings/settings_hub.dart';

import '../support/harness.dart';

/// Görünüm ekranı: kurulum sihirbazı satırı onaydan sonra onboarding'i
/// üste açar (zarflar varken bile), iptal hiçbir şey yapmaz, yarıda
/// bırakılınca bayrak geri gelir; "Tema" satırı VE "yazı kontrastı" anahtarı
/// bilinçli olarak yok (ikisi de 1.1'e ertelendi — ekranlar `Ex.*` sabitleriyle
/// boyandığı için kullanıcı hiçbir etki görmüyordu). Palet mekanizması
/// (`BudgyColors.highContrast`, `context.budgy`) yerinde duruyor; onun
/// birim testleri de burada kalıyor.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  // Mevcut kullanıcı: zarfları var, onboarding bitmiş. Sihirbazın bu
  // durumda da açılması asıl mesele — auth kapısı onu asla göstermezdi.
  final envelopes = [
    testEnvelope(id: 'e1', name: 'Market'),
    testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', sortOrder: 1),
  ];
  final settingsPath = 'users/$testUid/settings/main';

  Future<FakeFirebaseFirestore> seededDb({bool highContrast = false}) async {
    final db = FakeFirebaseFirestore();
    await db.doc(settingsPath).set({
      'onboardingDone': true,
      'currency': 'TRY',
      if (highContrast) 'highContrast': true,
    });
    return db;
  }

  Future<Map<String, dynamic>> settingsDoc(FakeFirebaseFirestore db) async =>
      (await db.doc(settingsPath).get()).data() ?? const {};

  group('kontrast anahtarı yok (bilinçli)', () {
    // Anahtar `context.budgy` paletini değiştiriyordu ama bu ekran dahil
    // ~50 ekran `Ex.*` ile boyanıyor: kullanıcı çevirip hiçbir fark
    // görmüyordu. Çalışmayan ayar gösterilmez; biri "eksik" sanıp geri
    // eklemesin diye açık test. Mekanizma 1.1 için yerinde (aşağıdaki
    // palet testleri).
    for (final lang in AppLanguage.values) {
      testWidgets('${lang.code}: ekranda kontrast satırı/anahtarı yok',
          (tester) async {
        await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
            db: await seededDb(), envelopes: envelopes, language: lang);
        final rs = RS.of(lang.code);
        expect(find.byType(Switch), findsNothing);
        expect(find.text(rs.highContrastTitle), findsNothing);
        expect(find.text(rs.highContrastBody), findsNothing);
        expect(find.text(rs.appearanceReadabilityLabel), findsNothing);
      });
    }

    testWidgets('veride highContrast=true kalmış olsa da ekran değişmez',
        (tester) async {
      // Eski bir sürümde anahtarı açmış kullanıcı: ekranda sürpriz bir
      // "açık" anahtar ya da satır belirmesin.
      await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
          db: await seededDb(highContrast: true),
          envelopes: envelopes,
          language: AppLanguage.en);
      expect(find.byType(Switch), findsNothing);
      expect(find.text(RS.en.highContrastTitle), findsNothing);
    });

    // Aşağıdaki iki test ANAHTARI değil, bekleyen MEKANİZMAYI sınar:
    // tokens.dart'taki palet ve app.dart'ın onu tema uzantısı olarak
    // vermesi. Anahtar geri gelince bunlar olduğu gibi kalır.
    test('palet ikincil metni gerçekten koyulaştırır, ana metne dokunmaz',
        () {
      final normal = BudgyColors.forContrast(high: false);
      final high = BudgyColors.forContrast(high: true);
      expect(identical(normal, BudgyColors.dark), isTrue);
      expect(identical(high, BudgyColors.highContrast), isTrue);

      double lum(Color c) => c.computeLuminance();
      expect(lum(high.textMuted), lessThan(lum(normal.textMuted)));
      expect(lum(high.textFaint), lessThan(lum(normal.textFaint)));
      expect(lum(high.border), lessThan(lum(normal.border)));
      expect(lum(high.borderStrong), lessThan(lum(normal.borderStrong)));
      // Ana metin zaten siyah, vurgu ve zemin aynı kalır.
      expect(high.text, normal.text);
      expect(high.accent, normal.accent);
      expect(high.bg, normal.bg);
      expect(high.surface, normal.surface);

      // WCAG: beyaz kart üstünde soluk metin bile AA (4.5:1) geçmeli,
      // ikincil metin AAA (7:1). Olağan palette textFaint 2.8:1'de kalıyor.
      double contrast(Color fg, Color bg) {
        final a = lum(fg), b = lum(bg);
        final hi = a > b ? a : b, lo = a > b ? b : a;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(contrast(high.textMuted, high.surface), greaterThan(7));
      expect(contrast(high.textFaint, high.surface), greaterThan(4.5));
      expect(contrast(normal.textFaint, normal.surface), lessThan(4.5),
          reason: 'olağan palet değişmemeli; ayarın anlamı bu farkta');
    });

    testWidgets('tema uzantısı olarak context.budgy üstünden okunur',
        (tester) async {
      // app.dart'taki seçimin aynısı: temanın uzantısı değişince
      // `context.budgy` koyu değeri döndürmeli.
      late BudgyColors seen;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [BudgyColors.forContrast(high: true)]),
        home: Builder(builder: (context) {
          seen = context.budgy;
          return const SizedBox();
        }),
      ));
      expect(seen.textMuted, BudgyColors.highContrast.textMuted);
      expect(seen.textMuted, isNot(BudgyColors.dark.textMuted));
    });
  });

  group('kurulum sihirbazı', () {
    // Kurulum kartı 800 px'de katlanmanın yakınında: widget kurulu ama
    // tam görünmeyebilir; `scrollUntilVisible` bulucuyu zaten eşleşmiş
    // sayar, o yüzden `ensureVisible` ile gerçekten kaydırıyoruz.
    Future<void> openRow(WidgetTester tester, RS rs) async {
      await tester.ensureVisible(find.text(rs.rerunOnboardingTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(rs.rerunOnboardingTitle));
      await tester.pumpAndSettle();
    }

    testWidgets('satır onay diyaloğu açar; iptal hiçbir şey yapmaz',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
          db: db, envelopes: envelopes, language: AppLanguage.tr);
      final rs = RS.tr;
      await openRow(tester, rs);
      expect(find.text(rs.rerunOnboardingDialogTitle), findsOneWidget);
      // Diyalog verinin silinmeyeceğini açıkça söyler.
      expect(find.text(rs.rerunOnboardingDialogBody), findsOneWidget);
      expect(rs.rerunOnboardingDialogBody, contains('silinmez'));

      await tester.tap(find.text(Strings.tr.cancel));
      await tester.pumpAndSettle();
      expect(find.text(rs.rerunOnboardingDialogTitle), findsNothing);
      expect(find.byType(OnboardingFlow), findsNothing);
      expect((await settingsDoc(db))['onboardingDone'], isTrue,
          reason: 'iptal bayrağa dokunmaz');
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
    });

    testWidgets('onay: zarflar varken bile sihirbaz üste açılır',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
          db: db, envelopes: envelopes, language: AppLanguage.en);
      final rs = RS.en;
      await openRow(tester, rs);
      await tester.tap(find.text(rs.rerunOnboardingConfirm));
      // Üste açılan route harness'ın `disableAnimations` sarmalayıcısının
      // dışında; giriş animasyonları gerçek sürede akar, settle beklemeden
      // sabit süre pompalanır.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text(rs.onbTitle), findsOneWidget, reason: 'ilk adım');
      // Veri yerinde: zarflar silinmedi, yalnız bayrak düştü.
      expect((await settingsDoc(db))['onboardingDone'], isFalse);
      expect((await settingsDoc(db))['currency'], 'TRY');
    });

    testWidgets('akış bitince (bayrak true) köke kadar kapanır',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
          db: db, envelopes: envelopes, language: AppLanguage.en);
      await openRow(tester, RS.en);
      await tester.tap(find.text(RS.en.rerunOnboardingConfirm));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(OnboardingFlow), findsOneWidget);

      // Onboarding'in son sayfası yalnız bunu yazar; kapanmayı kabuk yapar.
      await db
          .doc(settingsPath)
          .set({'onboardingDone': true}, SetOptions(merge: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(OnboardingFlow), findsNothing);
      // Testte kök = Görünüm ekranı; gerçekte auth kapısı → ana ekran.
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect((await settingsDoc(db))['onboardingDone'], isTrue);
    });

    testWidgets('yarıda bırakılırsa bayrak geri gelir', (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
          db: db, envelopes: envelopes, language: AppLanguage.ru);
      await openRow(tester, RS.ru);
      await tester.tap(find.text(RS.ru.rerunOnboardingConfirm));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect((await settingsDoc(db))['onboardingDone'], isFalse);

      // Geri hareketi: route kapanır, akış bitmedi. Kapanış geçişi bitince
      // push'un future'ı çözülür ve bayrak geri yazılır; settle bekler.
      Navigator.of(tester.element(find.byType(OnboardingFlow))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlow), findsNothing);
      expect((await settingsDoc(db))['onboardingDone'], isTrue,
          reason: 'bu kullanıcı zaten kurulmuştu; yarım sihirbaz onu bozmaz');
    });
  });

  group('tema satırı yok (bilinçli)', () {
    // Tek temalı uygulama + Ex sabitleri: tema anahtarı hiçbir şey
    // değiştirmezdi. Biri "eksik" sanıp geri eklemesin diye açık test.
    for (final lang in AppLanguage.values) {
      testWidgets('${lang.code}: ekranda tema satırı/değeri yok',
          (tester) async {
        await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
            db: await seededDb(), envelopes: envelopes, language: lang);
        final str = switch (lang) {
          AppLanguage.en => Strings.en,
          AppLanguage.tr => Strings.tr,
          AppLanguage.ru => Strings.ru,
        };
        for (final v in [str.themeSystem, str.themeLight, str.themeDark]) {
          expect(find.text(v), findsNothing, reason: '"$v" tema değeri');
        }
        final titles = tester
            .widgetList<SettingsRow>(find.byType(SettingsRow))
            .map((r) => r.title.toLowerCase());
        for (final t in titles) {
          expect(t, isNot(contains('tema')));
          expect(t, isNot(contains('theme')));
          expect(t, isNot(contains('тема')));
        }
        expect(find.byType(Switch), findsNothing,
            reason: 'ne tema ne kontrast anahtarı — ikisi de 1.1\'e kaldı');
      });
    }
  });

  group('yerleşim', () {
    for (final width in [320.0, 360.0]) {
      for (final lang in AppLanguage.values) {
        testWidgets('Görünüm · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
          await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
              db: await seededDb(),
              envelopes: envelopes,
              language: lang,
              logicalSize: Size(width, 800));
          expect(tester.takeException(), isNull);
          // Son kart katlanmanın altında kalabilir; kaydırıp onu da
          // görünür çiz.
          final rs = RS.of(lang.code);
          // 320 dp'de son kart tembel ListView'da henüz KURULU OLMAYABİLİR:
          // önce kurulana kadar kaydır, sonra tam görünür yap.
          await tester.scrollUntilVisible(find.text(rs.rerunOnboardingTitle),
              120,
              scrollable: find.byType(Scrollable).first);
          await tester.ensureVisible(find.text(rs.rerunOnboardingTitle));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(rs.rerunOnboardingTitle), findsOneWidget);
        });
      }
    }
  });
}
