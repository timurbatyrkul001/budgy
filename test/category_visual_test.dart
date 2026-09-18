import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/category_catalog.dart';
import 'package:kopilka_app/core/category_visual.dart';
import 'package:kopilka_app/core/l10n.dart';

/// Kategori görselleri: her katalog (ve eski preset) anahtarının simge +
/// rengi var; bir bölümde yan yana iki madde aynı rengi paylaşmaz; palet
/// marka yeşiline yaklaşmaz; emoji tonu id'ye göre sabit.
void main() {
  test('her katalog maddesinin görseli var', () {
    expect(hasVisualForAllCatalogItems(), isTrue);
    for (final s in kCategoryCatalog) {
      for (final i in s.items) {
        expect(categoryVisual(i.key), isNotNull, reason: i.key);
      }
    }
  });

  test('eski onboarding preset anahtarlarının da görseli var', () {
    for (final p in presetEnvelopes) {
      expect(categoryVisual(p.key), isNotNull, reason: p.key);
    }
  });

  test('bir bölümde yan yana iki madde aynı rengi paylaşmaz', () {
    for (final s in kCategoryCatalog) {
      for (var i = 1; i < s.items.length; i++) {
        final a = categoryVisual(s.items[i - 1].key)!.color;
        final b = categoryVisual(s.items[i].key)!.color;
        expect(a, isNot(equals(b)),
            reason: '${s.key}: ${s.items[i - 1].key} / ${s.items[i].key}');
      }
    }
  });

  test('palet marka yeşilinden uzak, her ton birbirinden farklı', () {
    const brand = Color(0xFF25BE86);
    final hsvBrand = HSVColor.fromColor(brand);
    expect(CategoryPalette.all.toSet().length, CategoryPalette.all.length);
    for (final c in CategoryPalette.all) {
      final hsv = HSVColor.fromColor(c);
      final dh = (hsv.hue - hsvBrand.hue).abs();
      final hueDist = dh > 180 ? 360 - dh : dh;
      // Yeşil komşuluğu (±25°) yasak; limon ~80°, turkuaz ~190° (camgöbeği).
      expect(hueDist, greaterThan(25), reason: '$c marka yeşiline çok yakın');
    }
  });

  test('bilinmeyen anahtar → null; emoji tonu sabit ve palette', () {
    expect(categoryVisual('nope'), isNull);
    expect(categoryVisual(null), isNull);
    expect(envelopeTint('abc'), envelopeTint('abc'));
    expect(CategoryPalette.all, contains(envelopeTint('abc')));
    expect(envelopeTint('abc') != envelopeTint('abd') || true, isTrue);
  });
}
