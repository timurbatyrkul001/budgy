import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('tr');
    await initializeDateFormatting('ru');
  });

  group('parseAmount', () {
    test('düz sayılar', () {
      expect(parseAmount('1250'), 1250);
      expect(parseAmount('1250.5'), 1250.5);
      expect(parseAmount('0.99'), 0.99);
    });

    test('İngilizce biçim: virgül binlik, nokta ondalık', () {
      expect(parseAmount('1,250.50'), 1250.5);
      expect(parseAmount('12,345,678.9'), 12345678.9);
    });

    test('Türkçe biçim: nokta binlik, virgül ondalık', () {
      expect(parseAmount('1.250,50'), 1250.5);
      expect(parseAmount('12.345.678,9'), 12345678.9);
    });

    test('Rusça biçim: boşluk binlik, virgül ondalık', () {
      expect(parseAmount('1 250,50'), 1250.5);
      expect(parseAmount('12 345 678,9'), 12345678.9);
    });

    test('tek ayraç + 3 hane binlik sayılır', () {
      expect(parseAmount('1,250'), 1250);
      expect(parseAmount('1.250'), 1250);
      // Para uygulamasında 3 ondalık hane yazılmaz — binlik okumak doğru.
      expect(parseAmount('1.005'), 1005);
    });

    test('tek ayraç + 1-2 hane ondalık sayılır', () {
      expect(parseAmount('1,5'), 1.5);
      expect(parseAmount('1.5'), 1.5);
      expect(parseAmount('1,05'), 1.05);
    });

    test('kuruşa yuvarlar', () {
      expect(parseAmount('1,2345'), 1.23);
      expect(parseAmount('2,5678'), 2.57);
      expect(parseAmount('1,234.5678'), 1234.57);
    });

    test('geçersiz ve pozitif olmayan girdiler null', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-5'), isNull);
    });

    test('para simgesi ve boşluklar temizlenir', () {
      expect(parseAmount('₺ 1 250'), 1250);
      expect(parseAmount(r'$1,250.50'), 1250.5);
    });
  });

  group('formatMoney dile göre biçimlendirir', () {
    test('en', () {
      moneyLocale = 'en';
      currencySymbol = '\$';
      expect(formatMoney(12345.5), '12,345.5 \$');
    });

    test('tr', () {
      moneyLocale = 'tr';
      currencySymbol = '₺';
      expect(formatMoney(12345.5), '12.345,5 ₺');
    });

    test('ru', () {
      moneyLocale = 'ru';
      currencySymbol = '₽';
      // Rusça binlik ayracı kesilmeyen boşluk (U+00A0).
      expect(formatMoney(12345.5).replaceAll(' ', ' '), '12 345,5 ₽');
    });
  });

  group('formatMoneyIn zarfın para birimini kullanır', () {
    test('bilinen kod', () {
      moneyLocale = 'en';
      currencySymbol = '₺';
      expect(formatMoneyIn(1000, 'USD'), '1,000 \$');
      expect(formatMoneyIn(1000, 'EUR'), '1,000 €');
    });

    test('bilinmeyen kod aktif simgeye düşer', () {
      currencySymbol = '₺';
      expect(formatMoneyIn(1000, 'XXX'), '1,000 ₺');
    });
  });
}
