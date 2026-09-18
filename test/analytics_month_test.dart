import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/insights/analytics_month.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

/// Analiz ekranının aylık toplulaştırması.
void main() {
  Tx tx(String id, int day, double amount,
          {String? env, TxType type = TxType.expense, String cur = 'TRY',
          bool convert = false}) =>
      Tx(
        id: id,
        type: type,
        amount: amount,
        date: DateTime(2026, 9, day, 12),
        envelopeId: env,
        currency: cur,
        isConvert: convert,
      );

  final envelopes = {
    'm': const Envelope(id: 'm', name: 'Market', emoji: '🛒', balance: 0, sortOrder: 0),
    'u': const Envelope(id: 'u', name: 'Ulaşım', emoji: '🚌', balance: 0, sortOrder: 1),
  };

  MonthAnalytics run(List<Tx> txs, {String? categoryId, DateTime? now}) =>
      analyzeMonth(
        txs,
        DateTime(2026, 9),
        categoryId: categoryId,
        envelopes: envelopes,
        nameOf: (e) => e.name,
        uncategorizedLabel: 'Kategorisiz',
        now: now ?? DateTime(2026, 9, 17),
      );

  final txs = [
    tx('1', 1, 100, env: 'm'), // kova 0, Salı
    tx('2', 7, 50, env: 'u'), // kova 0, Pzt
    tx('3', 8, 200, env: 'm'), // kova 1, Salı
    tx('4', 15, 30, env: 'u'), // kova 2, Salı
    tx('5', 16, 30, env: 'u'), // kova 2, Çrş
    tx('6', 30, 500), // kova 4, Çrş, kategorisiz
    tx('x', 10, 999, type: TxType.income), // gelir sayılmaz
    tx('y', 10, 999, cur: 'USD'), // döviz sayılmaz
    tx('z', 10, 999, convert: true), // çevirme sayılmaz
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
}
