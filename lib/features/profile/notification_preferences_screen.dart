import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../envelopes/budget_repository.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import '../settings/settings_hub.dart';

/// Sistem bildirim izni: `true` verildi, `false` reddedildi, `null` bilinmiyor.
///
/// Ayrı bir sağlayıcı olmasının nedeni dürüstlük: izin durumunu platformdan
/// okuyamadığımız yerde (web, test, eklenti kanalı yok) `null` dönüyoruz ve
/// ekran o bölümü HİÇ çizmiyor — uydurma bir "yeşil tik" göstermektense
/// bölümü gizlemek daha doğru. Eklenti tekil ([FlutterLocalNotificationsPlugin]
/// factory'si hep aynı örneği verir), bu yüzden `notifications.dart`'taki
/// özel `_plugin`'e dokunmadan aynı kanaldan okuyabiliyoruz.
///
/// iOS'ta `checkPermissions` sistem izin penceresini AÇMAZ, yalnız okur;
/// izin isteme işi onboarding'de ([Notifications.init]) kalıyor.
final notificationPermissionProvider = FutureProvider<bool?>((ref) async {
  if (kIsWeb) return null;
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    if (Platform.isIOS) {
      final opts = await plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return opts?.isEnabled;
    }
    if (Platform.isAndroid) {
      return await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
  } catch (_) {
    // MissingPluginException vb.: durum bilinmiyor, bölüm gizlenir.
  }
  return null;
});

/// Bildirimler — ayarlar hub'ının alt ekranı ([SettingsPage] iskeleti).
///
/// Yalnız uygulamanın GERÇEKTEN planladığı bildirimler var; kaynak
/// `reminders_repository.dart › reminderSchedulerProvider`:
///  1. Günlük hatırlatma (`dailyReminder` + `dailyHour`) — tek gerçek anahtar.
///  2. Haftalık özet — ayrı bir alan yok, günlük hatırlatma açıkken planlanır;
///     bu yüzden anahtar değil DURUM satırı (yeşil tik / soluk).
///  3. Ödeme hatırlatmaları — her düzenli gider için otomatik; genel bir
///     aç/kapa yok, yönetim yeri düzenli giderler ekranı. Yine durum satırı
///     + kartın sonunda yönetim eylemi.
/// Şifre değiştir / gizlilik satırları buradan çıktı: artık Hesabım ›
/// Giriş ve güvenlik ile Hakkında ekranlarında yaşıyorlar; bildirim
/// ekranında alakasız iki kapı kullanıcıyı şaşırtıyordu.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final str = ref.watch(strProvider);
    final daily = ref.watch(dailyReminderProvider);
    final permission = ref.watch(notificationPermissionProvider).value;
    final reminderCount = ref.watch(remindersProvider).value?.length ?? 0;

    Future<void> save(Map<String, dynamic> m) =>
        ref.read(budgetRepositoryProvider).saveProfile(m);

    // Anahtar ve satır dokunuşu aynı işi yapar: küçük anahtara nişan almak
    // zorunlu olmasın. Açarken saat de yazılır ki planlayıcı varsayılanı
    // değil kullanıcının son seçimini kullansın.
    Future<void> setDaily(bool v) => save({
          'dailyReminder': v,
          if (v) 'dailyHour': daily.hour,
        });

    Future<void> pickHour() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: daily.hour, minute: 0),
      );
      if (picked != null) await save({'dailyHour': picked.hour});
    }

    final hourLabel = '${daily.hour.toString().padLeft(2, '0')}:00';

    return SettingsPage(
      hero: SettingsHero(
        icon: Icons.notifications_rounded,
        title: str.notifTitle,
        body: str.notifHeroBody,
      ),
      children: [
        // ── Sistem izni: yalnız durum gerçekten biliniyorsa ────────────
        if (permission != null)
          SettingsCard(label: str.notifSectionSystem, rows: [
            SettingsRow(
              icon: permission
                  ? Icons.verified_user_rounded
                  : Icons.gpp_maybe_rounded,
              title: permission
                  ? str.notifPermGrantedTitle
                  : str.notifPermDeniedTitle,
              description: permission
                  ? str.notifPermGrantedBody
                  : str.notifPermDeniedBody,
              trailing: _StatusMark(
                  state: permission ? _Status.on : _Status.warning),
            ),
          ]),

        // ── Günlük ─────────────────────────────────────────────────────
        SettingsCard(label: str.notifSectionDaily, rows: [
          SettingsRow(
            icon: Icons.notifications_active_rounded,
            title: str.dailyReminderLabel,
            description: str.notifDailyDesc,
            onTap: () => setDaily(!daily.enabled),
            trailing: Switch(
              value: daily.enabled,
              activeThumbColor: Ex.mint,
              onChanged: setDaily,
            ),
          ),
          // Saat satırı yalnız hatırlatma açıkken: kapalıyken saat seçmek
          // hiçbir şeyi değiştirmez, boş bir ayar gibi dururdu.
          if (daily.enabled)
            SettingsRow(
              icon: Icons.schedule_rounded,
              title: str.notifDailyHourTitle,
              value: hourLabel,
              onTap: pickHour,
            ),
          SettingsRow(
            icon: Icons.calendar_view_week_rounded,
            title: str.weeklySummaryTitle,
            description: str.notifWeeklyDesc,
            trailing:
                _StatusMark(state: daily.enabled ? _Status.on : _Status.off),
          ),
        ]),

        // ── Ödemeler ───────────────────────────────────────────────────
        SettingsCard(label: str.notifSectionPayments, rows: [
          SettingsRow(
            icon: Icons.receipt_long_rounded,
            title: str.channelPaymentsName,
            description:
                tpl(str.notifPaymentsDescTpl, {'n': '$reminderCount'}),
            trailing: _StatusMark(
                state: reminderCount > 0 ? _Status.on : _Status.off),
          ),
          SettingsActionRow(
            title: str.notifManagePayments,
            onTap: () => pushSettings(context, const RemindersScreen()),
          ),
        ]),
      ],
    );
  }
}

enum _Status { on, off, warning }

/// Durum satırının sağındaki gösterge — anahtar DEĞİL.
///
/// Yeşil tik "bu bildirim şu an planlı", soluk daire "planlı değil", amber
/// ünlem "sistem engelliyor". Anahtar görünümünden bilinçli olarak uzak:
/// kullanıcı dokunup değiştirmeye çalışmasın, bunların denetimi başka yerde
/// (günlük anahtarı / düzenli giderler / cihaz ayarları).
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.state});
  final _Status state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      _Status.on => (Ex.mint, Icons.check_rounded),
      _Status.off => (Ex.textFaint, Icons.remove_rounded),
      _Status.warning => (Ex.amber, Icons.priority_high_rounded),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
