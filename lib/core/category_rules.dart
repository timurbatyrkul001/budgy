/// Kategori otomasyonu: not/işletme metnindeki anahtar kelime → kategori.
///
/// Kategorisiz kaydedilen harcamalarda ve parser'ın regex yedeğinde
/// uygulanır. Kullanıcının kendi seçtiği kategori ASLA ezilmez.
/// Eşleşme: küçük harf + aksan/Türkçe karakter duyarsız, alt dizi;
/// önce kullanıcı kuralları (sırayla), sonra yerleşikler; ilk eşleşen kazanır.
library;

/// Yerleşik kural seti: katalog anahtarı → anahtar kelimeler (TR/AB
/// işletmeleri; marka logosu yok, yalnız metin).
const kBuiltinRules = <String, List<String>>{
  'groceries': [
    'a101', 'bim', 'şok', 'migros', 'carrefour', 'getir', 'macrocenter',
    'metro market', 'file market', 'hakmar', 'tarım kredi', 'lidl', 'aldi',
    'rewe', 'tesco', 'sainsbury', 'auchan', 'spar',
  ],
  'restaurants': [
    'yemeksepeti', 'burger king', 'mcdonalds', "mcdonald's", 'starbucks',
    'kfc', 'dominos', 'popeyes', 'subway', 'restoran', 'cafe', 'kafe',
    'lokanta', 'pizza', 'kebap', 'döner', 'köfte', 'burger',
  ],
  'delivery': ['trendyol yemek', 'getir yemek', 'migros yemek', 'kurye'],
  'coffee': ['kahve', 'coffee', 'espresso', 'latte', 'kahve dünyası'],
  'fuel': [
    'opet', 'shell', 'bp', 'petrol ofisi', 'total', 'aytemiz', 'lukoil',
    'benzin', 'mazot', 'akaryakıt', 'yakıt',
  ],
  'taxi': ['uber', 'bitaksi', 'martı', 'marti', 'taksi', 'taxi', 'bolt'],
  'publicTransport': [
    'istanbulkart', 'metro', 'otobüs', 'metrobüs', 'marmaray', 'tramvay',
    'vapur', 'iett', 'ankarakart',
  ],
  'car': ['otopark', 'ispark', 'oto yıkama', 'lastik', 'servis', 'hgs', 'ogs'],
  'clothes': [
    'trendyol', 'hepsiburada', 'zara', 'lc waikiki', 'lcw', 'h&m', 'mango',
    'koton', 'defacto', 'boyner', 'bershka', 'pull&bear', 'primark',
    'uniqlo', 'nike', 'adidas', 'flo', 'deichmann',
  ],
  'electronics': [
    'mediamarkt', 'teknosa', 'vatan', 'apple store', 'samsung', 'amazon',
  ],
  'online': ['amazon', 'aliexpress', 'temu', 'n11', 'çiçeksepeti'],
  'personalCare': [
    'gratis', 'watsons', 'rossmann', 'sephora', 'berber', 'kuaför',
    'eczane kozmetik',
  ],
  'streaming': ['netflix', 'youtube', 'disney', 'prime video', 'blutv', 'exxen'],
  'music': ['spotify', 'apple music', 'deezer'],
  'cloud': ['icloud', 'google one', 'dropbox', 'google drive'],
  'games': ['playstation', 'xbox', 'steam', 'nintendo', 'game pass'],
  'software': ['microsoft 365', 'adobe', 'chatgpt', 'notion', 'figma'],
  'utilities': [
    'iski', 'aski', 'izsu', 'bedaş', 'ayedaş', 'enerjisa', 'ck enerji',
    'igdaş', 'başkentgaz', 'elektrik', 'doğalgaz', 'su faturası', 'aidat',
  ],
  'internet': [
    'turkcell', 'vodafone', 'türk telekom', 'turk telekom', 'superonline',
    'turknet', 'kablonet', 'digiturk', 'd-smart', 'internet',
  ],
  'rent': ['kira'],
  'pharmacy': ['eczane', 'pharmacy', 'ilaç'],
  'doctor': ['hastane', 'doktor', 'klinik', 'diş', 'muayene', 'acıbadem', 'medipol'],
  'sport': ['spor salonu', 'gym', 'fitness', 'macfit', 'decathlon'],
  'bankFees': ['banka', 'komisyon', 'işlem ücreti', 'eft ücreti', 'havale ücreti'],
  'insurance': ['sigorta', 'kasko', 'axa', 'allianz', 'anadolu sigorta'],
  'taxes': ['vergi', 'mtv', 'gib', 'harç', 'ceza'],
  'loans': ['kredi', 'taksit', 'kredi kartı borcu'],
  'education': ['okul', 'kurs', 'udemy', 'coursera', 'kitap', 'kırtasiye'],
  'pets': ['petshop', 'pet shop', 'veteriner', 'mama'],
  'kids': ['oyuncak', 'kreş', 'bebek'],
  'travel': ['thy', 'pegasus', 'ajet', 'otel', 'hotel', 'airbnb', 'booking', 'uçak'],
  'entertainment': ['sinema', 'cinema', 'tiyatro', 'konser', 'biletix'],
};

/// Toplam yerleşik anahtar kelime sayısı ("Yerleşik kurallar (N)").
int builtinRuleCount() =>
    kBuiltinRules.values.fold<int>(0, (s, l) => s + l.length);

/// Kullanıcı kuralı: users/{uid}/rules — anahtar kelime → zarf.
/// Yerleşik anahtar kelime sayısı (tanıtım metni gerçek sayıyı söyler).
final int kBuiltinRuleCount =
    kBuiltinRules.values.fold(0, (n, list) => n + list.length);

class UserRule {
  const UserRule({
    required this.id,
    required this.keyword,
    required this.envelopeId,
    required this.envelopeName,
  });

  final String id;
  final String keyword;
  final String envelopeId;
  final String envelopeName;
}

/// Eşleşme sonucu: ya kullanıcı zarfı ([envelopeId]) ya da yerleşik katalog
/// anahtarı ([catalogKey]).
class RuleMatch {
  const RuleMatch({required this.keyword, this.envelopeId, this.catalogKey});

  final String keyword;
  final String? envelopeId;
  final String? catalogKey;
}

const _foldMap = {
  'ç': 'c', 'ğ': 'g', 'ı': 'i', 'i̇': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
  'â': 'a', 'î': 'i', 'û': 'u', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'à': 'a', 'á': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ó': 'o', 'ò': 'o',
  'ô': 'o', 'õ': 'o', 'ú': 'u', 'ù': 'u', 'ñ': 'n', 'ß': 'ss', 'ý': 'y',
};

/// Küçük harf + aksan/Türkçe karakter sadeleştirme ("Şok Market" → "sok market").
String normalizeText(String s) {
  final lower = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(_foldMap[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Metne uyan ilk kural. [userRules] önce (verildiği sırada), sonra
/// yerleşikler ([disabledBuiltins] anahtar kelimeleri atlanır). Yok → null.
RuleMatch? matchCategory(
  String? text, {
  List<UserRule> userRules = const [],
  Set<String> disabledBuiltins = const {},
}) {
  if (text == null || text.trim().isEmpty) return null;
  final t = normalizeText(text);
  for (final r in userRules) {
    final k = normalizeText(r.keyword);
    if (k.isNotEmpty && t.contains(k)) {
      return RuleMatch(
          keyword: r.keyword, envelopeId: r.envelopeId);
    }
  }
  final disabled = {for (final d in disabledBuiltins) normalizeText(d)};
  for (final e in kBuiltinRules.entries) {
    for (final kw in e.value) {
      final k = normalizeText(kw);
      if (disabled.contains(k)) continue;
      if (t.contains(k)) return RuleMatch(keyword: kw, catalogKey: e.key);
    }
  }
  return null;
}
