import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/core/fx_freeze.dart';

/// Gerçekçi bir tablo: taban USD, 1 $ = 41 ₺, 1 $ = 1,7 ₼.
/// Buradan 1 ₼ = 41 / 1,7 ≈ 24,1176 ₺ çıkmalı.
final _snap = FxSnapshot(
  base: 'USD',
  rates: const {'TRY': 41.0, 'AZN': 1.7, 'EUR': 0.92},
  fetchedAt: DateTime(2026, 10, 1),
);

void main() {
  group('freezeToBase', () {
    test('aynı birim: kur 1, tutar olduğu gibi', () {
      final r = freezeToBase(amount: 250, from: 'TRY', to: 'TRY', fx: _snap);
      expect(r.rate, 1);
      expect(r.baseAmount, 250);
    });

    test('aynı birimde tabloya hiç bakılmaz (boş tablo bile olsa)', () {
      final empty = FxSnapshot(
        base: 'USD',
        rates: const {},
        fetchedAt: DateTime(2026, 10, 1),
      );
      final r = freezeToBase(amount: 10, from: 'AZN', to: 'AZN', fx: empty);
      expect(r.rate, 1);
      expect(r.baseAmount, 10);
    });

    test('çapraz kur: ikisi de tabandan farklı (AZN → TRY)', () {
      final r = freezeToBase(amount: 100, from: 'AZN', to: 'TRY', fx: _snap);
      // 1 ₼ = 41 / 1,7 ₺
      expect(r.rate, closeTo(41 / 1.7, 1e-12));
      // 100 ₼ = 2411,7647… → kuruşa yuvarlanır
      expect(r.baseAmount, 2411.76);
    });

    test('taban → hedef: doğrudan rates[to]', () {
      final r = freezeToBase(amount: 10, from: 'USD', to: 'TRY', fx: _snap);
      expect(r.rate, 41);
      expect(r.baseAmount, 410);
    });

    test('hedef → taban: 1 / rates[from]', () {
      final r = freezeToBase(amount: 82, from: 'TRY', to: 'USD', fx: _snap);
      expect(r.rate, closeTo(1 / 41, 1e-12));
      expect(r.baseAmount, 2);
    });

    test('kur yoksa FxUnavailable fırlatır, uydurma rakam dönmez', () {
      expect(
        () => freezeToBase(amount: 5, from: 'KZT', to: 'TRY', fx: _snap),
        throwsA(
          isA<FxUnavailable>()
              .having((e) => e.from, 'from', 'KZT')
              .having((e) => e.to, 'to', 'TRY'),
        ),
      );
      expect(
        () => freezeToBase(amount: 5, from: 'TRY', to: 'KZT', fx: _snap),
        throwsA(isA<FxUnavailable>()),
      );
    });

    test('sıfır / geçersiz kur "kur yok" sayılır', () {
      final bad = FxSnapshot(
        base: 'USD',
        rates: const {'TRY': 41.0, 'XXX': 0.0, 'YYY': double.infinity},
        fetchedAt: DateTime(2026, 10, 1),
      );
      expect(
        () => freezeToBase(amount: 1, from: 'XXX', to: 'TRY', fx: bad),
        throwsA(isA<FxUnavailable>()),
      );
      expect(
        () => freezeToBase(amount: 1, from: 'YYY', to: 'TRY', fx: bad),
        throwsA(isA<FxUnavailable>()),
      );
    });

    test('baseAmount kuruşa yuvarlanır, rate ham kalır', () {
      final r = freezeToBase(amount: 1, from: 'AZN', to: 'TRY', fx: _snap);
      expect(r.baseAmount, 24.12); // 24,1176…
      expect(r.rate, isNot(24.12));
      expect(r.rate, closeTo(24.117647, 1e-6));
    });

    test('yuvarlama double kuyruğunu temizler', () {
      // 0.1 + 0.2 türü kuyruk: 3 × 1,1 = 3.3000000000000003
      final tri = FxSnapshot(
        base: 'A',
        rates: const {'B': 1.1},
        fetchedAt: DateTime(2026),
      );
      final r = freezeToBase(amount: 3, from: 'A', to: 'B', fx: tri);
      expect(r.baseAmount, 3.3);
      expect(r.baseAmount.toString(), '3.3');
    });
  });
}
