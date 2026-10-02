import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/insights/analytics_month.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

/// Analiz ekranının aylık toplulaştırması.
///
/// Para birimi kuralı [Tx.baseOr]'da; burada yalnız o kuralın analize
/// doğru yansıdığı sabitlenir: ₼ harcaması dondurulmuş `baseAmount` ile ₺
/// toplamına girer, çevrilmemiş döviz kaydı ise hiç girmez.
void main() {
  Tx tx(
    String id,
    int day,
    double amount, {
    String? env,
    TxType type = TxType.expense,
    String cur = 'TRY',
    bool convert = false,
    bool goalFund = false,
    String? accountId,
    double? base,
  }) =>
      Tx(
        id: id,
        type: type,
        amount: amount,
        date: DateTime(2026, 9, day, 12),
        envelopeId: env,
        currency: cur,
        isConvert: convert,
        isGoalFund: goalFund,
        accountId: accountId,
        baseAmount: base,
        baseCurrency: base == null ? null : 'TRY',
      );

  final envelopes = {
    'm': const Envelope(id: 'm', name: 'Market', emoji: '🛒', balance: 0, sortOrder: 0),
    'u': const Envelope(id: 'u', name: 'Ulaşım', emoji: '🚌', balance: 0, sortOrder: 1),
    's': const Envelope(id: 's', name: 'Maaş', emoji: '💼', balance: 0, sortOrder: 2,
        presetKey: 'salary'),
  };

  MonthAnalytics run(
    List<Tx> txs, {
    String? categoryId,
    DateTime? now,
    String mainCurrency = 'TRY',
  }) =>
      analyzeMonth(
        txs,
        DateTime(2026, 9),
        categoryId: categoryId,
        envelopes: envelopes,
        nameOf: (e) => e.name,
        uncategorizedLabel: 'Kategorisiz',
        now: now ?? DateTime(2026, 9, 17),
        mainCurrency: mainCurrency,
      );

  final txs = [
    tx('1', 1, 100, env: 'm'), // kova 0, Salı
    tx('2', 7, 50, env: 'u'), // kova 0, Pzt
    tx('3', 8, 200, env: 'm'), // kova 1, Salı
    tx('4', 15, 30, env: 'u'), // kova 2, Salı
    tx('5', 16, 30, env: 'u'), // kova 2, Çrş
    tx('6', 30, 500), // kova 4, Çrş, kategorisiz
    tx('x', 10, 999, type: TxType.income), // gelir gidere karışmaz
    // Çevrilmemiş döviz (baseAmount yok, hesaba bağlı): 0 → sayılmaz.
    tx('y', 10, 999, cur: 'USD', accountId: 'acc-us'),
    tx('z', 10, 999, convert: true), // çevirme sayılmaz
    tx('g', 10, 999, goalFund: true), // hedefe para ayırma sayılmaz
    Tx(id: 'o', type: TxType.expense, amount: 999, date: DateTime(2026, 8, 31)),
  ];

  test('toplam, adet ve hafta kovaları', () {
    final a = run(txs);
    expect(a.total, 910);
    expect(a.count, 6);
    expect(a.buckets, [150, 200, 60, 0, 500]);
    expect(a.isEmpty, isFalse);
  });

  test('kategoriye göre azalan; kategorisiz etiketli', () {
    final a = run(txs);
    expect(a.byCategory.map((c) => c.name), ['Kategorisiz', 'Market', 'Ulaşım']);
    expect(a.topCategory!.name, 'Kategorisiz');
    expect(a.byCategory[1].count, 2);
    expect(a.byCategory[2].amount, 110);
    expect(a.mostPurchases!.name, 'Ulaşım', reason: '3 işlemle en sık');
  });

  test('en yoğun hafta günü ve günlük ortalama', () {
    final a = run(txs);
    // Çarşamba: 30 + 500 = 530 > Salı: 330.
    expect(a.busiestWeekday, DateTime.wednesday);
    expect(a.busiestWeekdayAmount, 530);
    expect(a.daysCounted, 17, reason: 'geçerli ay → bugüne kadar');
    expect(a.avgPerDay, closeTo(910 / 17, 0.001));
  });

  test('geçmiş ay tüm günlere böler', () {
    final a = run(txs, now: DateTime(2026, 10, 3));
    expect(a.daysCounted, 30);
  });

  test('kategori filtresi (id ve kategorisiz \'\')', () {
    expect(run(txs, categoryId: 'm').total, 300);
    expect(run(txs, categoryId: '').total, 500);
    expect(run(txs, categoryId: 'yok').isEmpty, isTrue);
  });

  test('boş ay', () {
    final a = run(const []);
    expect(a.isEmpty, isTrue);
    expect(a.busiestWeekday, isNull);
    expect(a.topCategory, isNull);
    expect(a.buckets, [0, 0, 0, 0, 0]);
  });

  test('kova etiketleri ve geçerli kova', () {
    expect(MonthAnalytics.bucketLabel(0, 30), '1-7');
    expect(MonthAnalytics.bucketLabel(4, 30), '29-30');
    expect(MonthAnalytics.bucketLabel(4, 29), '29');
    expect(MonthAnalytics.currentBucket(DateTime(2026, 9), DateTime(2026, 9, 17)), 2);
    expect(MonthAnalytics.currentBucket(DateTime(2026, 8), DateTime(2026, 9, 17)), isNull);
  });

  test('gelirler kaynağa göre ayrı kovada; gider dökümüne karışmaz', () {
    final a = run([
      tx('1', 1, 100, env: 'm'),
      tx('s1', 2, 4400, env: 's', type: TxType.income),
      tx('s2', 20, 600, env: 's', type: TxType.income),
      tx('g1', 21, 250, type: TxType.income), // kaynaksız
    ]);
    expect(a.total, 100);
    expect(a.byCategory.map((c) => c.envelopeId), ['m']);
    expect(a.incomeTotal, 5250);
    expect(a.incomeBySource.map((c) => c.envelopeId), ['s', null]);
    expect(a.incomeBySource.first.amount, 5000);
    expect(a.incomeBySource.first.count, 2);
    expect(a.incomeBySource.last.name, 'Kategorisiz');
  });

  group('çok para birimi — ana birime çevrilmiş tutarlar', () {
    test('dondurulmuş baseAmount\'lı ₼ gideri kategoriye ₺ olarak girer', () {
      final a = run([
        tx('m1', 3, 100, env: 'm'),
        // 50 ₼, kayıt günü kuruyla 98,50 ₺ dondurulmuş.
        tx('m2', 4, 50, env: 'm', cur: 'AZN', accountId: 'acc-az', base: 98.5),
      ]);
      expect(a.total, 198.5);
      expect(a.count, 2);
      expect(a.byCategory.single.envelopeId, 'm');
      expect(a.byCategory.single.amount, 198.5);
      expect(a.byCategory.single.count, 2);
      expect(a.buckets[0], 198.5);
    });

    test('baseAmount null + accountId dolu ₼ kaydı girmez (0), adet de saymaz', () {
      final a = run([
        tx('m1', 3, 100, env: 'm'),
        tx('m2', 4, 50, env: 'u', cur: 'AZN', accountId: 'acc-az'),
      ]);
      expect(a.total, 100);
      expect(a.count, 1, reason: '0 ₺\'lik kayıt "1 işlem" diye görünmesin');
      expect(a.byCategory.map((c) => c.envelopeId), ['m'],
          reason: 'Ulaşım satırı ₺0 ile listelenmesin');
    });

    test('accountId null + currency TRY eski kayıt ana birim ne olursa olsun girer', () {
      final old = [tx('e1', 5, 300, env: 'm')]; // hesaplar öncesi ana cüzdan
      expect(run(old, mainCurrency: 'TRY').total, 300);
      expect(run(old, mainCurrency: 'USD').total, 300,
          reason: 'ana birimi USD yapan kullanıcının geçmişi sıfırlanmamalı');
      expect(run(old, mainCurrency: 'AZN').byCategory.single.amount, 300);
    });

    test('iki para birimli ay toplamı ve kovalar doğru', () {
      final a = run([
        tx('t1', 1, 100, env: 'm'), // kova 0
        tx('a1', 2, 20, env: 'm', cur: 'AZN', accountId: 'acc-az', base: 39.4),
        tx('t2', 9, 200, env: 'u'), // kova 1
        tx('a2', 10, 10, env: 'u', cur: 'AZN', accountId: 'acc-az', base: 19.7),
        tx('a3', 11, 999, env: 'u', cur: 'AZN', accountId: 'acc-az'), // çevrilmemiş
      ]);
      expect(a.total, closeTo(359.1, 0.001));
      expect(a.count, 4);
      expect(a.buckets[0], closeTo(139.4, 0.001));
      expect(a.buckets[1], closeTo(219.7, 0.001));
      expect(a.byCategory.first.envelopeId, 'u');
      expect(a.byCategory.first.amount, closeTo(219.7, 0.001));
      expect(a.byCategory.last.amount, closeTo(139.4, 0.001));
    });

    test('gelir tarafı aynı kuraldan geçer', () {
      final a = run([
        tx('s1', 2, 4400, env: 's', type: TxType.income),
        // 500 ₼ maaş avansı, 985 ₺ dondurulmuş.
        tx('s2', 20, 500, env: 's', type: TxType.income, cur: 'AZN',
            accountId: 'acc-az', base: 985),
        // Çevrilmemiş ₼ gelir: girmez.
        tx('s3', 21, 300, type: TxType.income, cur: 'AZN', accountId: 'acc-az'),
      ]);
      expect(a.incomeTotal, 5385);
      expect(a.incomeBySource.single.envelopeId, 's');
      expect(a.incomeBySource.single.amount, 5385);
      expect(a.incomeBySource.single.count, 2);
    });

    test('çevirme ve hedef fonu döviz olsa da hariç', () {
      final a = run([
        tx('c', 3, 100, env: 'm', cur: 'AZN', accountId: 'acc-az', base: 197,
            convert: true),
        tx('g', 4, 100, env: 'm', cur: 'AZN', accountId: 'acc-az', base: 197,
            goalFund: true),
      ]);
      expect(a.isEmpty, isTrue);
    });
  });
}
