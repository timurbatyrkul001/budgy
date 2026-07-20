import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/notifications.dart';
import '../auth/auth_gate.dart';
import '../envelopes/budget_repository.dart';
import '../workdays/work_days_repository.dart';

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(
    FirebaseFirestore.instance,
    ref.watch(uidProvider),
  );
});

final remindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(remindersRepositoryProvider).watchAll();
});

/// Günlük hatırlatma ayarı (settings/main → dailyReminder + dailyHour).
final dailyReminderProvider = Provider<({bool enabled, int hour})>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  return (
    enabled: p['dailyReminder'] == true,
    hour: (p['dailyHour'] as num?)?.toInt() ?? 21,
  );
});

/// Держит локальные уведомления в синхроне с Firestore (ödeme + günlük).
/// Достаточно watch-нуть один раз на главном экране.
final reminderSchedulerProvider = Provider<void>((ref) {
  Future<void> reschedule() async {
    final reminders = ref.read(remindersProvider).value;
    final daily = ref.read(dailyReminderProvider);
    final str = ref.read(strProvider);
    await Notifications.cancelAll();
    if (reminders != null) {
      for (final reminder in reminders) {
        for (var day = reminder.fromDay; day <= reminder.toDay; day++) {
          await Notifications.scheduleMonthly(
            id: Object.hash(reminder.id, day) & 0x7fffffff,
            title: reminder.name,
            body: reminder.amount != null
                ? tpl(str.dontForgetTpl, {'x': formatMoney(reminder.amount!)})
                : str.dontForgetPlain,
            day: day,
          );
        }
      }
    }
    if (daily.enabled) {
      await Notifications.scheduleDaily(
        id: 990001,
        title: str.dailyReminderTitle,
        body: str.dailyReminderBody,
        hour: daily.hour,
      );
      // Haftalık özet: Pazar 20:00 — bu haftaki kazanç toplamı.
      final earned = ref.read(allWorkDaysProvider).value ?? const [];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final weekTotal = earned.fold<double>(0, (acc, d) {
        final day = DateTime(d.date.year, d.date.month, d.date.day);
        final inWeek = !day.isBefore(monday) && !day.isAfter(sunday);
        return inWeek ? acc + (d.amount ?? 0) : acc;
      });
      await Notifications.scheduleWeekly(
        id: 990002,
        title: str.weeklySummaryTitle,
        body: tpl(str.weeklySummaryBodyTpl, {'x': formatMoney(weekTotal)}),
        weekday: DateTime.sunday,
        hour: 20,
      );
    }
  }

  ref.listen(remindersProvider, (_, _) => reschedule(), fireImmediately: true);
  ref.listen(dailyReminderProvider, (_, _) => reschedule());
});

/// Bir düzenli giderin bu ay/gelecek en yakın ödeme bilgisi.
class RecurringItem {
  const RecurringItem({
    required this.reminder,
    required this.nextDue,
    required this.daysUntil,
    required this.dueNow,
  });

  final Reminder reminder;
  final DateTime nextDue;
  final int daysUntil; // bugüne kalan gün (dueNow ise 0)
  final bool dueNow; // bugün ödeme aralığında mı ([fromDay, toDay])
}

/// Düzenli giderler, en yakın ödemesi başta olacak şekilde sıralı.
final recurringExpensesProvider = Provider<List<RecurringItem>>((ref) {
  final reminders = ref.watch(remindersProvider).value ?? const [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  final items = <RecurringItem>[];
  for (final r in reminders) {
    final dueNow = now.day >= r.fromDay && now.day <= r.toDay;
    DateTime nextDue;
    if (dueNow) {
      nextDue = today;
    } else if (now.day < r.fromDay) {
      final dim = daysInMonth(now.year, now.month);
      nextDue = DateTime(now.year, now.month, r.fromDay.clamp(1, dim));
    } else {
      final ny = now.month == 12 ? now.year + 1 : now.year;
      final nm = now.month == 12 ? 1 : now.month + 1;
      final dim = daysInMonth(ny, nm);
      nextDue = DateTime(ny, nm, r.fromDay.clamp(1, dim));
    }
    items.add(RecurringItem(
      reminder: r,
      nextDue: nextDue,
      daysUntil: nextDue.difference(today).inDays,
      dueNow: dueNow,
    ));
  }
  items.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
  return items;
});

/// Aylık düzenli gider toplamı (tutarı girilmiş hatırlatıcılar).
final recurringMonthlyTotalProvider = Provider<double>((ref) {
  final reminders = ref.watch(remindersProvider).value ?? const [];
  return reminders.fold<double>(0, (a, r) => a + (r.amount ?? 0));
});

/// Напоминание о платеже: «Аренда, 15 000 ₺, с 1 по 5 число месяца».
class Reminder {
  const Reminder({
    required this.id,
    required this.name,
    required this.fromDay,
    required this.toDay,
    this.amount,
  });

  final String id;
  final String name;
  final int fromDay;
  final int toDay;
  final double? amount;

  factory Reminder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Reminder(
      id: doc.id,
      name: data['name'] as String,
      fromDay: data['fromDay'] as int,
      toDay: data['toDay'] as int,
      amount: (data['amount'] as num?)?.toDouble(),
    );
  }
}

class RemindersRepository {
  RemindersRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _reminders =>
      _db.collection('users').doc(_uid).collection('reminders');

  Stream<List<Reminder>> watchAll() => _reminders
      .orderBy('fromDay')
      .snapshots()
      .map((snap) => snap.docs.map(Reminder.fromDoc).toList());

  Future<void> add({
    required String name,
    required int fromDay,
    required int toDay,
    double? amount,
  }) {
    return _reminders.add({
      'name': name,
      'fromDay': fromDay,
      'toDay': toDay,
      'amount': amount,
    });
  }

  Future<void> remove(String id) => _reminders.doc(id).delete();
}
