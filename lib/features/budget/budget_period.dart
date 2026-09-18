import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../envelopes/budget_repository.dart';
import '../transactions/tx.dart';

/// Bütçe dönemi. settings/main → budgetPeriod: 'weekly' | 'monthly'.
enum BudgetPeriod { weekly, monthly }

/// Genel bütçe ayarı (settings/main): `budgetAmount`, `budgetPeriod`,
/// `budgetWeekStart` (1 = Pzt … 7 = Paz). Eski `monthlyBudget` alanı
/// [fromProfile] içinde aylık bütçe olarak okunmaya devam eder — kimse
/// mevcut bütçesini kaybetmez; ilk kayıtta yeni alanlara taşınır.
class BudgetSettings {
  const BudgetSettings({
    required this.amount,
    required this.period,
    this.weekStart = DateTime.monday,
  });

  final double amount;
  final BudgetPeriod period;

  /// Haftalık dönemin başladığı gün (DateTime.monday..sunday).
  final int weekStart;

  static BudgetSettings? fromProfile(Map<String, dynamic> p) {
    final amount = (p['budgetAmount'] as num?)?.toDouble();
    if (amount != null && amount > 0) {
      final period = p['budgetPeriod'] == 'weekly'
          ? BudgetPeriod.weekly
          : BudgetPeriod.monthly;
      final ws = (p['budgetWeekStart'] as num?)?.toInt() ?? DateTime.monday;
      return BudgetSettings(
        amount: amount,
        period: period,
        weekStart: ws.clamp(DateTime.monday, DateTime.sunday),
      );
    }
    // Eski model: yalnız aylık tutar.
    final legacy = (p['monthlyBudget'] as num?)?.toDouble();
    if (legacy != null && legacy > 0) {
      return BudgetSettings(amount: legacy, period: BudgetPeriod.monthly);
    }
    return null;
  }

  /// Firestore'a yazılacak alanlar; eski alan temizlenir.
  Map<String, dynamic> toProfile() => {
        'budgetAmount': amount,
        'budgetPeriod': period.name,
        'budgetWeekStart': weekStart,
        'monthlyBudget': null,
      };

  /// Kaldırma: tüm alanlar boş.
  static const Map<String, dynamic> cleared = {
    'budgetAmount': null,
    'budgetPeriod': null,
    'budgetWeekStart': null,
    'monthlyBudget': null,
  };
}

/// Bir dönemin penceresi: [start, end) — end hariç.
class PeriodWindow {
  const PeriodWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get totalDays => end.difference(start).inDays;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  /// Bugün dahil kalan gün sayısı.
  int daysLeft(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return end.difference(today).inDays.clamp(0, totalDays);
  }

  /// Bugün dahil geçen gün sayısı (tempo hesabı için, en az 1).
  int daysElapsed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return (today.difference(start).inDays + 1).clamp(1, totalDays);
  }
}

/// [now]'ı kapsayan dönem penceresi. Aylık: takvim ayı. Haftalık:
/// [weekStart] gününden başlayan 7 gün (Pzt varsayılan).
PeriodWindow periodWindow(
  DateTime now,
  BudgetPeriod period, {
  int weekStart = DateTime.monday,
}) {
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case BudgetPeriod.monthly:
      return PeriodWindow(
          DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
    case BudgetPeriod.weekly:
      final back = (today.weekday - weekStart) % 7;
      final start = today.subtract(Duration(days: back));
      return PeriodWindow(start, start.add(const Duration(days: 7)));
  }
}

/// Bütçe ayarı (yoksa null). Eski `monthlyBudget` da burada okunur.
final budgetSettingsProvider = Provider<BudgetSettings?>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  return BudgetSettings.fromProfile(p);
});

/// Geçerli dönem penceresi: ayar yoksa takvim ayı.
final budgetWindowProvider = Provider<PeriodWindow>((ref) {
  final s = ref.watch(budgetSettingsProvider);
  return periodWindow(
    DateTime.now(),
    s?.period ?? BudgetPeriod.monthly,
    weekStart: s?.weekStart ?? DateTime.monday,
  );
});

bool _countsAsSpend(Tx t) =>
    t.type == TxType.expense &&
    !t.isConvert &&
    !t.isGoalFund &&
    t.currency == 'TRY';

/// Geçerli bütçe döneminde harcanan ₺ (bütçe kartı / tempo).
final periodSpentProvider = Provider<double>((ref) {
  final w = ref.watch(budgetWindowProvider);
  final txs = ref.watch(recentTxsProvider).value ?? const [];
  return txs
      .where((t) => _countsAsSpend(t) && w.contains(t.date))
      .fold<double>(0, (s, t) => s + t.amount);
});

/// Geçerli dönemde zarf bazında harcama. Aylıkta mevcut
/// [monthlySpentByEnvelopeProvider] ile aynı (testler onu override eder).
final periodSpentByEnvelopeProvider = Provider<Map<String, double>>((ref) {
  final s = ref.watch(budgetSettingsProvider);
  if (s == null || s.period == BudgetPeriod.monthly) {
    return ref.watch(monthlySpentByEnvelopeProvider);
  }
  final w = ref.watch(budgetWindowProvider);
  final txs = ref.watch(recentTxsProvider).value ?? const [];
  final map = <String, double>{};
  for (final t in txs) {
    if (!_countsAsSpend(t) || !w.contains(t.date)) continue;
    final id = t.envelopeId;
    if (id == null) continue;
    map[id] = (map[id] ?? 0) + t.amount;
  }
  return map;
});

/// Son [days] gündeki zarf bazlı harcama (öneri ve satır altyazıları).
Map<String, double> spentInLastDays(List<Tx> txs, int days, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final from = today.subtract(Duration(days: days - 1));
  final map = <String, double>{};
  for (final t in txs) {
    if (!_countsAsSpend(t) || t.date.isBefore(from)) continue;
    final id = t.envelopeId;
    if (id == null) continue;
    map[id] = (map[id] ?? 0) + t.amount;
  }
  return map;
}

/// Son [days] gündeki toplam ₺ harcama (tutar adımındaki ipucu).
double totalInLastDays(List<Tx> txs, int days, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final from = today.subtract(Duration(days: days - 1));
  return txs
      .where((t) => _countsAsSpend(t) && !t.date.isBefore(from))
      .fold<double>(0, (s, t) => s + t.amount);
}
