import '../../core/currency_catalog.dart';
import '../../core/formatters.dart';
import '../../core/fx.dart';

/// Döviz çeviricinin saf mantığı: çevrim, satır sınırları, yıldız sınırı,
/// ana ekran çip seçimi, seçici filtresi.

const kConverterMinRows = 2;
const kConverterMaxRows = 6;
const kMaxStarred = 2;
const kMaxRecentCurrencies = 5;

/// [amount] [from] → [to]; kurlar herhangi bir tabana göre olabilir
/// (rates[x] = 1 base kaç x). Taban dışı iki para arasında çapraz kur.
double? convertAmount(
  double amount,
  String from,
  String to,
  FxSnapshot? snap,
) {
  if (from == to) return amount;
  if (snap == null) return null;
  final rf = from == snap.base ? 1.0 : snap.rates[from];
  final rt = to == snap.base ? 1.0 : snap.rates[to];
  if (rf == null || rt == null || rf <= 0) return null;
  final v = amount / rf * rt;
  final d = decimalsFor(to);
  final k = d == 0 ? 1 : 100;
  return (v * k).roundToDouble() / k;
}

/// 1 [code] kaç [main] eder (ana ekran çipi). Kurlar [main] tabanlı.
double? priceInMain(FxSnapshot? snap, String code) {
  if (snap == null) return null;
  if (code == snap.base) return 1;
  final r = snap.rates[code];
  if (r == null || r <= 0) return null;
  return 1 / r;
}

/// Kur biçimi: 41,52 · 540 (büyük değerlerde ondalık gereksiz).
String formatRate(double v) => formatConverted(v, v >= 1000 ? 'JPY' : 'USD');

/// Ana ekran çipinde gösterilecek paralar: yıldızlılar (ana para hariç,
/// en fazla [kMaxStarred]); hiç yoksa USD (ana para USD ise EUR).
List<String> dashboardCurrencies(List<String> starred, String mainCode) {
  final list = starred.where((c) => c != mainCode).take(kMaxStarred).toList();
  if (list.isNotEmpty) return list;
  return [mainCode == 'USD' ? 'EUR' : 'USD'];
}

/// Yıldız ekleme/çıkarma; sınıra ulaşıldıysa null (değişiklik yok).
List<String>? toggleStar(List<String> starred, String code) {
  if (starred.contains(code)) return [for (final c in starred) if (c != code) c];
  if (starred.length >= kMaxStarred) return null;
  return [...starred, code];
}

/// Satır ekleme: sınırı aşarsa null. Yeni satır, kullanılmayan ilk
/// tercih edilen paradan (ana, cüzdanlar, son kullanılanlar, USD, EUR).
List<String>? addRow(List<String> rows, List<String> preferred) {
  if (rows.length >= kConverterMaxRows) return null;
  final candidates = [...preferred, 'USD', 'EUR', 'GBP', 'TRY', 'KZT', 'RUB'];
  final next = candidates.where((c) => !rows.contains(c)).firstOrNull;
  if (next == null) return null;
  return [...rows, next];
}

/// Satır silme: en az [kConverterMinRows] kalır; kalmıyorsa null.
List<String>? removeRow(List<String> rows, int index) {
  if (rows.length <= kConverterMinRows || index < 0 || index >= rows.length) {
    return null;
  }
  return [for (final (i, r) in rows.indexed) if (i != index) r];
}

/// Son kullanılanlar: başa ekle, tekrarları at, [kMaxRecentCurrencies] tut.
List<String> pushRecent(List<String> recent, String code) =>
    [code, ...recent.where((c) => c != code)].take(kMaxRecentCurrencies).toList();

/// Seçici bölümü.
class PickerSection {
  const PickerSection(this.label, this.codes);

  final String label; // 'suggested' ya da harf
  final List<String> codes;
}

/// Seçici listesi: [query] ile filtrelenmiş, [exclude] dışı; önce
/// "Önerilen" ([suggested]: ana para, cüzdanlar, son kullanılanlar —
/// sırayla, tekrarsız), sonra A-Z bölümleri (ada göre).
List<PickerSection> pickerSections({
  required String query,
  required Set<String> exclude,
  required List<String> suggested,
}) {
  final q = query.trim().toLowerCase();
  bool ok(String code) =>
      !exclude.contains(code) &&
      isCatalogCurrency(code) &&
      (q.isEmpty ||
          code.toLowerCase().contains(q) ||
          catalogCurrencyName(code).toLowerCase().contains(q));

  final seen = <String>{};
  final sug = [
    for (final c in suggested)
      if (seen.add(c) && ok(c)) c,
  ];
  final rest = kCurrencyCatalog
      .map((c) => c.code)
      .where((c) => !sug.contains(c) && ok(c))
      .toList()
    ..sort((a, b) => catalogCurrencyName(a).compareTo(catalogCurrencyName(b)));
  final byLetter = <String, List<String>>{};
  for (final c in rest) {
    final letter = catalogCurrencyName(c)[0].toUpperCase();
    byLetter.putIfAbsent(letter, () => []).add(c);
  }
  return [
    if (sug.isNotEmpty) PickerSection('suggested', sug),
    for (final e in byLetter.entries) PickerSection(e.key, e.value),
  ];
}

/// Cüzdan/bakiye seti ile katalog ayrımı: sembol yalnız küçük sette var.
String symbolOrCode(String code) => kCurrencies[code] ?? code;
