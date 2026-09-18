import 'formatters.dart';

/// Para biriminin İngilizce adı (özel isim gibi, çevrilmez) ve bayrağı.
const kCurrencyNames = {
  'TRY': 'Turkish Lira',
  'USD': 'US Dollar',
  'EUR': 'Euro',
  'RUB': 'Russian Ruble',
  'KZT': 'Kazakhstani Tenge',
  'GBP': 'British Pound',
};

const kCurrencyFlags = {
  'TRY': '🇹🇷',
  'USD': '🇺🇸',
  'EUR': '🇪🇺',
  'RUB': '🇷🇺',
  'KZT': '🇰🇿',
  'GBP': '🇬🇧',
};

String currencyName(String code) => kCurrencyNames[code] ?? code;
String currencyFlag(String code) => kCurrencyFlags[code] ?? '🏳️';

const _euroZone = {
  'DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'GR', 'SK', //
  'SI', 'LT', 'LV', 'EE', 'LU', 'MT', 'CY', 'HR',
};

/// Cihaz bölgesinden (ülke kodu) desteklenen bir para birimi. Bilinmiyorsa
/// ya da desteklenmiyorsa USD.
String currencyForRegion(String? countryCode) {
  final cc = countryCode?.toUpperCase();
  final code = switch (cc) {
    'TR' => 'TRY',
    'KZ' => 'KZT',
    'RU' => 'RUB',
    'GB' => 'GBP',
    _ when _euroZone.contains(cc) => 'EUR',
    _ => 'USD',
  };
  return kCurrencies.containsKey(code) ? code : 'USD';
}
