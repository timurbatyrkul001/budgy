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
///
/// **Cüzdan modeli:** gün işaretlenip tutar girildiği AN para cüzdana girer —
/// eski "dağıtılmayı bekleyen" ara durumu yok. Düzenleme yalnız FARKI
/// uygular, silme tutarı geri çeker. Bu fark-kuralı göç öncesi günler için
/// de doğrudur: onların tutarı göç toplamına zaten girmişti.
///
/// Günler için ayrı işlem (tx) belgesi YAZILMAZ — geçmiş ekranı günleri
/// sentetik gelir satırı olarak zaten gösteriyor; ikinci bir kayıt aynı
/// parayı istatistikte iki kez saydırırdı.
class WorkDaysRepository {
  WorkDaysRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _workDays =>
      _db.collection('users').doc(_uid).collection('workDays');

  DocumentReference<Map<String, dynamic>> get _cash =>
      _db.collection('users').doc(_uid).collection('accounts').doc('cash');

  Stream<Map<DateTime, double?>> watchMonth(String monthKey) {
    return _workDays.where('month', isEqualTo: monthKey).snapshots().map(
          (snap) => {
            for (final doc in snap.docs)
              DateTime.parse(doc.id):
                  (doc.data()['amount'] as num?)?.toDouble(),
          },
        );
  }

  /// Отметить день с заработком. Кошелёк двигается на разницу со старой
  /// суммой — правка дня не удваивает деньги.
  Future<void> setDay(DateTime day, {double? amount}) async {
    final ref = _workDays.doc(_dayId(day));
    final prev =
        ((await ref.get()).data()?['amount'] as num?)?.toDouble() ?? 0;
    final next = amount ?? 0;

    final batch = _db.batch();
    batch.set(ref, {
      'month': monthKeyOf(day),
      'amount': amount,
    }, SetOptions(merge: true));
    if (next != prev) {
      batch.set(_cash, {'balance': FieldValue.increment(next - prev)},
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Снять отметку дня; его заработок возвращается из кошелька.
  Future<void> removeDay(DateTime day) async {
    final ref = _workDays.doc(_dayId(day));
    final prev =
        ((await ref.get()).data()?['amount'] as num?)?.toDouble() ?? 0;

    final batch = _db.batch();
    batch.delete(ref);
    if (prev != 0) {
      batch.set(_cash, {'balance': FieldValue.increment(-prev)},
          SetOptions(merge: true));
    }
    await batch.commit();
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
}
