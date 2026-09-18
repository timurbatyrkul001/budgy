import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../budget/budget_period.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../transactions/tx.dart';
import '../workdays/work_days_repository.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Budgy içgörü katmanı: kazanç serisi (streak), harcama temposu (pace) ve
/// ay-ay kategori karşılaştırması. Hepsi mevcut stream'lerden türetilir,
/// ekstra Firestore okuması yok.
/// ────────────────────────────────────────────────────────────────────────

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Kazanç serisi: bugüne (ya da bugün henüz girilmediyse düne) kadar,
/// kesintisiz kazanç girilen ardışık gün sayısı.
final earningStreakProvider = Provider<int>((ref) {
  final earned = ref.watch(allWorkDaysProvider).value ?? const [];
  final days = <DateTime>{
    for (final d in earned)
      if ((d.amount ?? 0) > 0) _dayOnly(d.date),
  };
  if (days.isEmpty) return 0;

  final now = DateTime.now();
  var cursor = _dayOnly(now);
  // Bugün henüz kazanç yoksa seri kopmasın — dünden saymaya başla.
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

/// Bugün kazanç girildi mi? (Seri kartında "bugünü işaretle" ipucu için.)
final earnedTodayProvider = Provider<bool>((ref) {
  final earned = ref.watch(allWorkDaysProvider).value ?? const [];
  final today = _dayOnly(DateTime.now());
  return earned.any((d) => (d.amount ?? 0) > 0 && _dayOnly(d.date) == today);
});

/// Bir harcama zarfının bu ayki temposu (pace).
@immutable
class EnvelopePace {
  const EnvelopePace({
    required this.envelope,
    required this.spent,
    required this.budget,
    required this.projected,
    required this.daysLeft,
  });

  final Envelope envelope;
  final double spent; // bu dönemde şu ana dek harcanan
  final double budget; // dönem limiti (haftalık/aylık, bkz. BudgetSettings)
  final double projected; // dönem sonu tahmini (mevcut hızla)
  final int daysLeft; // dönem sonuna kalan gün

  /// Dönem sonunda bütçeyi aşması bekleniyor mu?
  bool get willExceed => projected > budget;

  /// Zaten aşmış mı?
  bool get exceeded => spent > budget;

  /// Bütçenin ne kadarı harcandı (0..1+).
  double get ratio => budget <= 0 ? 0 : spent / budget;

  /// Tahmini aşım tutarı.
  double get projectedOver => (projected - budget).clamp(0, double.infinity);
}

/// Bütçeli (harcama) zarflar için tempo listesi — en riskliden başa doğru.
/// Dönem, genel bütçe ayarından gelir (haftalık/aylık); ayar yoksa ay.
final paceProvider = Provider<List<EnvelopePace>>((ref) {
  final envelopes = ref.watch(envelopesProvider).value ?? const [];
  final spentByEnv = ref.watch(periodSpentByEnvelopeProvider);
  final window = ref.watch(budgetWindowProvider);

  final now = DateTime.now();
  final daysInMonth = window.totalDays;
  final dayOfMonth = window.daysElapsed(now);
  final daysLeft = daysInMonth - dayOfMonth;

  final result = <EnvelopePace>[];
  for (final e in envelopes) {
    if (e.archived || e.isGoal || e.currency != 'TRY') continue;
    final budget = e.targetAmount;
    if (budget == null || budget <= 0) continue;
    final spent = spentByEnv[e.id] ?? 0;
    // Mevcut günlük hızla ay sonu tahmini.
    final projected =
        dayOfMonth <= 0 ? spent : spent / dayOfMonth * daysInMonth;
    result.add(EnvelopePace(
      envelope: e,
      spent: spent,
      budget: budget,
      projected: projected,
      daysLeft: daysLeft,
    ));
  }
  // Aşma riski yüksek olan (tahmin/bütçe oranı) başa gelsin.
  result.sort((a, b) => (b.projected / b.budget).compareTo(a.projected / a.budget));
  return result;
});

/// Bu ay temposuyla bütçeyi aşması beklenen zarf sayısı (Ana ekran uyarısı).
final overPaceCountProvider = Provider<int>((ref) {
  return ref.watch(paceProvider).where((p) => p.willExceed).length;
});

/// Bir kategorinin bu ay / geçen ay harcama karşılaştırması.
@immutable
class CategoryDelta {
  const CategoryDelta({
    required this.envelope,
    required this.thisMonth,
    required this.lastMonth,
  });

  final Envelope envelope;
  final double thisMonth;
  final double lastMonth;

  double get diff => thisMonth - lastMonth;

  /// Yüzde değişim (geçen ay 0 ise null — "yeni" kabul edilir).
  int? get pctChange {
    if (lastMonth <= 0) return null;
    return ((thisMonth - lastMonth) / lastMonth * 100).round();
  }
}

/// Zarf bazında bu ay vs geçen ay gider karşılaştırması (mutlak farka göre
/// büyükten küçüğe). Döviz çevrimi, hedef-fonu ve TRY-dışı hariç.
final monthComparisonProvider = Provider<List<CategoryDelta>>((ref) {
  final txs = ref.watch(recentTxsProvider).value ?? const [];
  final envelopes = ref.watch(envelopesProvider).value ?? const [];
  final byId = {for (final e in envelopes) e.id: e};

  final now = DateTime.now();
  final thisM = DateTime(now.year, now.month);
  final lastM = DateTime(now.year, now.month - 1);

  final thisMap = <String, double>{};
  final lastMap = <String, double>{};
  for (final t in txs) {
    if (t.type != TxType.expense || t.isConvert || t.isGoalFund) continue;
    if (t.currency != 'TRY') continue;
    final id = t.envelopeId;
    if (id == null) continue;
    final m = DateTime(t.date.year, t.date.month);
    if (m == thisM) {
      thisMap[id] = (thisMap[id] ?? 0) + t.amount;
    } else if (m == lastM) {
      lastMap[id] = (lastMap[id] ?? 0) + t.amount;
    }
  }

  final ids = {...thisMap.keys, ...lastMap.keys};
  final result = <CategoryDelta>[];
  for (final id in ids) {
    final e = byId[id];
    if (e == null || e.isGoal) continue;
    result.add(CategoryDelta(
      envelope: e,
      thisMonth: thisMap[id] ?? 0,
      lastMonth: lastMap[id] ?? 0,
    ));
  }
  result.sort((a, b) => b.diff.abs().compareTo(a.diff.abs()));
  return result;
});
