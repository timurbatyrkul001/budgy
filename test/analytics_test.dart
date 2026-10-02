import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/insights/analytics.dart';
import 'package:kopilka_app/features/transactions/tx.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
}

WorkDay _day(int daysAgo, double amount) {
  final d = _daysAgo(daysAgo);
  return WorkDay(
    id: '${d.year}-${d.month}-${d.day}',
    date: d,
    amount: amount,
  );
}

Envelope _env(String id, {double? target, String currency = 'TRY'}) {
  return Envelope(
    id: id,
    name: id,
    emoji: '🍔',
    balance: 0,
    sortOrder: 0,
    currency: currency,
    targetAmount: target,
  );
}

/// [allWorkDaysProvider] ve [envelopesProvider] stream olduğu için
/// testlerde sabit değerlerle override ediliyor.
///
/// Riverpod 3'te bir StreamProvider'a kimse abone olmadan `.future`
/// çözülmez — bu yüzden container kurulur kurulmaz dinleyici bağlanıyor,
/// böylece akış başlar ve ilk değer beklenebilir hale gelir.
Future<ProviderContainer> _container({
  List<WorkDay> workDays = const [],
  List<Envelope> envelopes = const [],
  Map<String, double> spent = const {},
  List<Tx> monthTxs = const [],
  List<Tx> recentTxs = const [],
  String currency = 'TRY',
}) async {
  final container = ProviderContainer(
    overrides: [
      allWorkDaysProvider.overrideWith((ref) => Stream.value(workDays)),
      envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
      currentMonthTxsProvider.overrideWithValue(monthTxs),
      monthlySpentByEnvelopeProvider.overrideWithValue(spent),
      // Tempo artık bütçe dönemini ayarlardan okuyor; testte ayar yok → ay.
      profileProvider.overrideWith((ref) => Stream.value(const {})),
      recentTxsProvider.overrideWith((ref) => Stream.value(recentTxs)),
      // Harcama toplamları ana para birimine çevrilmiş tutarı (`baseOr`)
      // kullanıyor; ana birim ayarlardan gelir, testte sabit.
      currencyProvider.overrideWith((ref) => Stream.value(currency)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(allWorkDaysProvider, (_, _) {}, fireImmediately: true);
  container.listen(envelopesProvider, (_, _) {}, fireImmediately: true);
  container.listen(recentTxsProvider, (_, _) {}, fireImmediately: true);
  container.listen(currencyProvider, (_, _) {}, fireImmediately: true);
  await container.read(allWorkDaysProvider.future);
  await container.read(envelopesProvider.future);
  await container.read(recentTxsProvider.future);
  await container.read(currencyProvider.future);
  return container;
}

void main() {
  group('earningStreakProvider', () {
    test('kazanç yoksa seri 0', () async {
      final c = await _container();
      expect(c.read(earningStreakProvider), 0);
    });

    test('bugün dahil ardışık günleri sayar', () async {
      final c = await _container(workDays: [
        _day(0, 500),
        _day(1, 400),
        _day(2, 300),
      ]);
      expect(c.read(earningStreakProvider), 3);
    });

    test('bugün henüz girilmediyse seri kopmaz, dünden sayar', () async {
      final c = await _container(workDays: [
        _day(1, 400),
        _day(2, 300),
      ]);
      expect(c.read(earningStreakProvider), 2);
    });

    test('araya boş gün girerse seri orada kesilir', () async {
      final c = await _container(workDays: [
        _day(0, 500),
        _day(1, 400),
        // 2 gün önce yok
        _day(3, 300),
      ]);
      expect(c.read(earningStreakProvider), 2);
    });

    test('tutarı 0 olan gün seriye sayılmaz', () async {
      final c = await _container(workDays: [
        _day(0, 0),
        _day(1, 400),
      ]);
      expect(c.read(earningStreakProvider), 1);
    });
  });

  group('earnedTodayProvider', () {
    test('bugün kazanç varsa true', () async {
      final c = await _container(workDays: [_day(0, 100)]);
      expect(c.read(earnedTodayProvider), isTrue);
    });

    test('yalnız dün varsa false', () async {
      final c = await _container(workDays: [_day(1, 100)]);
      expect(c.read(earnedTodayProvider), isFalse);
    });
  });

  group('paceProvider', () {
    test('bütçesiz zarflar listeye girmez', () async {
      final c = await _container(
        envelopes: [_env('a'), _env('b', target: 1000)],
        spent: {'a': 500, 'b': 100},
      );
      final pace = c.read(paceProvider);
      expect(pace.map((p) => p.envelope.id), ['b']);
    });

    test('döviz zarfları tempo hesabına girmez', () async {
      final c = await _container(
        envelopes: [_env('usd', target: 1000, currency: 'USD')],
        spent: {'usd': 100},
      );
      expect(c.read(paceProvider), isEmpty);
    });

    test('ay sonu tahminini mevcut hızdan hesaplar', () async {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final spentSoFar = 100.0 * now.day; // günde 100 ₺

      final c = await _container(
        envelopes: [_env('a', target: 999999)],
        spent: {'a': spentSoFar},
      );
      final pace = c.read(paceProvider).single;

      expect(pace.projected, closeTo(100.0 * daysInMonth, 0.01));
      expect(pace.daysLeft, daysInMonth - now.day);
    });

    test('tempoyla bütçeyi aşacaksa willExceed true', () async {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      // Günde 100 ₺ harcarken bütçe ay sonu tahmininin yarısı kadar.
      final spentSoFar = 100.0 * now.day;
      final budget = 100.0 * daysInMonth / 2;

      final c = await _container(
        envelopes: [_env('a', target: budget)],
        spent: {'a': spentSoFar},
      );
      final pace = c.read(paceProvider).single;

      expect(pace.willExceed, isTrue);
      expect(pace.projectedOver, closeTo(budget, 0.01));
      expect(c.read(overPaceCountProvider), 1);
    });

    test('bütçenin çok altındaysa willExceed false', () async {
      final c = await _container(
        envelopes: [_env('a', target: 1000000)],
        spent: {'a': 10},
      );
      expect(c.read(paceProvider).single.willExceed, isFalse);
      expect(c.read(overPaceCountProvider), 0);
    });
  });

  group('monthlySpentByEnvelopeProvider', () {
    Tx tx({
      required String envelopeId,
      required double amount,
      TxType type = TxType.expense,
      String currency = 'TRY',
      double? baseAmount,
      bool convert = false,
      bool goalFund = false,
      DateTime? date,
    }) {
      return Tx(
        id: 'x',
        type: type,
        amount: amount,
        date: date ?? DateTime.now(),
        envelopeId: envelopeId,
        currency: currency,
        baseAmount: baseAmount,
        baseCurrency: baseAmount == null ? null : 'TRY',
        isConvert: convert,
        isGoalFund: goalFund,
      );
    }

    /// Sağlayıcı ana birimi `currencyProvider`'dan okuyor; akış değer
    /// üretene kadar 'TRY' varsayılır. Testler ana birim 'TRY' ile çalışıyor,
    /// yine de akışı bekliyoruz ki varsayılana değil ayara dayanalım.
    Future<ProviderContainer> container(List<Tx> txs,
        {String currency = 'TRY'}) async {
      final c = ProviderContainer(overrides: [
        currentMonthTxsProvider.overrideWithValue(txs),
        currencyProvider.overrideWith((ref) => Stream.value(currency)),
      ]);
      addTearDown(c.dispose);
      c.listen(currencyProvider, (_, _) {}, fireImmediately: true);
      await c.read(currencyProvider.future);
      return c;
    }

    test('aynı zarfın giderlerini toplar', () async {
      final c = await container([
        tx(envelopeId: 'a', amount: 100),
        tx(envelopeId: 'a', amount: 50),
        tx(envelopeId: 'b', amount: 70),
      ]);
      expect(c.read(monthlySpentByEnvelopeProvider), {'a': 150.0, 'b': 70.0});
    });

    test('gelir, döviz çevrimi ve hedef fonunu hariç tutar', () async {
      final c = await container([
        tx(envelopeId: 'a', amount: 100),
        tx(envelopeId: 'a', amount: 999, type: TxType.income),
        tx(envelopeId: 'a', amount: 999, convert: true),
        tx(envelopeId: 'a', amount: 999, goalFund: true),
      ]);
      expect(c.read(monthlySpentByEnvelopeProvider), {'a': 100.0});
    });

    test('baseAmount dolu ₼ işlemi çevrilmiş tutarıyla toplama girer',
        () async {
      // 50 ₼, kayıt günü kuruyla 98,50 ₺ olarak dondurulmuş.
      final c = await container([
        tx(envelopeId: 'a', amount: 50, currency: 'AZN', baseAmount: 98.5),
      ]);
      expect(c.read(monthlySpentByEnvelopeProvider), {'a': 98.5});
    });

    test('baseAmount null olan eski ₼ kaydı toplama girmez (0 sayılır)',
        () async {
      // Çevrilmemiş eski döviz kaydı: kuru yok. Bugünkü kurla çevirmek
      // geçmişi oynatır, ham ₼'yi ₺ gibi toplamak düpedüz yanlış olur —
      // bu yüzden bilinçli olarak 0. Zarf yine de haritada görünür (0 ile),
      // çünkü işlem var ama tutarı güvenilir değil.
      final c = await container([
        tx(envelopeId: 'a', amount: 100),
        tx(envelopeId: 'a', amount: 999, currency: 'AZN'),
      ]);
      expect(c.read(monthlySpentByEnvelopeProvider), {'a': 100.0});
    });

    test('ana birimdeki işlem baseAmount olmasa da girer', () async {
      // Eski ₺ kayıtlarında baseAmount yok; ana birim zaten ₺ → amount.
      final c = await container([
        tx(envelopeId: 'a', amount: 250),
      ]);
      expect(c.read(monthlySpentByEnvelopeProvider), {'a': 250.0});
    });

    test('iki para birimli ay: ₺ + dondurulmuş ₼ tek ₺ rakamında', () async {
      final c = await container([
        tx(envelopeId: 'market', amount: 1000), // ₺, eski kayıt
        tx(envelopeId: 'market', amount: 40, currency: 'AZN', baseAmount: 78.8),
        tx(envelopeId: 'kafe', amount: 10, currency: 'AZN', baseAmount: 19.7),
        tx(envelopeId: 'kafe', amount: 5, currency: 'AZN'), // kursuz, eski
      ]);
      expect(c.read(monthlySpentByEnvelopeProvider),
          {'market': 1078.8, 'kafe': 19.7});
    });
  });

  group('monthComparisonProvider', () {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1, 12);
    final lastMonth = DateTime(now.year, now.month - 1, 1, 12);

    Tx tx(
      DateTime date, {
      required String envelopeId,
      required double amount,
      String currency = 'TRY',
      double? baseAmount,
      bool convert = false,
    }) =>
        Tx(
          id: '${date.month}-$envelopeId-$amount',
          type: TxType.expense,
          amount: amount,
          date: date,
          envelopeId: envelopeId,
          currency: currency,
          baseAmount: baseAmount,
          isConvert: convert,
        );

    test('bu ay vs geçen ay, iki para birimi tek ₺ rakamında', () async {
      final c = await _container(
        envelopes: [_env('a'), _env('b')],
        recentTxs: [
          tx(thisMonth, envelopeId: 'a', amount: 100),
          tx(thisMonth, envelopeId: 'a', amount: 50, currency: 'AZN', baseAmount: 98.5),
          tx(thisMonth, envelopeId: 'a', amount: 999, currency: 'AZN'), // kursuz
          tx(thisMonth, envelopeId: 'a', amount: 999, convert: true),
          tx(lastMonth, envelopeId: 'a', amount: 300),
          tx(lastMonth, envelopeId: 'b', amount: 10, currency: 'AZN', baseAmount: 19.7),
        ],
      );
      final result = {
        for (final d in c.read(monthComparisonProvider))
          d.envelope.id: (d.thisMonth, d.lastMonth),
      };
      expect(result['a'], (198.5, 300.0));
      expect(result['b'], (0.0, 19.7));
    });
  });
}
