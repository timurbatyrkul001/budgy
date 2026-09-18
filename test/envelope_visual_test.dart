import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/category_visual.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';

/// Tembel göç: bölüm ve renk türetme; kayıtlı değer öndedir; bölüm
/// gruplaması.
void main() {
  Envelope env(String id, {String? preset, String? section, int? color}) => Envelope(
        id: id,
        name: id,
        emoji: '🍔',
        balance: 0,
        sortOrder: 0,
        presetKey: preset,
        section: section,
        colorIndex: color,
      );

  test('katalog zarfı: bölüm ve renk katalogdan türer', () {
    final e = env('a', preset: 'groceries');
    expect(envelopeSection(e), 'everyday');
    expect(envelopeColor(e), categoryVisual('groceries')!.color);
  });

  test('eski preset (food/transport/health/savings) bölüm eşlemesi', () {
    expect(envelopeSection(env('a', preset: 'food')), 'everyday');
    expect(envelopeSection(env('b', preset: 'transport')), 'transport');
    expect(envelopeSection(env('c', preset: 'savings')), 'finance');
    expect(envelopeSection(env('d', preset: 'unknownKey')), isNull);
  });

  test('kullanıcı zarfı: bölümsüz, renk id hash\'inden (ekran kaymaz)', () {
    final e = env('custom-1');
    expect(envelopeSection(e), isNull);
    expect(envelopeColor(e), envelopeTint('custom-1'));
  });

  test('kayıtlı bölüm ve renk her zaman önde', () {
    final e = env('a', preset: 'groceries', section: 'health', color: 5);
    expect(envelopeSection(e), 'health');
    expect(envelopeColor(e), CategoryPalette.all[5]);
    // Geçersiz indeks → türetilmişe düşer.
    expect(envelopeColor(env('b', color: 99)), envelopeTint('b'));
  });

  test('paletteIndexOf', () {
    expect(paletteIndexOf(CategoryPalette.teal), CategoryPalette.all.indexOf(CategoryPalette.teal));
    expect(paletteIndexOf(const Color(0xFF123456)), isNull);
  });

  test('groupBySection: bölümlüler bölümüne, bölümsüzler null altında, sıra korunur', () {
    final g = groupBySection([
      env('x'),
      env('y', section: 'everyday'),
      env('z', preset: 'fuel'),
      env('w', section: 'everyday'),
    ]);
    expect(g[null]!.map((e) => e.id), ['x']);
    expect(g['everyday']!.map((e) => e.id), ['y', 'w']);
    expect(g['transport']!.map((e) => e.id), ['z']);
  });
}
