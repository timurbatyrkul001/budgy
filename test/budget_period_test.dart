import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/budget/auto_split.dart';
import 'package:kopilka_app/features/budget/budget_period.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

/// Bütçe dönemi penceresi, eski ayarın taşınması, öneri dağılımı.
void main() {
  group('periodWindow', () {
    test('aylık: takvim ayı [1, sonraki ayın 1\'i)', () {
      final w = periodWindow(DateTime(2026, 9, 17, 14), BudgetPeriod.monthly);
      expect(w.start, DateTime(2026, 9, 1));
      expect(w.end, DateTime(2026, 10, 1));
      expect(w.totalDays, 30);
      expect(w.daysLeft(DateTime(2026, 9, 17)), 14);
      expect(w.daysElapsed(DateTime(2026, 9, 17)), 17);
      expect(w.contains(DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(w.contains(DateTime(2026, 10, 1)), isFalse);
    });

    test('aylık: aralık → ocak yıl atlar', () {
      final w = periodWindow(DateTime(2026, 12, 5), BudgetPeriod.monthly);
      expect(w.end, DateTime(2027, 1, 1));
      expect(w.totalDays, 31);
    });

    test('haftalık: Pazartesi başlangıç (17 Eylül 2026 Perşembe)', () {
      final w = periodWindow(DateTime(2026, 9, 17), BudgetPeriod.weekly);
      expect(w.start, DateTime(2026, 9, 14)); // Pzt
      expect(w.end, DateTime(2026, 9, 21));
      expect(w.totalDays, 7);
      expect(w.daysLeft(DateTime(2026, 9, 17)), 4);
      expect(w.daysElapsed(DateTime(2026, 9, 17)), 4);
    });

    test('haftalık: başlangıç günü Pazar ise pencere Pazar\'dan başlar', () {
      final w = periodWindow(DateTime(2026, 9, 17), BudgetPeriod.weekly,
          weekStart: DateTime.sunday);
      expect(w.start, DateTime(2026, 9, 13));
      expect(w.end, DateTime(2026, 9, 20));
    });

    test('haftalık: bugün başlangıç günüyse pencere bugün başlar', () {
      final w = periodWindow(DateTime(2026, 9, 17), BudgetPeriod.weekly,
          weekStart: DateTime.thursday);
      expect(w.start, DateTime(2026, 9, 17));
      expect(w.daysLeft(DateTime(2026, 9, 17)), 7);
    });

    test('haftalık: ay sınırını aşar', () {
      final w = periodWindow(DateTime(2026, 10, 1), BudgetPeriod.weekly);
      expect(w.start, DateTime(2026, 9, 28));
      expect(w.contains(DateTime(2026, 9, 30)), isTrue);
    });
  });

  group('BudgetSettings.fromProfile (göç)', () {
    test('yeni alanlar önce gelir', () {
      final s = BudgetSettings.fromProfile({
        'budgetAmount': 3000,
        'budgetPeriod': 'weekly',
        'budgetWeekStart': 6,
        'monthlyBudget': 15000,
      })!;
      expect(s.amount, 3000);
      expect(s.period, BudgetPeriod.weekly);
      expect(s.weekStart, DateTime.saturday);
    });

    test('eski monthlyBudget aylık bütçe olarak okunur', () {
      final s = BudgetSettings.fromProfile({'monthlyBudget': 15000})!;
      expect(s.amount, 15000);
      expect(s.period, BudgetPeriod.monthly);
      expect(s.weekStart, DateTime.monday);
    });

    test('hiçbiri yoksa null; 0 ve null tutar yok sayılır', () {
      expect(BudgetSettings.fromProfile(const {}), isNull);
      expect(BudgetSettings.fromProfile({'monthlyBudget': 0}), isNull);
      expect(BudgetSettings.fromProfile({'budgetAmount': null}), isNull);
    });

    test('toProfile eski alanı temizler', () {
      final m = const BudgetSettings(
              amount: 500, period: BudgetPeriod.weekly, weekStart: 2)
          .toProfile();
      expect(m['budgetAmount'], 500);
      expect(m['budgetPeriod'], 'weekly');
      expect(m['budgetWeekStart'], 2);
      expect(m.containsKey('monthlyBudget'), isTrue);
      expect(m['monthlyBudget'], isNull);
    });
  });

  group('autoSplit', () {
    test('paylara göre böler, toplam korunur, 10\'a yuvarlar', () {
      final r = autoSplit(total: 10000, history: {'a': 600, 'b': 300, 'c': 100});
      expect(r['a'], 6000);
      expect(r['b'], 3000);
      expect(r['c'], 1000);
      expect(r.values.fold<double>(0, (x, y) => x + y), 10000);
    });

    test('yuvarlama artığı en büyük kategoriye gider', () {
      final r = autoSplit(total: 1000, history: {'a': 1, 'b': 1, 'c': 1});
      // 333.3 → 330 ×3 = 990; artık 10 → a.
      expect(r['a'], 340);
      expect(r['b'], 330);
      expect(r['c'], 330);
      expect(r.values.fold<double>(0, (x, y) => x + y), 1000);
    });

    test('geçmiş yoksa boş', () {
      expect(autoSplit(total: 1000, history: const {}), isEmpty);
      expect(autoSplit(total: 1000, history: {'a': 0}), isEmpty);
    });

    test('küçük toplamda 1\'e yuvarlar', () {
      final r = autoSplit(total: 100, history: {'a': 2, 'b': 1});
      expect(r['a'], 67);
      expect(r['b'], 33);
    });
  });

  group('son N gün toplamları', () {
    Tx tx(int daysAgo, double amount, {String? env}) => Tx(
          id: '$daysAgo-$amount',
          type: TxType.expense,
          amount: amount,
          date: DateTime(2026, 9, 17).subtract(Duration(days: daysAgo)),
          envelopeId: env,
        );
    final now = DateTime(2026, 9, 17, 10);

    test('totalInLastDays bugün dahil N gün', () {
      final txs = [tx(0, 10), tx(6, 20), tx(7, 40), tx(29, 80), tx(30, 160)];
      expect(totalInLastDays(txs, 7, now: now), 30);
      expect(totalInLastDays(txs, 30, now: now), 150);
    });

    test('spentInLastDays zarf bazında, kategorisiz hariç', () {
      final txs = [tx(1, 10, env: 'a'), tx(2, 5, env: 'a'), tx(3, 7), tx(70, 9, env: 'b')];
      expect(spentInLastDays(txs, 60, now: now), {'a': 15});
    });
  });
}
