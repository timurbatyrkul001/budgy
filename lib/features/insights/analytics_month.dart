import '../envelopes/envelope.dart';
import '../transactions/tx.dart';

/// Bir kategorinin ay içindeki özeti.
class CategoryStat {
  const CategoryStat({
    required this.envelopeId,
    required this.name,
    required this.emoji,
    required this.count,
    required this.amount,
  });

  /// null = kategorisiz.
  final String? envelopeId;
  final String name;
  final String emoji;
  final int count;
  final double amount;
}

/// Analiz ekranının bir aylık verisi — saf hesap, Firestore yok.
/// Yalnız gerçek ₺ giderler (döviz çevirme, hedefe para ayırma, döviz hariç).
class MonthAnalytics {
  const MonthAnalytics({
    required this.month,
    required this.total,
    required this.count,
    required this.buckets,
    required this.byCategory,
    required this.busiestWeekday,
    required this.busiestWeekdayAmount,
    required this.avgPerDay,
    required this.daysCounted,
  });

  final DateTime month;
  final double total;
  final int count;

  /// Hafta kovaları: 1-7, 8-14, 15-21, 22-28, 29-ay sonu.
  final List<double> buckets;

  /// Tutara göre azalan.
  final List<CategoryStat> byCategory;

  /// 1 = Pzt … 7 = Paz; veri yoksa null.
  final int? busiestWeekday;
  final double busiestWeekdayAmount;

  /// Toplam / sayılan gün (geçerli ay: bugüne kadar, geçmiş ay: tüm ay).
  final double avgPerDay;
  final int daysCounted;

  bool get isEmpty => count == 0;

  CategoryStat? get topCategory =>
      byCategory.isEmpty ? null : byCategory.first;

  /// En çok işlem yapılan kategori.
  CategoryStat? get mostPurchases => byCategory.isEmpty
      ? null
      : byCategory.reduce((a, b) => b.count > a.count ? b : a);

  /// Kova etiketi: "1-7" … "29-30".
  static String bucketLabel(int i, int daysInMonth) {
    final start = i * 7 + 1;
    final end = i == 4 ? daysInMonth : start + 6;
    return start == end ? '$start' : '$start-$end';
  }

  /// Şu an içinde bulunulan kova (geçerli ay), yoksa null.
  static int? currentBucket(DateTime month, DateTime now) {
    if (month.year != now.year || month.month != now.month) return null;
    return ((now.day - 1) ~/ 7).clamp(0, 4);
  }
}

/// [txs]'ten [month] için analiz. [categoryId] verilirse yalnız o kategori
/// ('' = kategorisiz). [nameOf] zarf adını dilden çözer.
MonthAnalytics analyzeMonth(
  List<Tx> txs,
  DateTime month, {
  String? categoryId,
  required Map<String, Envelope> envelopes,
  required String Function(Envelope) nameOf,
  required String uncategorizedLabel,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final buckets = List<double>.filled(5, 0);
  final byWeekday = List<double>.filled(8, 0); // 1..7
  final amountBy = <String?, double>{};
  final countBy = <String?, int>{};
  var total = 0.0;
  var count = 0;

  for (final t in txs) {
    if (t.type != TxType.expense || t.isConvert || t.isGoalFund) continue;
    if (t.currency != 'TRY') continue;
    if (t.date.year != month.year || t.date.month != month.month) continue;
    final id = t.envelopeId;
    if (categoryId != null && (id ?? '') != categoryId) continue;
    total += t.amount;
    count++;
    buckets[((t.date.day - 1) ~/ 7).clamp(0, 4)] += t.amount;
    byWeekday[t.date.weekday] += t.amount;
    amountBy[id] = (amountBy[id] ?? 0) + t.amount;
    countBy[id] = (countBy[id] ?? 0) + 1;
  }

  final cats = <CategoryStat>[
    for (final e in amountBy.entries)
      CategoryStat(
        envelopeId: e.key,
        name: switch (envelopes[e.key]) {
          final env? => nameOf(env),
          null => uncategorizedLabel,
        },
        emoji: envelopes[e.key]?.emoji ?? '❔',
        count: countBy[e.key] ?? 0,
        amount: e.value,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));

  int? busiest;
  var busiestAmount = 0.0;
  for (var d = 1; d <= 7; d++) {
    if (byWeekday[d] > busiestAmount) {
      busiestAmount = byWeekday[d];
      busiest = d;
    }
  }

  final isCurrent = month.year == n.year && month.month == n.month;
  final daysCounted = isCurrent ? n.day : daysInMonth;

  return MonthAnalytics(
    month: month,
    total: total,
    count: count,
    buckets: buckets,
    byCategory: cats,
    busiestWeekday: busiest,
    busiestWeekdayAmount: busiestAmount,
    avgPerDay: daysCounted == 0 ? 0 : total / daysCounted,
    daysCounted: daysCounted,
  );
}
