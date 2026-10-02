import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/features/accounts/bank_catalog.dart';

/// Banka kataloğu: her markanın yazısı KENDİ zeminine göre okunur (≥ 4.5:1),
/// stil-zemin tutarlı, anahtarlar benzersiz, para birimi ülkesiyle tutarlı,
/// ülke süzgeci doğru.
void main() {
  test('her markanın yazı rengi kendi zeminine göre en az 4.5:1 verir', () {
    for (final b in kBankCatalog) {
      // Açık zeminde mürekkep, koyuda beyaz — zemin de stile göre (ribbon'da
      // yazı şeritte değil beyaz kâğıtta).
      expect(b.ink, b.isLight ? Ex.text : Colors.white, reason: b.key);
      expect(
        b.contrastWithInk,
        greaterThanOrEqualTo(4.5),
        reason: '${b.key} (${b.ground} / ${b.ink}) → '
            '${b.contrastWithInk.toStringAsFixed(2)}:1',
      );
    }
  });

  test('split kartlarda ikinci ton da mürekkeple okunur', () {
    // Temassız simgesi ve para birimi rozeti ikinci tonun üstüne düşüyor.
    for (final b in kBankCatalog.where((b) => b.style == CardStyle.split)) {
      expect(b.accents.length, 1, reason: '${b.key}: split tek ikinci ton');
      expect(
        BankBrand.contrastBetween(b.accents.first, b.ink),
        greaterThanOrEqualTo(4.5),
        reason: '${b.key} ikinci ton ${b.accents.first}',
      );
    }
  });

  test('her stil en az bir bankada kullanılıyor', () {
    final used = kBankCatalog.map((b) => b.style).toSet();
    for (final s in CardStyle.values) {
      expect(used, contains(s), reason: s.name);
    }
  });

  test('stil ile zemin tutarlı', () {
    for (final b in kBankCatalog) {
      switch (b.style) {
        case CardStyle.metal:
          // Altın/gümüş açık zemin: mürekkep yazı.
          expect(b.isLight, isTrue, reason: '${b.key}: metal açık zemin');
        case CardStyle.ribbon:
          expect(b.isLight, isTrue, reason: '${b.key}: ribbon açık zemin');
          // Şeritte geçiş için en az iki renk.
          expect(b.accents.length, greaterThanOrEqualTo(2), reason: b.key);
          expect(b.ground, Ex.surface, reason: '${b.key}: beyaz kâğıt');
        case CardStyle.split:
        case CardStyle.flat:
          expect(b.ground, b.color, reason: b.key);
      }
    }
  });

  test('bilinen karakterler: Kaspi altın metal, Enpara beyaz şerit, '
      'Papara siyah split, T-Bank siyah flat, Birbank siyah-kırmızı split', () {
    final kaspi = bankByKey('kaspi')!;
    expect(kaspi.style, CardStyle.metal);
    expect(kaspi.isLight, isTrue);
    // Altın: kırmızı > yeşil > mavi, sıcak.
    expect(kaspi.color.r, greaterThan(kaspi.color.g));
    expect(kaspi.color.g, greaterThan(kaspi.color.b));

    final enpara = bankByKey('enpara')!;
    expect(enpara.style, CardStyle.ribbon);
    expect(enpara.accents, hasLength(3));

    final papara = bankByKey('papara')!;
    expect(papara.style, CardStyle.split);
    expect(papara.isLight, isFalse);
    // 2023 kimliği siyah-beyaz: zemin siyah, ikinci ton da nötr (doygun
    // değil) — eski mor geri sızmasın.
    expect(papara.color.computeLuminance(), lessThan(0.02), reason: 'siyah');
    final graphite = papara.accents.single;
    expect((graphite.r - graphite.b).abs(), lessThan(0.05), reason: 'nötr');
    expect((graphite.r - graphite.g).abs(), lessThan(0.05), reason: 'nötr');

    final tbank = bankByKey('tbank')!;
    expect(tbank.style, CardStyle.flat);
    expect(tbank.color.computeLuminance(), lessThan(0.02), reason: 'siyah');

    final birbank = bankByKey('birbank')!;
    expect(birbank.style, CardStyle.split);
    expect(birbank.color.computeLuminance(), lessThan(0.02), reason: 'siyah');
    final red = birbank.accents.single;
    expect(red.r, greaterThan(0.6));
    expect(red.g, lessThan(0.2));
  });

  test('yeni alanların varsayılanı var: eski imzayla kurulan marka flat/koyu',
      () {
    // account_editor_sheet "Diğer banka"yı eski imzayla kuruyor.
    const b = BankBrand(
      key: 'x',
      name: 'X',
      color: Color(0xFF333333),
      country: '',
      currency: 'TRY',
    );
    expect(b.style, CardStyle.flat);
    expect(b.surface, Brightness.dark);
    expect(b.accents, isEmpty);
    expect(b.ink, Colors.white);
  });

  test('copyWith stil/vurgu override taşır, diğer alanları korur', () {
    final z = bankByKey('ziraat')!;
    final c = z.copyWith(style: CardStyle.metal, accents: const [Colors.red]);
    expect(c.style, CardStyle.metal);
    expect(c.accents, [Colors.red]);
    expect(c.key, z.key);
    expect(c.color, z.color);
    expect(c.surface, z.surface);
    // Parametresiz kopya her şeyi aynen taşır (ribbon paleti dahil).
    final e = bankByKey('enpara')!.copyWith(country: 'TR');
    expect(e.style, CardStyle.ribbon);
    expect(e.accents, bankByKey('enpara')!.accents);
    expect(e.surface, Brightness.light);
  });

  test('CardStyle.name ↔ cardStyleFromName gidip gelir', () {
    for (final s in CardStyle.values) {
      expect(cardStyleFromName(s.name), s);
    }
    expect(cardStyleFromName(null), isNull);
    expect(cardStyleFromName(''), isNull);
    expect(cardStyleFromName('hologram'), isNull);
  });

  test('contrastBetween simetrik ve WCAG uçlarını verir', () {
    expect(BankBrand.contrastBetween(Colors.black, Colors.white),
        moreOrLessEquals(21, epsilon: 0.01));
    expect(BankBrand.contrastBetween(Colors.white, Colors.black),
        moreOrLessEquals(21, epsilon: 0.01));
    expect(BankBrand.contrastBetween(Colors.white, Colors.white), 1.0);
  });

  test('anahtarlar benzersiz ve boş değil', () {
    final keys = kBankCatalog.map((b) => b.key).toList();
    expect(keys.toSet().length, keys.length);
    for (final k in keys) {
      expect(k, isNotEmpty);
      expect(k, equals(k.toLowerCase()), reason: 'anahtar küçük harf: $k');
    }
  });

  test('aynı ülkede iki banka aynı rengi paylaşmaz', () {
    // Kart rengi tanıma aracı: seçicide yan yana duran iki kart aynı
    // renkse kullanıcı ayıramaz. Genel kayıtlar (Diğer/Nakit) her ülkede
    // görünür, onlar da hiçbir bankayla çakışmasın.
    for (final c in kBankCountries) {
      final seen = <int, String>{};
      for (final b in banksForCountry(c)) {
        final v = b.color.toARGB32();
        expect(seen.containsKey(v), isFalse,
            reason: '$c: ${b.key} ile ${seen[v]} aynı renk');
        seen[v] = b.key;
      }
    }
  });

  test('her kaydın para birimi ülkesiyle tutarlı', () {
    for (final b in kBankCatalog) {
      if (b.isGeneric) continue;
      expect(kBankCountries, contains(b.country), reason: b.key);
      expect(b.currency, currencyForCountry(b.country), reason: b.key);
    }
  });

  test('istenen markaların hepsi katalogda', () {
    const must = {
      'TR': [
        'enpara', 'garanti', 'isbank', 'yapikredi', 'akbank', 'ziraat',
        'papara', 'denizbank', 'qnb', 'vakifbank', 'teb', 'ing',
      ],
      'AZ': ['kapital', 'pasha', 'birbank', 'abb'],
      'KZ': ['kaspi', 'halyk', 'freedom', 'jusan'],
      'RU': ['tbank', 'sber', 'alfa'],
    };
    for (final e in must.entries) {
      for (final k in e.value) {
        final b = bankByKey(k);
        expect(b, isNotNull, reason: k);
        expect(b!.country, e.key, reason: k);
      }
    }
    expect(bankByKey('other'), isNotNull);
    expect(bankByKey('cash'), isNotNull);
    expect(bankByKey('yok-boyle-banka'), isNull);
  });

  test('banksForCountry yalnız o ülkeyi + genel kayıtları döner', () {
    final az = banksForCountry('AZ');
    final specific = az.where((b) => !['other', 'cash'].contains(b.key));
    expect(specific, isNotEmpty);
    for (final b in specific) {
      expect(b.country, 'AZ', reason: b.key);
      expect(b.currency, 'AZN', reason: b.key);
    }
    // Genel kayıtlar listenin sonunda ve ülkenin para birimine uyarlanmış.
    expect(az[az.length - 2].key, 'other');
    expect(az.last.key, 'cash');
    expect(az.last.currency, 'AZN');
    expect(az[az.length - 2].currency, 'AZN');

    // Küçük harf de kabul; Türkiye'de TRY.
    final tr = banksForCountry('tr');
    expect(tr.first.key, 'enpara');
    expect(tr.every((b) => b.currency == 'TRY'), isTrue);

    // Bilinmeyen ülke: yalnız genel kayıtlar, uygulama varsayılanı TRY.
    final xx = banksForCountry('XX');
    expect(xx.map((b) => b.key), ['other', 'cash']);
    expect(xx.first.currency, 'TRY');
  });

  test('her ülkenin en az bir bankası var', () {
    for (final c in kBankCountries) {
      expect(
        kBankCatalog.where((b) => b.country == c),
        isNotEmpty,
        reason: c,
      );
    }
  });

  test('bankByName hesap adından markayı yakalar', () {
    expect(bankByName('Enpara Maaş')?.key, 'enpara');
    expect(bankByName('garanti kredi kartı')?.key, 'garanti');
    expect(bankByName('Kaspi Gold')?.key, 'kaspi');
    expect(bankByName('Cüzdan')?.key, isNull);
    expect(bankByName('   '), isNull);
  });

  test('genel kayıtların rengi de okunur (çip/liste için)', () {
    // Nakit kart olarak çizilmez ama rengi küçük yerlerde kullanılıyor.
    expect(bankByKey('cash')!.color, isA<Color>());
    expect(bankByKey('other')!.contrastWithWhite, greaterThanOrEqualTo(4.5));
  });
}
