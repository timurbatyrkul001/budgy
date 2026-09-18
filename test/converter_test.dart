import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/currency_catalog.dart';
import 'package:kopilka_app/core/formatters.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/features/converter/converter_logic.dart';

/// Döviz çevirici mantığı: çevrim, biçim, "güncellendi" etiketi, yıldız
/// sınırı ve çip seçimi, seçici filtresi, satır sınırları, kur önbelleği.
void main() {
  final snap = FxSnapshot(
    base: 'TRY',
    rates: const {'USD': 0.025, 'EUR': 0.02, 'JPY': 3.5, 'KZT': 12.5},
    fetchedAt: DateTime(2026, 9, 17, 10),
  );

  group('convertAmount', () {
    test('ana paradan ve ana paraya', () {
      expect(convertAmount(100, 'TRY', 'USD', snap), 2.5);
      expect(convertAmount(2.5, 'USD', 'TRY', snap), 100);
    });

    test('taban dışı iki para arasında çapraz kur', () {
      // 100 USD = 4000 TRY = 80 EUR.
      expect(convertAmount(100, 'USD', 'EUR', snap), 80);
      expect(convertAmount(80, 'EUR', 'USD', snap), 100);
    });

    test('aynı para, kur yok, bilinmeyen kod', () {
      expect(convertAmount(42, 'USD', 'USD', null), 42);
      expect(convertAmount(42, 'USD', 'EUR', null), isNull);
      expect(convertAmount(42, 'USD', 'ZZZ', snap), isNull);
    });

    test('ondalıksız paralar tam sayıya, diğerleri kuruşa yuvarlar', () {
      expect(convertAmount(1, 'TRY', 'JPY', snap), 4); // 3.5 → 4
      expect(convertAmount(1, 'TRY', 'USD', snap), 0.03); // 0.025 → 0.03
    });
  });

  group('biçim', () {
    setUp(() => moneyLocale = 'en');
    test('ondalıksız / iki ondalık', () {
      expect(formatConverted(4867.2, 'JPY'), '4,867');
      expect(formatConverted(4867.2, 'TRY'), '4,867.20');
      expect(decimalsFor('KRW'), 0);
      expect(decimalsFor('EUR'), 2);
    });
    test('kur biçimi', () {
      expect(formatRate(41.52), '41.52');
      expect(formatRate(540.4), '540.40');
      expect(formatRate(5404.4), '5,404');
    });
    test('priceInMain', () {
      expect(priceInMain(snap, 'USD'), 40);
      expect(priceInMain(snap, 'TRY'), 1);
      expect(priceInMain(null, 'USD'), isNull);
    });
  });

  group('katalog', () {
    test('166 kod, bayraklar ISO çiftinden', () {
      expect(kCurrencyCatalog.length, 166);
      expect(flagFor('TRY'), '🇹🇷');
      expect(flagFor('EUR'), '🇪🇺');
      expect(flagFor('XOF'), '🏳️');
      expect(catalogCurrencyName('KZT'), 'Kazakhstani Tenge');
      expect(isCatalogCurrency('XAU'), isFalse, reason: 'altın yok — kaynak vermiyor');
      expect(isCatalogCurrency('BTC'), isFalse);
    });
    test('kCurrencies dokunulmadı', () {
      expect(kCurrencies.keys, ['TRY', 'USD', 'EUR', 'RUB', 'KZT', 'GBP']);
    });
  });

  group('updatedAgo', () {
    final now = DateTime(2026, 9, 17, 12);
    test('az önce / dakika / saat / gün', () {
      expect(updatedAgo(now.subtract(const Duration(seconds: 30)), now).unit, 'now');
      expect(updatedAgo(now.subtract(const Duration(minutes: 7)), now), (unit: 'minutes', n: 7));
      expect(updatedAgo(now.subtract(const Duration(hours: 4)), now), (unit: 'hours', n: 4));
      expect(updatedAgo(now.subtract(const Duration(days: 3, hours: 2)), now), (unit: 'days', n: 3));
    });
  });

  group('yıldız ve çip', () {
    test('en fazla 2 yıldız; üçüncü reddedilir', () {
      expect(toggleStar(const [], 'USD'), ['USD']);
      expect(toggleStar(const ['USD'], 'EUR'), ['USD', 'EUR']);
      expect(toggleStar(const ['USD', 'EUR'], 'GBP'), isNull);
      expect(toggleStar(const ['USD', 'EUR'], 'USD'), ['EUR']);
    });
    test('çip seçimi: yıldızlılar, yoksa USD (ana USD ise EUR)', () {
      expect(dashboardCurrencies(const [], 'TRY'), ['USD']);
      expect(dashboardCurrencies(const [], 'USD'), ['EUR']);
      expect(dashboardCurrencies(const ['EUR'], 'TRY'), ['EUR']);
      expect(dashboardCurrencies(const ['TRY', 'EUR', 'GBP', 'USD'], 'TRY'), ['EUR', 'GBP']);
    });
  });

  group('satırlar', () {
    test('ekleme sınırı 6, kullanılmayan ilk tercihten', () {
      expect(addRow(const ['TRY', 'USD'], const ['TRY', 'USD', 'KZT']), ['TRY', 'USD', 'KZT']);
      expect(addRow(const ['TRY', 'USD'], const []), ['TRY', 'USD', 'EUR']);
      expect(addRow(const ['A', 'B', 'C', 'D', 'E', 'F'], const []), isNull);
    });
    test('silme: en az 2 kalır', () {
      expect(removeRow(const ['TRY', 'USD', 'EUR'], 1), ['TRY', 'EUR']);
      expect(removeRow(const ['TRY', 'USD'], 0), isNull);
    });
    test('son kullanılanlar 5 ile sınırlı, tekrarsız, en yeni başta', () {
      expect(pushRecent(const ['A', 'B'], 'B'), ['B', 'A']);
      expect(pushRecent(const ['A', 'B', 'C', 'D', 'E'], 'F'), ['F', 'A', 'B', 'C', 'D']);
    });
  });

  group('pickerSections', () {
    test('önerilenler önce, kullanılanlar hariç, A-Z bölümleri', () {
      final s = pickerSections(query: '', exclude: {'USD'}, suggested: ['TRY', 'USD', 'EUR', 'TRY']);
      expect(s.first.label, 'suggested');
      expect(s.first.codes, ['TRY', 'EUR'], reason: 'USD hariç, tekrar yok');
      expect(s[1].label, 'A');
      expect(s.every((sec) => !sec.codes.contains('USD')), isTrue);
      expect(s.any((sec) => sec.codes.contains('TRY') && sec.label != 'suggested'), isFalse);
    });
    test('arama kod ve ada bakar', () {
      final s = pickerSections(query: 'tenge', exclude: const {}, suggested: const []);
      expect(s.single.codes, ['KZT']);
      final byCode = pickerSections(query: 'gbp', exclude: const {}, suggested: const []);
      expect(byCode.single.codes, ['GBP']);
    });
  });

  group('FxCache / loadFxSnapshot', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fxtest');
      FxCache.directoryOverride = dir;
      FxCache.clearMemory();
    });
    tearDown(() async {
      FxCache.directoryOverride = null;
      FxCache.clearMemory();
      await dir.delete(recursive: true);
    });

    test('ağdan alır, diske yazar; tazeyken ağa çıkmaz', () async {
      var calls = 0;
      Future<Map<String, double>?> fetch(String b) async {
        calls++;
        return {'USD': 0.03};
      }
      final now = DateTime(2026, 9, 17, 12);
      final a = await loadFxSnapshot('TRY', now: now, fetch: fetch);
      expect(a!.rates['USD'], 0.03);
      FxCache.clearMemory(); // diskten okumaya zorla
      final b = await loadFxSnapshot('TRY', now: now.add(const Duration(hours: 1)), fetch: fetch);
      expect(b!.fetchedAt, now);
      expect(calls, 1);
    });

    test('bayat + ağ yok → eski önbellek; hiç önbellek yok → null', () async {
      final old = DateTime(2026, 9, 10);
      await FxCache.write(FxSnapshot(base: 'TRY', rates: const {'USD': 0.02}, fetchedAt: old));
      final s = await loadFxSnapshot('TRY', now: DateTime(2026, 9, 17), fetch: (_) async => null);
      expect(s!.fetchedAt, old, reason: 'çevrimdışı: eski tablo + damgası');
      final none = await loadFxSnapshot('EUR', now: DateTime(2026, 9, 17), fetch: (_) async => null);
      expect(none, isNull);
    });
  });
}
