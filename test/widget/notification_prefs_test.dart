import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/profile/notification_preferences_screen.dart';
import 'package:kopilka_app/features/settings/settings_hub.dart';

import '../support/harness.dart';

/// Bildirimler ekranı: tek gerçek anahtar (günlük hatırlatma) Firestore'a
/// yazar ve kayıtlı değeri yansıtır; haftalık özet ile ödeme hatırlatmaları
/// DURUM satırı (anahtar değil); sistem izni yalnız biliniyorsa çizilir;
/// her satırın açıklaması var; referanstaki yabancı özellikler ("magic",
/// e-posta özeti) yok; 320/360dp × üç dil taşmıyor.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final settingsPath = 'users/$testUid/settings/main';

  Future<FakeFirebaseFirestore> seededDb() async {
    final db = FakeFirebaseFirestore();
    await db.doc(settingsPath).set({'onboardingDone': true, 'currency': 'TRY'});
    return db;
  }

  Future<Map<String, dynamic>> settingsDoc(FakeFirebaseFirestore db) async =>
      (await db.doc(settingsPath).get()).data() ?? const {};

  /// Harness kendi ProviderScope'unu kuruyor; izin sağlayıcısını iç içe bir
  /// scope ile eziyoruz — yalnız bu ekran okuyor, üstte bağımlısı yok.
  Widget withPermission(bool? value) => ProviderScope(
        overrides: [
          notificationPermissionProvider.overrideWith((ref) async => value),
        ],
        child: const NotificationPreferencesScreen(),
      );

  group('günlük hatırlatma anahtarı', () {
    testWidgets('kapalı başlar, dokununca Firestore\'a yazar', (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const NotificationPreferencesScreen(),
          db: db, language: AppLanguage.tr);
      final str = Strings.tr;

      expect(find.byType(Switch), findsOneWidget,
          reason: 'tek gerçek anahtar var: günlük hatırlatma');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text(str.dailyReminderLabel), findsOneWidget);
      // Kapalıyken saat satırı yok.
      expect(find.text(str.notifDailyHourTitle), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final doc = await settingsDoc(db);
      expect(doc['dailyReminder'], isTrue);
      // Açarken varsayılan saat de yazılır — planlayıcı 21'i oradan okur.
      expect(doc['dailyHour'], 21);
      // Diğer alanlar korunur (merge).
      expect(doc['onboardingDone'], isTrue);
    });

    testWidgets('satıra dokunmak da çevirir', (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const NotificationPreferencesScreen(),
          db: db, language: AppLanguage.en);
      await tester.tap(find.text(Strings.en.dailyReminderLabel));
      await tester.pumpAndSettle();
      expect((await settingsDoc(db))['dailyReminder'], isTrue);
    });

    testWidgets('kayıtlı açık değer anahtara ve saate yansır; kapatınca yazar',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const NotificationPreferencesScreen(),
          db: db,
          language: AppLanguage.ru,
          profile: const {'dailyReminder': true, 'dailyHour': 9});
      final str = Strings.ru;

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text(str.notifDailyHourTitle), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final doc = await settingsDoc(db);
      expect(doc['dailyReminder'], isFalse);
      // Kapatırken saat EZİLMEZ — tekrar açınca aynı saat gelsin.
      expect(doc.containsKey('dailyHour'), isFalse);
    });

    testWidgets('saat satırı seçiciyi açar ve dailyHour yazar',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const NotificationPreferencesScreen(),
          db: db,
          language: AppLanguage.tr,
          profile: const {'dailyReminder': true, 'dailyHour': 21});

      await tester.tap(find.text(Strings.tr.notifDailyHourTitle));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      // Varsayılan saati onaylamak bile alanı yazar (davranış korunuyor).
      // Düğme etiketi yerelleştirilmiş ("TAMAM"/"OK"): sabit metin yerine
      // Material'ın kendi etiketini kullanıyoruz.
      final loc = MaterialLocalizations.of(
          tester.element(find.byType(TimePickerDialog)));
      await tester.tap(find.text(loc.okButtonLabel));
      await tester.pumpAndSettle();
      expect((await settingsDoc(db))['dailyHour'], 21);
    });
  });

  group('durum satırları', () {
    testWidgets('haftalık özet ve ödemeler anahtar değil, açıklamalı',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, const NotificationPreferencesScreen(),
          db: db, language: AppLanguage.tr);
      final str = Strings.tr;

      expect(find.text(str.weeklySummaryTitle), findsOneWidget);
      expect(find.text(str.notifWeeklyDesc), findsOneWidget);
      expect(find.text(str.channelPaymentsName), findsOneWidget);
      // Harness'ta hatırlatıcı listesi boş: sayı 0 yazılır.
      expect(find.text(tpl(str.notifPaymentsDescTpl, {'n': '0'})),
          findsOneWidget);
      // Yönetim eylemi vurgu satırı olarak kartın sonunda.
      expect(find.widgetWithText(SettingsActionRow, str.notifManagePayments),
          findsOneWidget);
      // Hâlâ tek anahtar: durum satırları Switch taşımıyor.
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('her satırın açıklaması var — çıplak başlık yok',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, withPermission(true),
          db: db,
          language: AppLanguage.en,
          profile: const {'dailyReminder': true});
      final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow));
      expect(rows, isNotEmpty);
      for (final r in rows) {
        final explained = (r.description?.isNotEmpty ?? false) ||
            (r.value?.isNotEmpty ?? false);
        expect(explained, isTrue,
            reason: '"${r.title}" satırı açıklama ya da değer taşımalı');
      }
    });
  });

  group('sistem izni', () {
    testWidgets('durum bilinmiyorsa bölüm hiç çizilmez', (tester) async {
      final db = await seededDb();
      // Testte platform kanalı yok → sağlayıcı null döner.
      await pumpBudgyScreen(tester, const NotificationPreferencesScreen(),
          db: db, language: AppLanguage.tr);
      final str = Strings.tr;
      expect(find.text(str.notifSectionSystem), findsNothing);
      expect(find.text(str.notifPermGrantedTitle), findsNothing);
      expect(find.text(str.notifPermDeniedTitle), findsNothing);
    });

    testWidgets('izin verildiyse yeşil tik satırı', (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, withPermission(true),
          db: db, language: AppLanguage.tr);
      final str = Strings.tr;
      expect(find.text(str.notifSectionSystem), findsOneWidget);
      expect(find.text(str.notifPermGrantedTitle), findsOneWidget);
      expect(find.text(str.notifPermGrantedBody), findsOneWidget);
      expect(find.text(str.notifPermDeniedTitle), findsNothing);
    });

    testWidgets('reddedildiyse uyarı satırı ve cihaz ayarı yönlendirmesi',
        (tester) async {
      final db = await seededDb();
      await pumpBudgyScreen(tester, withPermission(false),
          db: db, language: AppLanguage.en);
      final str = Strings.en;
      expect(find.text(str.notifPermDeniedTitle), findsOneWidget);
      expect(find.text(str.notifPermDeniedBody), findsOneWidget);
      expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
      expect(find.text(str.notifPermGrantedTitle), findsNothing);
    });
  });

  testWidgets('uydurma ayar yok: magic / e-posta özeti / gün öncesi',
      (tester) async {
    final db = await seededDb();
    await pumpBudgyScreen(tester, withPermission(true),
        db: db, language: AppLanguage.en);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    const forbidden = [
      'magic',
      'email',
      'e-mail',
      'digest',
      'day-before',
      'snooze',
      'tap',
    ];
    for (final word in forbidden) {
      expect(texts.any((s) => s.contains(word)), isFalse,
          reason: '"$word" içeren metin olmamalı — bu özellik bizde yok');
    }
    // Eski ekranın bildirimle ilgisiz kapıları da burada değil artık.
    expect(find.text(Strings.en.changePassword), findsNothing);
    expect(find.text(Strings.en.confidentialityPolicy), findsNothing);
  });

  group('yerleşim', () {
    // 320dp: iPhone SE (1. nesil) · 360dp: en yaygın Android genişliği.
    for (final width in [320.0, 360.0]) {
      for (final lang in AppLanguage.values) {
        testWidgets('${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
          final db = await seededDb();
          // En kalabalık hâl: izin bölümü + saat satırı görünür.
          await pumpBudgyScreen(tester, withPermission(false),
              db: db,
              language: lang,
              profile: const {'dailyReminder': true, 'dailyHour': 21},
              logicalSize: Size(width, 800));
          expect(tester.takeException(), isNull);
          final str = switch (lang) {
            AppLanguage.en => Strings.en,
            AppLanguage.tr => Strings.tr,
            AppLanguage.ru => Strings.ru,
          };
          // Alt karta kadar kaydırılabiliyor. ListView tembel: ekran dışı
          // satır henüz kurulmadığından `ensureVisible` bulamaz; gerçekten
          // kaydırıp görünene kadar bekliyoruz.
          await tester.scrollUntilVisible(
            find.text(str.notifManagePayments),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(str.notifManagePayments), findsOneWidget);
        });
      }
    }
  });
}
