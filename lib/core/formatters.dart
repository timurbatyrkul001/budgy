import 'package:intl/intl.dart';

import 'l10n.dart';

/// Поддерживаемые валюты: код -> символ.
const kCurrencies = {
  'TRY': '₺',
  'USD': '\$',
  'EUR': '€',
  'RUB': '₽',
  'KZT': '₸',
  'GBP': '£',
};

/// Текущий символ валюты. Обновляется currencySymbolProvider'ом,
/// при смене всё дерево пересобирается (см. app.dart).
var currencySymbol = '₺';

/// Sayı biçimlendirmede kullanılan dil. [moneyLocaleProvider] günceller;
/// değişince tüm ağaç yeniden kurulur (bkz. app.dart).
///
/// Bu olmadan her dilde Rusça biçim ("1 234,5") basılırdı — İngilizce
/// kullanıcı "1,234.5" bekler, Türkçe kullanıcı "1.234,5".
var moneyLocale = 'en';

String _cachedLocale = '';
NumberFormat? _cachedFormat;

NumberFormat get _money {
  if (_cachedFormat == null || _cachedLocale != moneyLocale) {
    _cachedLocale = moneyLocale;
    _cachedFormat = NumberFormat('#,##0.##', moneyLocale);
  }
  return _cachedFormat!;
}

/// 12345.5 -> «12,345.5 ₺» (en) / «12.345,5 ₺» (tr) / «12 345,5 ₺» (ru)
String formatMoney(double amount) =>
    '${_money.format(amount)} $currencySymbol';

/// Belirli para biriminde formatla (zarf bazlı): (1000, 'USD') -> «1,000 $».
String formatMoneyIn(double amount, String currencyCode) {
  final symbol = kCurrencies[currencyCode] ?? currencySymbol;
  return '${_money.format(amount)} $symbol';
}

/// Подменяет ₺ в строках локализации (подсказки полей) на выбранный символ.
String curText(String text) => text.replaceAll('₺', currencySymbol);

/// Компактно для тесных мест (ячейка календаря): 2400 -> «2,4k».
String formatMoneyCompact(double amount) {
  if (amount.abs() >= 1000) {
    final k = amount / 1000;
    return k % 1 == 0 ? '${k.toStringAsFixed(0)}k' : '${k.toStringAsFixed(1)}k';
  }
  return _money.format(amount);
}

/// Заголовок дня в журнале: «4 июня, среда» / "June 4, Wednesday".
String formatDay(DateTime date, Strings str) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return str.today;
  if (day == today.subtract(const Duration(days: 1))) return str.yesterday;
  return DateFormat('d MMMM, EEEE', str.localeCode).format(date);
}

/// Kullanıcı girdisini sayıya çevirir. Klavye dili ve alışkanlık kişiden
/// kişiye değiştiği için üç yazımı da kabul eder:
/// «1 250,50» (ru) · «1.250,50» (tr) · «1,250.50» (en) · «1250.5».
///
/// Kural: iki ayraç da varsa SONUNCUSU ondalıktır, diğeri binlik ayracıdır.
/// Tek ayraç varsa ve arkasında tam 3 hane varsa binlik sayılır («1,250»),
/// aksi halde ondalık («1,5»). Pozitif olmayan değerler `null`.
double? parseAmount(String input) {
  // Boşluk (normal + kesilmeyen), para simgeleri ve harfler temizlenir.
  var s = input.replaceAll(RegExp(r'[\s  ]'), '');
  s = s.replaceAll(RegExp(r'[^\d.,\-]'), '');
  if (s.isEmpty) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');

  String normalized;
  if (lastComma >= 0 && lastDot >= 0) {
    // Her ikisi de var: sondaki ondalık, öteki binlik.
    final decimalSep = lastComma > lastDot ? ',' : '.';
    final groupSep = decimalSep == ',' ? '.' : ',';
    normalized = s.replaceAll(groupSep, '').replaceFirst(decimalSep, '.');
  } else if (lastComma >= 0 || lastDot >= 0) {
    final sep = lastComma >= 0 ? ',' : '.';
    final pos = lastComma >= 0 ? lastComma : lastDot;
    final decimals = s.length - pos - 1;
    final occurrences = sep.allMatches(s).length;
    if (occurrences > 1 || decimals == 3) {
      // «1.234.567» ya da «1,250» → ayraçların hepsi binlik.
      normalized = s.replaceAll(sep, '');
    } else {
      normalized = s.replaceFirst(sep, '.');
    }
  } else {
    normalized = s;
  }

  final value = double.tryParse(normalized);
  if (value == null || value <= 0) return null;
  // Округляем до копеек, чтобы не копить хвосты double.
  return (value * 100).roundToDouble() / 100;
}
