import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/automation/automation_screen.dart';
import 'package:kopilka_app/features/budget/budget_screen.dart';
import 'package:kopilka_app/features/categories/categories_screen.dart';
import 'package:kopilka_app/features/settings/data_management_screen.dart';
import 'package:kopilka_app/features/profile/terms_of_use_screen.dart';
import 'package:kopilka_app/features/settings/settings_about_screen.dart';
import 'package:kopilka_app/features/settings/settings_account_screen.dart';
import 'package:kopilka_app/features/settings/settings_appearance_screen.dart';
import 'package:kopilka_app/features/settings/settings_hub.dart';
import 'package:kopilka_app/features/settings/settings_personal_details_screen.dart';
import 'package:kopilka_app/features/space/space.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Ayarlar merkezi ve alt ekranları dar ekranda taşmaz; hub'daki kartlar
/// doğru alt ekranı açar; tuş takımı düzeni ayarı iki klavyeyi de etkiler;
/// etiket ekranı boş durumu gösterir.
///
/// Not: FirebaseAuth.instance testte kurulu değil → "Hesabım" ekranı
/// currentUser=null ile (anonim gibi) çizilir; bu widget testi için yeterli.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final now = DateTime.now();
  final envelopes = [
    testEnvelope(id: 'e1', name: 'Market ve Temel Gıda'),
    testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', sortOrder: 1),
    testEnvelope(id: 'e3', name: 'Eski', emoji: '📦', sortOrder: 2, archived: true),
  ];
  final txs = [
    Tx(id: 't1', type: TxType.expense, amount: 120, date: now, envelopeId: 'e1',
        note: 'market #ev #haftalık'),
    Tx(id: 't2', type: TxType.expense, amount: 40, date: now, note: 'kahve #ev'),
  ];

  // Hub + üç yeni alt ekran + hub'dan açılan eski ekranlar. Pro kapalı:
  // Pro kartı çizilir, en uzun metinli hâl bu.
  final screens = <String, Widget>{
    'Ayarlar merkezi': const SettingsHubScreen(),
    'Ayarlar · Hesabım': const SettingsAccountScreen(),
    'Ayarlar · Kişisel bilgiler': const SettingsPersonalDetailsScreen(),
    'Ayarlar · Görünüm': const SettingsAppearanceScreen(),
    'Ayarlar · Hakkında': const SettingsAboutScreen(),
    'Kategoriler': const CategoriesScreen(),
    'Otomasyon': const AutomationScreen(),
    'Otomasyon · kategori': const RuleKeywordsScreen(
        title: 'Groceries', catalogKey: 'groceries'),
    'Veri yönetimi': const DataManagementScreen(),
    'Kullanım şartları': const TermsOfUseScreen(),
  };

  for (final width in [320.0, 360.0]) {
    for (final entry in screens.entries) {
      for (final lang in AppLanguage.values) {
        testWidgets('${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
          await pumpBudgyScreen(
            tester,
            entry.value,
            db: FakeFirebaseFirestore(),
            envelopes: envelopes,
            transactions: txs,
            language: lang,
            logicalSize: Size(width, 800),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  group('hub', () {
    testWidgets('cüzdan satırı hub\'da yok; kategori sayısı aktifleri sayar',
        (tester) async {
      await pumpBudgyScreen(tester, const SettingsHubScreen(),
          db: FakeFirebaseFirestore(), envelopes: envelopes, language: AppLanguage.en);
      // Avatar + "Personal" + "Personal space" satırı kaldırıldı; cüzdan
      // düzenleyiciye artık Hesabım › Kişisel bilgiler'den gidiliyor.
      expect(find.text('Personal'), findsNothing);
      expect(find.text(RS.en.spaceSubtitle), findsNothing);
      expect(find.byType(SpaceAvatar), findsNothing);
      // İlk kartın ilk satırı artık "Hesabım".
      final firstRow = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).first;
      expect(firstRow.title, RS.en.hubMyAccount);
      expect(find.text('2'), findsOneWidget, reason: 'arşivdeki sayılmaz');
    });

    testWidgets('cüzdan düzenleyici: Hesabım › Kişisel bilgiler › Avatarı düzenle',
        (tester) async {
      await pumpBudgyScreen(tester, const SettingsHubScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      final rs = RS.en;
      await tester.tap(find.text(rs.hubMyAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.text(rs.hubPersonalDetails));
      await tester.pumpAndSettle();
      // Kişisel bilgiler: büyük avatar + cüzdan adı + "Avatarı düzenle".
      expect(find.byType(SpaceAvatar), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text(rs.hubEditAvatar), findsOneWidget);
      await tester.tap(find.text(rs.hubEditAvatar));
      await tester.pumpAndSettle();
      // Artık eski cüzdan sheet'i değil, ayrı avatar ekranı açılır
      // (renk + simge; ad ve para birimi burada yok).
      expect(find.text(rs.editAvatarTitle), findsOneWidget);
      expect(find.text(rs.customizeWallet), findsNothing);
    });

    testWidgets('bölüm başlıkları yok, dört giriş kapısı var', (tester) async {
      await pumpBudgyScreen(tester, const SettingsHubScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.tr);
      final rs = RS.tr;
      // Eski gri bölüm etiketleri ("Yönet", "Uygulama", "Hesap", "Yardım")
      // kalktı; gruplama kartlarla anlatılıyor.
      for (final old in [rs.manage, rs.appSection, rs.accountSection]) {
        expect(find.text(old), findsNothing, reason: '"$old" başlığı kalkmalı');
      }
      expect(find.text(rs.hubMyAccount), findsOneWidget);
      expect(find.text(rs.hubAppearance), findsOneWidget);
      // "Hesaplar" + "Hesaplarım" tek satır oldu.
      expect(find.text(rs.accounts), findsOneWidget);
      expect(find.text(rs.accountsTitle), findsNothing);
      // Son kart 800 px'lik test ekranında katlanmanın altında (tembel
      // ListView) — kaydırarak bul.
      await tester.scrollUntilVisible(find.text(rs.hubAbout), 120,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(rs.hubHelp), findsOneWidget);
      expect(find.text(rs.hubAbout), findsOneWidget);
    });

    testWidgets('Pro değilse tanıtım kartı var, Pro ise hiç çizilmez',
        (tester) async {
      await pumpBudgyScreen(tester, const SettingsHubScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.tr, pro: false);
      expect(find.text(RS.tr.hubProCta), findsOneWidget);
      expect(find.text(RS.tr.hubProRestore), findsOneWidget);
    });

    testWidgets('Pro üyeye tanıtım kartı gösterilmez', (tester) async {
      await pumpBudgyScreen(tester, const SettingsHubScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.tr, pro: true);
      expect(find.text(RS.tr.hubProCta), findsNothing);
      expect(find.text(RS.tr.hubProTitle), findsNothing);
    });

    testWidgets('Pro\'ya geç düğmesi paywall\'ı açar', (tester) async {
      await pumpBudgyScreen(tester, const SettingsHubScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      await tester.tap(find.text(RS.en.hubProCta));
      await tester.pumpAndSettle();
      // Paywall, analiz kilidinin başlığıyla açılır.
      expect(find.text(RS.en.paywallTitleAnalytics), findsOneWidget);
    });

    testWidgets('Hesabım / Görünüm / Hakkında alt ekranları açılır',
        (tester) async {
      Future<void> open(String label, String heroBody) async {
        await tester.scrollUntilVisible(find.text(label), 120,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(heroBody), findsOneWidget);
        // Alt ekranlar Material AppBar değil BudgyBackButton kullanıyor;
        // tester.pageBack() onu bulamaz.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
      }

      await pumpBudgyScreen(tester, const SettingsHubScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      final rs = RS.en;
      await open(rs.hubMyAccount, rs.hubAccountBody);
      await open(rs.hubAppearance, rs.hubAppearanceBody);
      await open(rs.hubAbout, rs.hubAboutBody);
    });
  });

  group('alt ekranlar', () {
    testWidgets('Hesabım: anonimde hesap oluştur + giriş var, çıkış yok',
        (tester) async {
      await pumpBudgyScreen(tester, const SettingsAccountScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      final str = Strings.en;
      final rs = RS.en;
      expect(find.text(rs.hubPersonalDetails), findsOneWidget);
      expect(find.text(str.createAccount), findsOneWidget);
      expect(find.text(str.signInTitle), findsOneWidget);
      expect(find.text(rs.hubLoginSecurity), findsNothing,
          reason: 'anonimde şifre yok; yerine hesap oluştur + giriş');
      // Kart etiketleri alt ekranda var.
      expect(find.text(rs.hubSectionIdentity), findsOneWidget);
      // Alt kartlar 800 px'lik test ekranında katlanmanın altında (tembel
      // ListView) — kaydırarak bul.
      await tester.scrollUntilVisible(find.text(str.deleteAccount), 120,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(rs.hubExportData), findsOneWidget);
      expect(find.text(str.deleteAccount), findsOneWidget);
      expect(find.text(str.signOutWord), findsNothing,
          reason: 'anonim kullanıcının çıkacağı hesap yok');
      expect(find.text(rs.hubSectionData), findsOneWidget);
      expect(find.text(rs.hubSectionDanger), findsOneWidget);
      // Veri notu: anonim metni. "Bu cihazda saklanır" cümlesi YOK — veri
      // Firestore'da; anonimde "hesabını bağlamazsan gider" uyarısı var.
      expect(find.text(rs.hubDataNoteAnon), findsOneWidget);
      expect(find.text(rs.hubDataNoteMember), findsNothing);
      // Eski "Hesap bilgileri" satırı artık Kişisel bilgiler'de.
      expect(find.text(str.accountInformation), findsNothing);
    });

    testWidgets('Kişisel bilgiler: profil alanları değer olarak görünür',
        (tester) async {
      await pumpBudgyScreen(tester, const SettingsPersonalDetailsScreen(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.en,
          profile: const {'name': 'Timur', 'phone': '+90 555 000 00 00'});
      final str = Strings.en;
      // Ad hem avatar altında başlık hem de alan değeri olarak.
      expect(find.text('Timur'), findsNWidgets(2));
      expect(find.text('+90 555 000 00 00'), findsOneWidget);
      expect(find.text(str.fullNameLabel), findsOneWidget);
      expect(find.text(str.phoneLabel), findsOneWidget);
      expect(find.text(str.accountInformation), findsOneWidget);
      expect(find.text(RS.en.hubNotSet), findsNothing);
    });

    testWidgets('Kişisel bilgiler: boş profilde "Belirtilmedi" ve cüzdan adı',
        (tester) async {
      await pumpBudgyScreen(tester, const SettingsPersonalDetailsScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.tr);
      expect(find.text(RS.tr.hubNotSet), findsNWidgets(2));
      // Ad yoksa avatar altında cüzdan adı (varsayılan).
      expect(find.text(RS.tr.defaultWalletName), findsOneWidget);
      expect(find.text(RS.tr.hubEditAvatar), findsOneWidget);
    });

    testWidgets('Görünüm: tuş takımı değeri profili yansıtır', (tester) async {
      await pumpBudgyScreen(tester, const SettingsAppearanceScreen(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.en,
          profile: const {'keypadLayout': 'top'});
      expect(find.text(RS.en.keypadTop), findsOneWidget);
      expect(find.text(RS.en.keypadBottom), findsNothing);
      expect(find.text('TRY'), findsOneWidget);
    });

    testWidgets('Hakkında: sürüm, yasal metinler ve veri yönetimi listelenir',
        (tester) async {
      await pumpBudgyScreen(tester, const SettingsAboutScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.tr);
      final rs = RS.tr;
      expect(find.text('1.0.0 (1)'), findsOneWidget);
      expect(find.text(rs.privacyPolicy), findsOneWidget);
      expect(find.text(rs.termsTitle), findsOneWidget);
      expect(find.text(rs.dataManagement), findsOneWidget);
    });
  });

  group('tuş takımı düzeni', () {
    Future<List<String>> firstRowLabels(WidgetTester tester) async {
      // İlk üç rakam tuşu: görsel sıraya göre (y sonra x).
      final texts = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(InkWell), matching: find.byType(Text)))
          .map((t) => t.data ?? '')
          .where((d) => RegExp(r'^\d$').hasMatch(d))
          .toList();
      return texts.take(3).toList();
    }

    // Her ekran ayrı testte: aynı testte ikinci ProviderScope override'ları
    // değiştiremez (Riverpod ilk container'ı tutar).
    testWidgets('varsayılan: 7-8-9 üstte (hızlı giriş)', (tester) async {
      await pumpBudgyScreen(tester, const QuickEntryScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      expect(await firstRowLabels(tester), ['7', '8', '9']);
    });

    testWidgets('varsayılan: 7-8-9 üstte (bütçe)', (tester) async {
      await pumpBudgyScreen(tester, const BudgetAmountStep(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      expect(await firstRowLabels(tester), ['7', '8', '9']);
    });

    testWidgets('ayar "top": 1-2-3 üstte (hızlı giriş)', (tester) async {
      await pumpBudgyScreen(tester, const QuickEntryScreen(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.en,
          profile: const {'keypadLayout': 'top'});
      expect(await firstRowLabels(tester), ['1', '2', '3']);
    });

    testWidgets('ayar "top": 1-2-3 üstte (bütçe)', (tester) async {
      await pumpBudgyScreen(tester, const BudgetAmountStep(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.en,
          profile: const {'keypadLayout': 'top'});
      expect(await firstRowLabels(tester), ['1', '2', '3']);
    });
  });

  testWidgets('kategoriler: arşivdeki ayrı bölümde, katalog maddesi soluk',
      (tester) async {
    await pumpBudgyScreen(tester, const CategoriesScreen(),
        db: FakeFirebaseFirestore(), envelopes: envelopes, language: AppLanguage.tr);
    expect(find.text(RS.tr.tapToAdd), findsWidgets);
    // Arşiv bölümü listenin sonunda (tembel ListView) — kaydırarak bul.
    await tester.scrollUntilVisible(
      find.text('Eski'),
      200,
      scrollable: find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable)),
      maxScrolls: 100,
    );
    expect(find.text(RS.tr.archived), findsOneWidget);
    expect(find.text('Eski'), findsOneWidget);
  });
}
