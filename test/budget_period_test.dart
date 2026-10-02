import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/budget/auto_split.dart';
import 'package:kopilka_app/features/budget/budget_period.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
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
    Tx tx(int daysAgo, double amount,
            {String? env,
            String currency = 'TRY',
            double? baseAmount,
            String? accountId,
            bool convert = false,
            bool goalFund = false}) =>
        Tx(
          id: '$daysAgo-$amount-$currency-${accountId ?? ''}',
          type: TxType.expense,
          amount: amount,
          date: DateTime(2026, 9, 17).subtract(Duration(days: daysAgo)),
          envelopeId: env,
          currency: currency,
          baseAmount: baseAmount,
          accountId: accountId,
          isConvert: convert,
          isGoalFund: goalFund,
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

    test('döviz çevirme ve hedef fonu harcama sayılmaz', () {
      final txs = [tx(0, 10), tx(1, 999, convert: true), tx(2, 999, goalFund: true)];
      expect(totalInLastDays(txs, 7, now: now), 10);
    });

    test('iki para birimi: ₺ + dondurulmuş ₼ tek rakamda, kursuz ₼ sayılmaz',
        () {
      final txs = [
        tx(0, 100, env: 'a'), // ₺, eski kayıt (baseAmount yok) → amount
        tx(1, 50, env: 'a', currency: 'AZN', baseAmount: 98.5), // → 98,5 ₺
        tx(2, 999, env: 'a', currency: 'AZN'), // çevrilmemiş eski kayıt → 0
      ];
      // Varsayılan ana birim 'TRY' (ana cüzdanın iç kodu).
      expect(totalInLastDays(txs, 7, now: now), 198.5);
      expect(spentInLastDays(txs, 7, now: now), {'a': 198.5});
      // Ana birim açıkça verilince de aynı: baseAmount zaten o birimde.
      expect(totalInLastDays(txs, 7, now: now, mainCurrency: 'TRY'), 198.5);
    });

    test('ana birimi ₼ olan kullanıcıda eski kayıtlar yine de sayılır', () {
      // Hesaplar gelmeden önce yazılan kayıtlarda `currency` alanı, kullanıcı
      // hangi birimi seçmiş olursa olsun sabit 'TRY' idi — "ana birim"
      // anlamında bir iç kod. `accountId` yokluğu bu kayıtların işareti.
      // Bunları yabancı para sanıp sıfırlasaydık, ana birimini ₼ yapmış bir
      // kullanıcının BÜTÜN geçmişi silinmiş görünürdü.
      final legacy = tx(0, 100, env: 'a');
      // Gerçekten yabancı: hesabı var, birimi ana birimden farklı, kuru yok.
      final foreign = tx(1, 50, env: 'a', accountId: 'tr-card');
      expect(
        totalInLastDays([legacy, foreign], 7, now: now, mainCurrency: 'AZN'),
        100,
      );
      // Ana birim 'TRY' olduğunda ikisi de sayılır.
      expect(
        totalInLastDays([legacy, foreign], 7, now: now, mainCurrency: 'TRY'),
        150,
      );
    });
  });

  group('periodSpentProvider', () {
    /// Ayar yok → takvim ayı; ana birim ayarlardan (`currencyProvider`).
    Future<ProviderContainer> container(List<Tx> txs) async {
      final c = ProviderContainer(overrides: [
        profileProvider.overrideWith((ref) => Stream.value(const {})),
        recentTxsProvider.overrideWith((ref) => Stream.value(txs)),
        currencyProvider.overrideWith((ref) => Stream.value('TRY')),
      ]);
      addTearDown(c.dispose);
      c.listen(recentTxsProvider, (_, _) {}, fireImmediately: true);
      c.listen(currencyProvider, (_, _) {}, fireImmediately: true);
      await c.read(recentTxsProvider.future);
      await c.read(currencyProvider.future);
      return c;
    }

    Tx tx(double amount, {String currency = 'TRY', double? baseAmount}) => Tx(
          id: '$amount-$currency',
          type: TxType.expense,
          amount: amount,
          date: DateTime.now(),
          currency: currency,
          baseAmount: baseAmount,
        );

    test('dönem toplamı iki para birimini ana birimde birleştirir', () async {
      final c = await container([
        tx(1000), // ₺
        tx(40, currency: 'AZN', baseAmount: 78.8), // dondurulmuş
        tx(5, currency: 'AZN'), // kursuz eski kayıt → 0
      ]);
      expect(c.read(periodSpentProvider), 1078.8);
    });
  });
}
