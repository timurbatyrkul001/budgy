import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_gate.dart';

final workDaysRepositoryProvider = Provider<WorkDaysRepository>((ref) {
  return WorkDaysRepository(
    FirebaseFirestore.instance,
    ref.watch(uidProvider),
  );
});

/// Рабочие дни месяца: дата -> заработок за этот день. Ключ — '2026-06'.
final monthWorkDaysProvider =
    StreamProvider.family<Map<DateTime, double?>, String>((ref, monthKey) {
  return ref.watch(workDaysRepositoryProvider).watchMonth(monthKey);
});

/// Отработанные, но ещё не распределённые по конвертам дни (до сегодня).
final unallocatedWorkDaysProvider = StreamProvider<List<WorkDay>>((ref) {
  return ref.watch(workDaysRepositoryProvider).watchUnallocated();
});

/// Tüm kazançlı çalışma günleri (Geçmiş'te gelir olarak göstermek için).
final allWorkDaysProvider = StreamProvider<List<WorkDay>>((ref) {
  return ref.watch(workDaysRepositoryProvider).watchAllEarned();
});

String monthKeyOf(DateTime date) => DateFormat('yyyy-MM').format(date);

String _dayId(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Рабочий день: дата и заработок за него.
class WorkDay {
  const WorkDay({required this.id, required this.date, this.amount});

  final String id;
  final DateTime date;
  final double? amount;
}

/// Отметки рабочих дней: users/{uid}/workDays/{yyyy-MM-dd}.
/// Ставка лежит в users/{uid}/settings/main.
class WorkDaysRepository {
  WorkDaysRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _workDays =>
      _db.collection('users').doc(_uid).collection('workDays');

  Stream<Map<DateTime, double?>> watchMonth(String monthKey) {
    return _workDays.where('month', isEqualTo: monthKey).snapshots().map(
          (snap) => {
            for (final doc in snap.docs)
              DateTime.parse(doc.id):
                  (doc.data()['amount'] as num?)?.toDouble(),
          },
        );
  }

  /// Отметить день рабочим с заработком за этот день.
  /// merge — чтобы не сбросить флаг allocated при правке суммы.
  Future<void> setDay(DateTime day, {double? amount}) {
    return _workDays.doc(_dayId(day)).set({
      'month': monthKeyOf(day),
      'amount': amount,
    }, SetOptions(merge: true));
  }

  Future<void> removeDay(DateTime day) {
    return _workDays.doc(_dayId(day)).delete();
  }

  /// Дни до сегодня включительно, ещё не внесённые как доход.
  Stream<List<WorkDay>> watchUnallocated() {
    return _workDays.snapshots().map((snap) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return snap.docs
          .where((doc) => doc.data()['allocated'] != true)
          .map((doc) => WorkDay(
                id: doc.id,
                date: DateTime.parse(doc.id),
                amount: (doc.data()['amount'] as num?)?.toDouble(),
              ))
          .where((day) => !day.date.isAfter(today))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  /// Kazancı girilmiş tüm günler (amount>0) — Geçmiş'te gelir olarak.
  Stream<List<WorkDay>> watchAllEarned() {
    return _workDays.snapshots().map((snap) => snap.docs
        .map((doc) => WorkDay(
              id: doc.id,
              date: DateTime.parse(doc.id),
              amount: (doc.data()['amount'] as num?)?.toDouble(),
            ))
        .where((d) => d.amount != null && d.amount! > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)));
  }

  /// Пометить дни распределёнными (после сохранения дохода).
  Future<void> markAllocated(List<String> dayIds) {
    final batch = _db.batch();
    for (final id in dayIds) {
      batch.update(_workDays.doc(id), {'allocated': true});
    }
    return batch.commit();
  }
}
