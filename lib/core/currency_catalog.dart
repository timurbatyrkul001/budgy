import 'package:intl/intl.dart';

import 'formatters.dart';

/// Döviz çevirici kataloğu: kur kaynağımızın (open.er-api.com) gerçekten
/// döndürdüğü 166 itibari para. YALNIZ kur gösterme/çevirme içindir —
/// cüzdan/bakiye için küçük [kCurrencies] seti geçerlidir; katalogdan
/// seçilen bir para asla cüzdan yaratmaz. Altın/gümüş/kripto yok: kaynak
/// vermiyor, uydurma olurdu.
class CatalogCurrency {
  const CatalogCurrency(this.code, this.name);

  final String code;
  final String name;
}

const kCurrencyCatalog = <CatalogCurrency>[
  CatalogCurrency('AED', 'UAE Dirham'),
  CatalogCurrency('AFN', 'Afghan Afghani'),
  CatalogCurrency('ALL', 'Albanian Lek'),
  CatalogCurrency('AMD', 'Armenian Dram'),
  CatalogCurrency('ANG', 'Netherlands Antillean Guilder'),
  CatalogCurrency('AOA', 'Angolan Kwanza'),
  CatalogCurrency('ARS', 'Argentine Peso'),
  CatalogCurrency('AUD', 'Australian Dollar'),
  CatalogCurrency('AWG', 'Aruban Florin'),
  CatalogCurrency('AZN', 'Azerbaijani Manat'),
  CatalogCurrency('BAM', 'Bosnia-Herzegovina Convertible Mark'),
  CatalogCurrency('BBD', 'Barbadian Dollar'),
  CatalogCurrency('BDT', 'Bangladeshi Taka'),
  CatalogCurrency('BGN', 'Bulgarian Lev'),
  CatalogCurrency('BHD', 'Bahraini Dinar'),
  CatalogCurrency('BIF', 'Burundian Franc'),
  CatalogCurrency('BMD', 'Bermudian Dollar'),
  CatalogCurrency('BND', 'Brunei Dollar'),
  CatalogCurrency('BOB', 'Bolivian Boliviano'),
  CatalogCurrency('BRL', 'Brazilian Real'),
  CatalogCurrency('BSD', 'Bahamian Dollar'),
  CatalogCurrency('BTN', 'Bhutanese Ngultrum'),
  CatalogCurrency('BWP', 'Botswana Pula'),
  CatalogCurrency('BYN', 'Belarusian Ruble'),
  CatalogCurrency('BZD', 'Belize Dollar'),
  CatalogCurrency('CAD', 'Canadian Dollar'),
  CatalogCurrency('CDF', 'Congolese Franc'),
  CatalogCurrency('CHF', 'Swiss Franc'),
  CatalogCurrency('CLF', 'Chilean Unit of Account (UF)'),
  CatalogCurrency('CLP', 'Chilean Peso'),
  CatalogCurrency('CNH', 'Chinese Yuan (Offshore)'),
  CatalogCurrency('CNY', 'Chinese Yuan'),
  CatalogCurrency('COP', 'Colombian Peso'),
  CatalogCurrency('CRC', 'Costa Rican Colón'),
  CatalogCurrency('CUP', 'Cuban Peso'),
  CatalogCurrency('CVE', 'Cape Verdean Escudo'),
  CatalogCurrency('CZK', 'Czech Koruna'),
  CatalogCurrency('DJF', 'Djiboutian Franc'),
  CatalogCurrency('DKK', 'Danish Krone'),
  CatalogCurrency('DOP', 'Dominican Peso'),
  CatalogCurrency('DZD', 'Algerian Dinar'),
  CatalogCurrency('EGP', 'Egyptian Pound'),
  CatalogCurrency('ERN', 'Eritrean Nakfa'),
  CatalogCurrency('ETB', 'Ethiopian Birr'),
  CatalogCurrency('EUR', 'Euro'),
  CatalogCurrency('FJD', 'Fijian Dollar'),
  CatalogCurrency('FKP', 'Falkland Islands Pound'),
  CatalogCurrency('FOK', 'Faroese Króna'),
  CatalogCurrency('GBP', 'British Pound'),
  CatalogCurrency('GEL', 'Georgian Lari'),
  CatalogCurrency('GGP', 'Guernsey Pound'),
  CatalogCurrency('GHS', 'Ghanaian Cedi'),
  CatalogCurrency('GIP', 'Gibraltar Pound'),
  CatalogCurrency('GMD', 'Gambian Dalasi'),
  CatalogCurrency('GNF', 'Guinean Franc'),
  CatalogCurrency('GTQ', 'Guatemalan Quetzal'),
  CatalogCurrency('GYD', 'Guyanese Dollar'),
  CatalogCurrency('HKD', 'Hong Kong Dollar'),
  CatalogCurrency('HNL', 'Honduran Lempira'),
  CatalogCurrency('HRK', 'Croatian Kuna'),
  CatalogCurrency('HTG', 'Haitian Gourde'),
  CatalogCurrency('HUF', 'Hungarian Forint'),
  CatalogCurrency('IDR', 'Indonesian Rupiah'),
  CatalogCurrency('ILS', 'Israeli New Shekel'),
  CatalogCurrency('IMP', 'Isle of Man Pound'),
  CatalogCurrency('INR', 'Indian Rupee'),
  CatalogCurrency('IQD', 'Iraqi Dinar'),
  CatalogCurrency('IRR', 'Iranian Rial'),
  CatalogCurrency('ISK', 'Icelandic Króna'),
  CatalogCurrency('JEP', 'Jersey Pound'),
  CatalogCurrency('JMD', 'Jamaican Dollar'),
  CatalogCurrency('JOD', 'Jordanian Dinar'),
  CatalogCurrency('JPY', 'Japanese Yen'),
  CatalogCurrency('KES', 'Kenyan Shilling'),
  CatalogCurrency('KGS', 'Kyrgyzstani Som'),
  CatalogCurrency('KHR', 'Cambodian Riel'),
  CatalogCurrency('KID', 'Kiribati Dollar'),
  CatalogCurrency('KMF', 'Comorian Franc'),
  CatalogCurrency('KRW', 'South Korean Won'),
  CatalogCurrency('KWD', 'Kuwaiti Dinar'),
  CatalogCurrency('KYD', 'Cayman Islands Dollar'),
  CatalogCurrency('KZT', 'Kazakhstani Tenge'),
  CatalogCurrency('LAK', 'Lao Kip'),
  CatalogCurrency('LBP', 'Lebanese Pound'),
  CatalogCurrency('LKR', 'Sri Lankan Rupee'),
  CatalogCurrency('LRD', 'Liberian Dollar'),
  CatalogCurrency('LSL', 'Lesotho Loti'),
  CatalogCurrency('LYD', 'Libyan Dinar'),
  CatalogCurrency('MAD', 'Moroccan Dirham'),
  CatalogCurrency('MDL', 'Moldovan Leu'),
  CatalogCurrency('MGA', 'Malagasy Ariary'),
  CatalogCurrency('MKD', 'Macedonian Denar'),
  CatalogCurrency('MMK', 'Myanmar Kyat'),
  CatalogCurrency('MNT', 'Mongolian Tögrög'),
  CatalogCurrency('MOP', 'Macanese Pataca'),
  CatalogCurrency('MRU', 'Mauritanian Ouguiya'),
  CatalogCurrency('MUR', 'Mauritian Rupee'),
  CatalogCurrency('MVR', 'Maldivian Rufiyaa'),
  CatalogCurrency('MWK', 'Malawian Kwacha'),
  CatalogCurrency('MXN', 'Mexican Peso'),
  CatalogCurrency('MYR', 'Malaysian Ringgit'),
  CatalogCurrency('MZN', 'Mozambican Metical'),
  CatalogCurrency('NAD', 'Namibian Dollar'),
  CatalogCurrency('NGN', 'Nigerian Naira'),
  CatalogCurrency('NIO', 'Nicaraguan Córdoba'),
  CatalogCurrency('NOK', 'Norwegian Krone'),
  CatalogCurrency('NPR', 'Nepalese Rupee'),
  CatalogCurrency('NZD', 'New Zealand Dollar'),
  CatalogCurrency('OMR', 'Omani Rial'),
  CatalogCurrency('PAB', 'Panamanian Balboa'),
  CatalogCurrency('PEN', 'Peruvian Sol'),
  CatalogCurrency('PGK', 'Papua New Guinean Kina'),
  CatalogCurrency('PHP', 'Philippine Peso'),
  CatalogCurrency('PKR', 'Pakistani Rupee'),
  CatalogCurrency('PLN', 'Polish Złoty'),
  CatalogCurrency('PYG', 'Paraguayan Guaraní'),
  CatalogCurrency('QAR', 'Qatari Riyal'),
  CatalogCurrency('RON', 'Romanian Leu'),
  CatalogCurrency('RSD', 'Serbian Dinar'),
  CatalogCurrency('RUB', 'Russian Ruble'),
  CatalogCurrency('RWF', 'Rwandan Franc'),
  CatalogCurrency('SAR', 'Saudi Riyal'),
  CatalogCurrency('SBD', 'Solomon Islands Dollar'),
  CatalogCurrency('SCR', 'Seychellois Rupee'),
  CatalogCurrency('SDG', 'Sudanese Pound'),
  CatalogCurrency('SEK', 'Swedish Krona'),
  CatalogCurrency('SGD', 'Singapore Dollar'),
  CatalogCurrency('SHP', 'Saint Helena Pound'),
  CatalogCurrency('SLE', 'Sierra Leonean Leone'),
  CatalogCurrency('SLL', 'Sierra Leonean Leone (old)'),
  CatalogCurrency('SOS', 'Somali Shilling'),
  CatalogCurrency('SRD', 'Surinamese Dollar'),
  CatalogCurrency('SSP', 'South Sudanese Pound'),
  CatalogCurrency('STN', 'São Tomé and Príncipe Dobra'),
  CatalogCurrency('SYP', 'Syrian Pound'),
  CatalogCurrency('SZL', 'Swazi Lilangeni'),
  CatalogCurrency('THB', 'Thai Baht'),
  CatalogCurrency('TJS', 'Tajikistani Somoni'),
  CatalogCurrency('TMT', 'Turkmenistani Manat'),
  CatalogCurrency('TND', 'Tunisian Dinar'),
  CatalogCurrency('TOP', 'Tongan Paʻanga'),
  CatalogCurrency('TRY', 'Turkish Lira'),
  CatalogCurrency('TTD', 'Trinidad and Tobago Dollar'),
  CatalogCurrency('TVD', 'Tuvaluan Dollar'),
  CatalogCurrency('TWD', 'New Taiwan Dollar'),
  CatalogCurrency('TZS', 'Tanzanian Shilling'),
  CatalogCurrency('UAH', 'Ukrainian Hryvnia'),
  CatalogCurrency('UGX', 'Ugandan Shilling'),
  CatalogCurrency('USD', 'US Dollar'),
  CatalogCurrency('UYU', 'Uruguayan Peso'),
  CatalogCurrency('UZS', 'Uzbekistani Som'),
  CatalogCurrency('VES', 'Venezuelan Bolívar'),
  CatalogCurrency('VND', 'Vietnamese Đồng'),
  CatalogCurrency('VUV', 'Vanuatu Vatu'),
  CatalogCurrency('WST', 'Samoan Tālā'),
  CatalogCurrency('XAF', 'Central African CFA Franc'),
  CatalogCurrency('XCD', 'East Caribbean Dollar'),
  CatalogCurrency('XCG', 'Caribbean Guilder'),
  CatalogCurrency('XDR', 'IMF Special Drawing Rights'),
  CatalogCurrency('XOF', 'West African CFA Franc'),
  CatalogCurrency('XPF', 'CFP Franc'),
  CatalogCurrency('YER', 'Yemeni Rial'),
  CatalogCurrency('ZAR', 'South African Rand'),
  CatalogCurrency('ZMW', 'Zambian Kwacha'),
  CatalogCurrency('ZWG', 'Zimbabwe Gold'),
  CatalogCurrency('ZWL', 'Zimbabwean Dollar'),
];

final _byCode = {for (final c in kCurrencyCatalog) c.code: c};

/// Katalogda var mı (kur kaynağının döndürdüğü kod)?
bool isCatalogCurrency(String code) => _byCode.containsKey(code);

/// İngilizce ad (özel isim, çevrilmez); katalog dışıysa kod.
String catalogCurrencyName(String code) => _byCode[code]?.name ?? code;

/// Ondalık kullanmayan paralar: tutarlar tam sayı biçimlenir.
const kZeroDecimalCurrencies = {
  'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF', 'UGX',
  'VND', 'VUV', 'XAF', 'XOF', 'XPF', 'IDR', 'LAK', 'MGA', 'MMK', 'SLL', 'UZS',
};

/// Para koduna göre ondalık hane: 0 ya da 2.
int decimalsFor(String code) => kZeroDecimalCurrencies.contains(code) ? 0 : 2;

/// ISO-3166 çiftinden bayrak emojisi (bölgesel gösterge harfleri). Ülkesi
/// olmayan (EUR, XOF, XAF, XCD, XPF, XCG, XDR) için nötr simge.
String flagFor(String code) {
  const overrides = {
    'EUR': '🇪🇺',
    'ANG': '🇨🇼',
    'XCG': '🇨🇼',
    'CNH': '🇨🇳',
    'GGP': '🇬🇬',
    'IMP': '🇮🇲',
    'JEP': '🇯🇪',
    'KID': '🇰🇮',
    'TVD': '🇹🇻',
    'FOK': '🇫🇴',
  };
  final o = overrides[code];
  if (o != null) return o;
  if (code.length != 3 || code.startsWith('X')) return '🏳️';
  final cc = code.substring(0, 2).toUpperCase();
  return String.fromCharCodes(cc.codeUnits.map((u) => 0x1F1E6 + (u - 65)));
}

/// Çevirici tutarı: para birimine göre 0 ya da 2 ondalık, dil gruplaması.
String formatConverted(double amount, String code) {
  final d = decimalsFor(code);
  final pattern = d == 0 ? '#,##0' : '#,##0.00';
  return NumberFormat(pattern, moneyLocale).format(amount);
}
