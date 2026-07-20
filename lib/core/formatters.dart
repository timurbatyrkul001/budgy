import 'package:intl/intl.dart';

import 'l10n.dart';

final _money = NumberFormat('#,##0.##', 'ru_RU');

/// Поддерживаемые валюты: код -> символ.
const kCurrencies = {
  'TRY': '₺',
  'USD': '\$',
  'EUR': '€',
  'RUB': '₽',
};

/// Текущий символ валюты. Обновляется currencySymbolProvider'ом,
/// при смене всё дерево пересобирается (см. app.dart).
var currencySymbol = '₺';

/// 12 345.5 -> «12 345,5 ₺»
String formatMoney(double amount) =>
    '${_money.format(amount)} $currencySymbol';

/// Belirli para biriminde formatla (zarf bazlı): (1000, 'USD') -> «1 000 $».
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

/// Парсит ввод пользователя: «1 250,50» / «1250.5» -> 1250.5
double? parseAmount(String input) {
  final cleaned = input.replaceAll(' ', '').replaceAll(',', '.');
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  // Округляем до копеек, чтобы не копить хвосты double.
  return (value * 100).roundToDouble() / 100;
}
