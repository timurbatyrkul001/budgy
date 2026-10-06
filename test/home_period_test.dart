import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/category_visual.dart';
import 'package:kopilka_app/features/envelopes/home_period.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

Tx _tx(
  String id,
  TxType type,
  double amount,
  DateTime date, {
  bool convert = false,
  bool goal = false,
  String? groupId,
  String currency = 'TRY',
  double? base,
}) => Tx(
  id: id,
  type: type,
  amount: amount,
  date: date,
  isConvert: convert,
  isGoalFund: goal,
  groupId: groupId,
  currency: currency,
  baseAmount: base,
);

void main() {
  group('buildOverview', () {
    final now = DateTime(2026, 10, 10, 12);
    final txs = [
      _tx('i1', TxType.income, 10000, DateTime(2026, 10, 1)),
      _tx('e1', TxType.expense, 1000, DateTime(2026, 10, 2)),
      _tx('e2', TxType.expense, 3000, DateTime(2026, 10, 9)),
      // Döviz kartı: dondurulmuş kurla ana birime girer.
      _tx(
        'e3',
        TxType.expense,
        100,
        DateTime(2026, 10, 9),
        currency: 'USD',
        base: 4000,
      ),
      // Çevirme ve hedef fonu gelir/gider değil.
      _tx('c1', TxType.expense, 500, DateTime(2026, 10, 3), convert: true),
      _tx('g1', TxType.expense, 700, DateTime(2026, 10, 3), goal: true),
      // Geçen ay: 10'una kadar 5000, ayın tamamı 9000.
      _tx('p1', TxType.expense, 5000, DateTime(2026, 9, 5)),
      _tx('p2', TxType.expense, 4000, DateTime(2026, 9, 20)),
    ];

    test('gelir, gider, net ve birikim oranı ana birimde', () {
      final o = buildOverview(
        txs,
        month: DateTime(2026, 10),
        main: 'TRY',
        now: now,
      );
      expect(o.income, 10000);
      expect(o.expense, 8000);
      expect(o.net, 2000);
      expect(o.savedRate, closeTo(0.2, 1e-9));
      expect(o.daysCounted, 10);
      expect(o.cumulative.length, 10);
      expect(o.largest?.id, 'e3');
      expect(o.avgPerDay, 800);
    });

    test('eğilim önceki ayın AYNI GÜNÜYLE kıyaslanır', () {
      final o = buildOverview(
        txs,
        month: DateTime(2026, 10),
        main: 'TRY',
        now: now,
      );
      // 8000 vs 5000 (Eylül 10'una kadar) → +%60, ayın tamamı (9000) değil.
      expect(o.trend, closeTo(0.6, 1e-9));
    });

    test('geçmiş ay tam sayılır; gelir yoksa oran null', () {
      final o = buildOverview(
        txs,
        month: DateTime(2026, 9),
        main: 'TRY',
        now: now,
      );
      expect(o.daysCounted, 30);
      expect(o.expense, 9000);
      expect(o.savedRate, isNull);
    });

    test('pencere dışındaki önceki ay: kıyas yok', () {
      final o = buildOverview(
        txs,
        month: DateTime(2026, 10),
        main: 'TRY',
        now: now,
        hasPrev: false,
      );
      expect(o.prevCumulative, isNull);
      expect(o.trend, isNull);
    });
  });

  group('groupRecent', () {
    test('günlere böler, çevirme bacaklarını tek satır yapar', () {
      final txs = [
        _tx('a', TxType.expense, 50, DateTime(2026, 10, 6, 10)),
        _tx(
          'cin',
          TxType.income,
          10,
          DateTime(2026, 10, 6, 9),
          convert: true,
          groupId: 'g',
          currency: 'USD',
        ),
        _tx(
          'cout',
          TxType.expense,
          400,
          DateTime(2026, 10, 6, 9),
          convert: true,
          groupId: 'g',
        ),
        _tx('b', TxType.income, 1000, DateTime(2026, 10, 5)),
        _tx('goal', TxType.expense, 99, DateTime(2026, 10, 5), goal: true),
      ];
      final days = groupRecent(txs, main: 'TRY');
      expect(days.length, 2);
      expect(days[0].entries.length, 2);
      final pair = days[0].entries[1];
      expect(pair.isConvertPair, isTrue);
      expect(pair.tx.id, 'cout');
      expect(pair.into?.id, 'cin');
      // Çevirme günün net akışına girmez.
      expect(days[0].net, -50);
      // Hedef fonu listelenmez.
      expect(days[1].entries.map((e) => e.tx.id), ['b']);
      expect(days[1].net, 1000);
    });

    test('maxEntries sınırı', () {
      final txs = [
        for (var i = 0; i < 20; i++)
          _tx('t$i', TxType.expense, 1, DateTime(2026, 10, 6)),
      ];
      final days = groupRecent(txs, main: 'TRY', maxEntries: 8);
      expect(days.single.entries.length, 8);
    });
  });

  group('catalogKeyForName', () {
    test('katalog adının öneki ve tam adı', () {
      expect(catalogKeyForName('Fatura'), 'utilities');
      expect(catalogKeyForName('Kira'), 'rent');
      expect(catalogKeyForName('Продукты'), 'groceries');
    });

    test('anahtar kelime kuralı', () {
      expect(catalogKeyForName('Netflix'), 'streaming');
    });

    test('kısa ya da bilinmeyen ad tahmin edilmez', () {
      expect(catalogKeyForName('Xq'), isNull);
      expect(catalogKeyForName('Zzzzz'), isNull);
    });
  });
}
