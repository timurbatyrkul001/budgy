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
}) async {
  final container = ProviderContainer(
    overrides: [
      allWorkDaysProvider.overrideWith((ref) => Stream.value(workDays)),
      envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
      currentMonthTxsProvider.overrideWithValue(monthTxs),
      monthlySpentByEnvelopeProvider.overrideWithValue(spent),
      // Tempo artık bütçe dönemini ayarlardan okuyor; testte ayar yok → ay.
      profileProvider.overrideWith((ref) => Stream.value(const {})),
      recentTxsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  );
  addTearDown(container.dispose);
  container.listen(allWorkDaysProvider, (_, _) {}, fireImmediately: true);
  container.listen(envelopesProvider, (_, _) {}, fireImmediately: true);
  await container.read(allWorkDaysProvider.future);
  await container.read(envelopesProvider.future);
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
      bool convert = false,
      bool goalFund = false,
    }) {
      return Tx(
        id: 'x',
        type: type,
        amount: amount,
        date: DateTime.now(),
        envelopeId: envelopeId,
        currency: currency,
        isConvert: convert,
        isGoalFund: goalFund,
      );
    }

    test('aynı zarfın giderlerini toplar', () {
      final c = ProviderContainer(overrides: [
        currentMonthTxsProvider.overrideWithValue([
          tx(envelopeId: 'a', amount: 100),
          tx(envelopeId: 'a', amount: 50),
          tx(envelopeId: 'b', amount: 70),
        ]),
      ]);
      addTearDown(c.dispose);
      expect(c.read(monthlySpentByEnvelopeProvider), {'a': 150.0, 'b': 70.0});
    });

    test('gelir, döviz çevrimi, hedef fonu ve dövizi hariç tutar', () {
      final c = ProviderContainer(overrides: [
        currentMonthTxsProvider.overrideWithValue([
          tx(envelopeId: 'a', amount: 100),
          tx(envelopeId: 'a', amount: 999, type: TxType.income),
          tx(envelopeId: 'a', amount: 999, convert: true),
          tx(envelopeId: 'a', amount: 999, goalFund: true),
          tx(envelopeId: 'a', amount: 999, currency: 'USD'),
        ]),
      ]);
      addTearDown(c.dispose);
      expect(c.read(monthlySpentByEnvelopeProvider), {'a': 100.0});
    });
  });
}
