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
/// Yalnız gerçek giderler (döviz çevirme ve hedefe para ayırma hariç).
///
/// Tüm tutarlar ana para biriminde: ₼ kartından yapılan harcama, kaydedilirken
/// dondurulan [Tx.baseAmount] ile ₺ toplamına girer — kullanıcı iki kartı tek
/// rakamda görmek istiyor. Eskiden `currency != 'TRY'` atlanıyordu ve döviz
/// harcaması grafiklerde hiç görünmüyordu.
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
    this.incomeBySource = const [],
    this.incomeTotal = 0,
  });

  /// Gelirler kaynağa göre (tutara göre azalan), ana birimde; toplamı
  /// [incomeTotal]. ₼ gelir de aynı kuralla ([Tx.baseOr]) ₺'ye çevrilmiş
  /// hâliyle girer. Gider dökümüne KARIŞMAZ.
  final List<CategoryStat> incomeBySource;
  final double incomeTotal;

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
///
/// [mainCurrency]: tutarların toplanacağı ana para birimi; ekranlar
/// `currencyCodeProvider`'ı geçmeli. Varsayılan [Tx.legacyMainCode] —
/// parametre vermeyen eski çağıranlar bugünkü ₺ sonucunu almaya devam eder
/// (ana cüzdan kayıtları zaten o kodla yazılı), üstüne dondurulmuş
/// `baseAmount` taşıyan döviz işlemleri de toplama girer.
MonthAnalytics analyzeMonth(
  List<Tx> txs,
  DateTime month, {
  String? categoryId,
  required Map<String, Envelope> envelopes,
  required String Function(Envelope) nameOf,
  required String uncategorizedLabel,
  DateTime? now,
  String mainCurrency = Tx.legacyMainCode,
}) {
  final n = now ?? DateTime.now();
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final buckets = List<double>.filled(5, 0);
  final byWeekday = List<double>.filled(8, 0); // 1..7
  final amountBy = <String?, double>{};
  final countBy = <String?, int>{};
  var total = 0.0;
  var count = 0;

  final incomeBy = <String?, double>{};
  final incomeCount = <String?, int>{};
  var incomeTotal = 0.0;

  for (final t in txs) {
    // Döviz çevirme ve hedefe para ayırma gerçek harcama değil — para yer
    // değiştiriyor. Para birimi burada SORULMAZ: döviz işlemi aşağıda
    // [Tx.baseOr] ile ana birime çevrilmiş tutarıyla girer.
    if (t.isConvert || t.isGoalFund) continue;
    if (t.date.year != month.year || t.date.month != month.month) continue;
    // Ana birimdeki tutar: dondurulmuş baseAmount, yoksa kural tx.dart'ta.
    // Çevrilmemiş eski döviz kaydı 0 döner — bugünkü kurla çevirmek
    // geçmişi oynatır; yanlış rakamdansa eksik rakam.
    final amount = t.baseOr(mainCurrency);
    // 0 dönen kayıt adet/kategori listesine de girmesin: "Market · 1 işlem ·
    // ₺0" satırı ve şişmiş "en çok işlem" rozeti yanıltır. Tutarsız kaydı
    // hiç saymamak, yarım saymaktan dürüst.
    if (amount == 0) continue;
    if (t.type == TxType.income) {
      // Gelir ayrı kovada: kaynak etiketi (yoksa "kaynaksız").
      if (categoryId != null) continue;
      incomeTotal += amount;
      incomeBy[t.envelopeId] = (incomeBy[t.envelopeId] ?? 0) + amount;
      incomeCount[t.envelopeId] = (incomeCount[t.envelopeId] ?? 0) + 1;
      continue;
    }
    if (t.type != TxType.expense) continue;
    final id = t.envelopeId;
    if (categoryId != null && (id ?? '') != categoryId) continue;
    total += amount;
    count++;
    buckets[((t.date.day - 1) ~/ 7).clamp(0, 4)] += amount;
    byWeekday[t.date.weekday] += amount;
    amountBy[id] = (amountBy[id] ?? 0) + amount;
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

  final income = <CategoryStat>[
    for (final e in incomeBy.entries)
      CategoryStat(
        envelopeId: e.key,
        name: switch (envelopes[e.key]) {
          final env? => nameOf(env),
          null => uncategorizedLabel,
        },
        emoji: envelopes[e.key]?.emoji ?? '❔',
        count: incomeCount[e.key] ?? 0,
        amount: e.value,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));

  return MonthAnalytics(
    month: month,
    total: total,
    count: count,
    buckets: buckets,
    byCategory: cats,
    incomeBySource: income,
    incomeTotal: incomeTotal,
    busiestWeekday: busiest,
    busiestWeekdayAmount: busiestAmount,
    avgPerDay: daysCounted == 0 ? 0 : total / daysCounted,
    daysCounted: daysCounted,
  );
}
