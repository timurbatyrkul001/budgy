import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Локальные уведомления: напоминания о платежах (аренда и т.п.).
/// Расписание живёт на устройстве; источник правды — Firestore,
/// при изменении списка всё пересоздаётся заново.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    // Android 13+ (API 33) bildirim iznini çalışma anında ister. Bu çağrı
    // olmadan zamanlanan hatırlatmalar hiç görünmez.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// Ayın [day]. gününü o ay için geçerli bir güne kırpar:
  /// 31 istenip ay 30 çekiyorsa 30'a düşer (yoksa bir sonraki aya kayardı).
  static tz.TZDateTime _monthlyAt(int year, int month, int day, int hour) {
    // Ayın son günü: bir sonraki ayın 0. günü.
    final lastDay = DateTime(year, month + 1, 0).day;
    return tz.TZDateTime(tz.local, year, month, day.clamp(1, lastDay), hour);
  }

  /// Ежемесячное напоминание: каждый [day] день месяца в 10:00.
  ///
  /// [channelName]/[channelDescription] Android sistem ayarlarında kullanıcıya
  /// görünür — bu yüzden uygulamanın dilinden geçirilir.
  static Future<void> scheduleMonthly({
    required int id,
    required String title,
    required String body,
    required int day,
    required String channelName,
    required String channelDescription,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = _monthlyAt(now.year, now.month, day, 10);
    if (!when.isAfter(now)) {
      when = _monthlyAt(now.year, now.month + 1, day, 10);
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        iOS: const DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'reminders',
          channelName,
          channelDescription: channelDescription,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Повтор каждый месяц в этот день и время.
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// Günlük hatırlatma: her gün [hour]:[minute]'da (harcama girme dürtüsü).
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required String channelName,
    required String channelDescription,
    int minute = 0,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        iOS: const DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'daily',
          channelName,
          channelDescription: channelDescription,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // her gün aynı saat
    );
  }

  /// Haftalık özet: her hafta [weekday] günü (1=Pzt … 7=Paz) [hour]:00'da.
  static Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required String channelName,
    required String channelDescription,
    int minute = 0,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // İstenen hafta gününe ve geçmemiş bir zamana ilerle.
    while (when.weekday != weekday || !when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
      when = tz.TZDateTime(
          tz.local, when.year, when.month, when.day, hour, minute);
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        iOS: const DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'weekly',
          channelName,
          channelDescription: channelDescription,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Her hafta aynı gün ve saatte tekrar.
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
