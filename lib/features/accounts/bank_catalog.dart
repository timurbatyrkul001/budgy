import 'package:flutter/material.dart';

import '../../core/ex_style.dart';

/// Banka marka kataloğu — kart görselinin RENGİ, STİLİ ve ADI buradan gelir.
///
/// NEDEN LOGO YOK: Banka logoları tescilli marka. Uygulamaya gömüp App
/// Store'da dağıtmak hem hukuken bizi açıkta bırakır (lisansımız yok) hem
/// de inceleme ekibinin "üçüncü taraf marka kullanımı" gerekçesiyle
/// takıldığı bilinen bir konu. Bunun yerine kartı kendimiz çiziyoruz:
/// bankanın marka rengi + banka adı bizim tipografimizle. İnsan gözü rengi
/// logodan önce tanır — mor kart "Enpara", altın kart "Kaspi" der.
///
/// NEDEN DESEN VAR AMA KOPYA DEĞİL: Düz renkli kartlar birbirine benziyor;
/// kullanıcı gerçek kartının KARAKTERİNİ (Kaspi Gold'un metalik altını,
/// Enpara'nın beyaz üstü renkli şeridi) arıyor. O karakteri [CardStyle]
/// ile veriyoruz: marka rengi + bizim çizdiğimiz sade, geometrik bir motif
/// (metalik gradyan, çapraz şerit, köşegen iki ton). SINIR ŞU: gerçek kart
/// yüzünü birebir kopyalamıyoruz — bankanın kendi şerit açısı, oranı,
/// logosu, hologramı, kart numarası, isim, son kullanma yok. Amaç "benim
/// kartım" diye TANINMASI, bankanın ürün görseli gibi görünmesi değil;
/// ikincisi hem ticari taklit riski hem de "bu uygulama kartımı tutuyor"
/// yanılgısı demek. Geometri `account_card.dart` içindeki painter'larda,
/// her biri kendi oranlarıyla.
///
/// RENKLER NEREDEN: Her kayıttaki hex, bankanın resmî sitesi / kurumsal
/// kimlik kılavuzundaki ana rengin ezberden aktarımı (Pantone eşleniğiyle
/// birlikte not düştüm). Yüzde yüz birebir olduğunu iddia etmiyoruz; amaç
/// "o bankanın rengi" diye tanınması, pikseli pikseline eşleşmesi değil.
///
/// KONTRAST KURALI: Kart üstündeki yazı rengi [BankBrand.surface]'tan türer:
/// koyu zeminde BEYAZ, açık zeminde mürekkep (`Ex.text`). WCAG AA metin için
/// yazı ile zemin arasında en az 4.5:1 gerekir. Sarı (Vakıfbank), turuncu
/// (ING), açık yeşil (TEB, Halyk, Sber) ve parlak kırmızı (Alfa) marka
/// tonları beyazla bunu geçmez; o kayıtlarda ton KOYULAŞTIRILDI ve yanına
/// yazıldı. Açık zeminli kartlarda (Kaspi altını, Enpara beyazı) tam tersi:
/// zemin yeterince AÇIK tutuldu ki mürekkep okunsun. Testler bu eşiği her
/// kayıt için kendi zeminine göre doğrular (`test/bank_catalog_test.dart`).

/// Kart yüzünün çizim stili. Geometrinin kendisi `account_card.dart`'ta.
enum CardStyle {
  /// Düz marka rengi, hafif dikey gradyan. Varsayılan; çoğu banka böyle.
  flat,

  /// Metalik his: çapraz, koyu→parlak→koyu gradyan + hafif parlama.
  /// Altın/gümüş kartlar için (Kaspi Gold).
  metal,

  /// Açık zemin üstünde sağ üstten sol alta geniş çapraz şerit; şerit içinde
  /// [BankBrand.accents] yumuşak geçişle. (Enpara.)
  ribbon,

  /// Köşegenle ikiye bölünmüş iki ton: [BankBrand.color] ve
  /// [BankBrand.accents]'in ilki (yoksa aynı rengin koyusu).
  split,
}

class BankBrand {
  const BankBrand({
    required this.key,
    required this.name,
    required this.color,
    required this.country,
    required this.currency,
    // Yeni alanların varsayılanı var: `account_editor_sheet` gibi dışarıdan
    // BankBrand kuran yerler eski imzayla çalışmaya devam etsin.
    this.style = CardStyle.flat,
    this.surface = Brightness.dark,
    this.accents = const [],
  });

  /// Kalıcı kimlik — Firestore'a bu yazılır, ad/renk sonradan değişebilir.
  final String key;

  /// Kart üstünde basılacak ad (bankanın kendi yazımıyla).
  final String name;

  /// Markanın kimlik rengi. `flat`/`metal`/`split`'te kart zemini; `ribbon`'da
  /// zemin açık kâğıt olduğu için yalnız çip/nokta gibi küçük yerlerde ve
  /// şerit paleti boşsa şeritte kullanılır. Yazıyla ≥ 4.5:1 kontrast verir
  /// (bkz. [ground], [ink]).
  final Color color;

  /// ISO-2 ülke kodu; genel kayıtlarda (`other`, `cash`) boş.
  final String country;

  /// Bu bankada hesap açınca varsayılan para birimi (TRY / AZN / KZT / RUB).
  final String currency;

  /// Kart yüzünün çizim stili.
  final CardStyle style;

  /// Kart zemini koyu mu açık mı. Yazı, temassız simgesi ve para birimi
  /// rozeti bu bilgiden renk alır; stil tek başına belirlemez (koyu bir
  /// metal de olabilirdi), o yüzden ayrı alan.
  final Brightness surface;

  /// İkincil renkler: `ribbon`'da şerit paleti (2+ renk, geçiş için),
  /// `split`'te ikinci ton (ilk eleman). Diğer stiller okumaz.
  final List<Color> accents;

  /// Ülkeye bağlı olmayan genel kayıt (Diğer banka, Nakit).
  bool get isGeneric => country.isEmpty;

  bool get isLight => surface == Brightness.light;

  /// Kart üstündeki yazı/simge rengi: açık zeminde mürekkep, koyuda beyaz.
  /// Krem kâğıt uygulamada beyaz zeminli karta beyaz yazı okunmaz; mürekkep
  /// de uygulamanın kendi metin rengi, böylece kart "yabancı" durmuyor.
  Color get ink => isLight ? Ex.text : Colors.white;

  /// Yazının gerçekten üstüne oturduğu zemin. `ribbon`'da şerit yazıdan
  /// uzak geçer, yazı beyaz kâğıt üstündedir; diğerlerinde marka rengi.
  Color get ground => switch (style) {
        CardStyle.ribbon => isLight ? Ex.surface : color,
        _ => color,
      };

  /// WCAG kontrast oranı (1..21). Her iki sırayla aynı sonucu verir.
  static double contrastBetween(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Yazı ([ink]) ile zemin ([ground]) arasındaki kontrast. Test bunu ölçer.
  double get contrastWithInk => contrastBetween(ground, ink);

  /// Beyaz metne karşı kontrast. Eski API; artık yalnız koyu zeminli
  /// kartlar için anlamlı — açık zeminde [contrastWithInk] kullanın.
  double get contrastWithWhite => contrastBetween(color, Colors.white);

  /// Kopya. `style` / `accents` parametreleri kullanıcı seçimi içindir:
  /// katalogdaki stil yalnız VARSAYILAN — Ziraat'in tek bir kartı yok
  /// (Bankkart, Combo, World...), kullanıcı cebindekine göre değiştirebilir.
  /// `AccountCard.styleOverride` / `accentOverride` buradan geçer.
  BankBrand copyWith({
    String? country,
    String? currency,
    CardStyle? style,
    Brightness? surface,
    List<Color>? accents,
  }) =>
      BankBrand(
        key: key,
        name: name,
        color: color,
        country: country ?? this.country,
        currency: currency ?? this.currency,
        style: style ?? this.style,
        surface: surface ?? this.surface,
        accents: accents ?? this.accents,
      );
}

/// Kayıtlı stil adını (`CardStyle.name`, örn. "ribbon") enum'a çevirir.
/// Bilinmeyen/boş ad → null: eski kayıt ya da silinmiş stil çökertmesin,
/// çağıran markanın varsayılanına düşsün. `Account` modeline yazarken
/// `style.name`, okurken bu fonksiyon kullanılır.
CardStyle? cardStyleFromName(String? name) {
  if (name == null) return null;
  for (final s in CardStyle.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// Desteklenen ülkeler, seçicideki sırayla. Türkiye ilk: kullanıcı kitlesi.
const kBankCountries = ['TR', 'AZ', 'KZ', 'RU'];

/// Ülke → o ülkenin ulusal para birimi.
String currencyForCountry(String code) => switch (code) {
      'TR' => 'TRY',
      'AZ' => 'AZN',
      'KZ' => 'KZT',
      'RU' => 'RUB',
      // Bilinmeyen ülke: uygulamanın varsayılanı (Account.fromDoc ile aynı).
      _ => 'TRY',
    };

/// Tüm katalog. Sıra = seçicideki sıra (ülke içinde yaygınlık).
const kBankCatalog = <BankBrand>[
  // ── Türkiye ────────────────────────────────────────────────────────────
  BankBrand(
    key: 'enpara',
    name: 'Enpara',
    // Enpara moru (Pantone 2603 C ≈ #702082): kimlik rengi, çipte görünür.
    color: Color(0xFF702082),
    country: 'TR',
    currency: 'TRY',
    // NEDEN ribbon: Enpara'nın kartı beyaz üstüne renkli çapraz şerittir;
    // mor tek başına "Enpara" demiyor, beyaz + üç renk şerit diyor. Zemin
    // açık, yazı mürekkep. Şerit: turuncu → mor → yeşil, bizim açımız ve
    // oranımızla (bankanın şeridi birebir değil).
    style: CardStyle.ribbon,
    surface: Brightness.light,
    accents: [Color(0xFFF07E1A), Color(0xFF702082), Color(0xFF2E9E4F)],
  ),
  BankBrand(
    key: 'garanti',
    name: 'Garanti BBVA',
    // BBVA "core blue" #004481 — Garanti BBVA birleşmeden beri bu laciverti
    // kullanıyor, eski Garanti yeşili artık ikincil. ~9.8:1.
    color: Color(0xFF004481),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'isbank',
    name: 'İş Bankası',
    // İş Bankası laciverti (Pantone 288 C ≈ #002D72). Olduğu gibi.
    color: Color(0xFF002D72),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'yapikredi',
    name: 'Yapı Kredi',
    // Yapı Kredi koyu mavisi (logo laciverti, ≈ #003A70). Olduğu gibi.
    color: Color(0xFF003A70),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'akbank',
    name: 'Akbank',
    // Akbank kırmızısı (Pantone 485 C ≈ #DA291C). Beyazla ~4.9:1, sınırda
    // ama geçiyor; koyulaştırmadık.
    color: Color(0xFFDA291C),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'ziraat',
    name: 'Ziraat',
    // Ziraat kırmızısı (Pantone 186 C ≈ #C8102E). ~5.9:1, olduğu gibi.
    color: Color(0xFFC8102E),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'papara',
    name: 'Papara',
    // Papara moru (dijital markanın vurgu rengi, ≈ #4B2A8A). Beyazla ~10:1.
    color: Color(0xFF4B2A8A),
    country: 'TR',
    currency: 'TRY',
    // NEDEN split: Papara'nın kartları tek düz renk değil, iki tonlu/kesik
    // yüzeyler; köşegen iki ton bunu düz mor kartlardan (Enpara/QNB) ayırır.
    // İkinci ton aynı morun koyusu, beyazla ~14:1 — simge ve rozet onun
    // üstüne düşüyor.
    style: CardStyle.split,
    accents: [Color(0xFF2B1650)],
  ),
  BankBrand(
    key: 'denizbank',
    name: 'DenizBank',
    // DenizBank kırmızısı (logo dalgası, ≈ #E4002B). Parlak hali ~4.3:1 ile
    // eşiğin altında kaldığı için koyulaştırıldı → #B5121B.
    color: Color(0xFFB5121B),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'qnb',
    name: 'QNB',
    // QNB mor-bordosu (Pantone 7421 C komşusu, ≈ #6B1E5C). Olduğu gibi.
    color: Color(0xFF6B1E5C),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'vakifbank',
    name: 'VakıfBank',
    // VakıfBank sarısı (#FFCB05) beyaz yazıyla ~1.4:1 — okunmaz. Aynı tonun
    // koyu hardalı kullanıldı; sarı kimliği korunuyor, metin okunuyor.
    color: Color(0xFF8A6600),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'teb',
    name: 'TEB',
    // TEB / BNP Paribas yeşili (#009640) beyazla ~3.9:1, eşiğin altında;
    // koyulaştırıldı → #007A33.
    color: Color(0xFF007A33),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'ing',
    name: 'ING',
    // ING turuncusu (#FF6200) beyazla ~3:1 — geçmez. Yanık turuncuya
    // koyulaştırıldı → #B84A00; hâlâ "ING turuncusu" diye okunuyor.
    color: Color(0xFFB84A00),
    country: 'TR',
    currency: 'TRY',
  ),

  // ── Azerbaycan ─────────────────────────────────────────────────────────
  BankBrand(
    key: 'kapital',
    name: 'Kapital Bank',
    // Kapital Bank kırmızısı (≈ #D7141A). ~5.2:1, olduğu gibi.
    color: Color(0xFFD7141A),
    country: 'AZ',
    currency: 'AZN',
  ),
  BankBrand(
    key: 'pasha',
    name: 'PAŞA Bank',
    // PAŞA Bank koyu yeşili (logo, ≈ #00573F). Olduğu gibi.
    color: Color(0xFF00573F),
    country: 'AZ',
    currency: 'AZN',
  ),
  BankBrand(
    key: 'birbank',
    name: 'Birbank',
    // Birbank, Kapital Bank'ın dijital markası. Kullanıcı tarifine göre
    // kartı SİYAH zemin üstüne KIRMIZI vurgu — renkler kullanıcı tarifinden,
    // resmî marka kılavuzundan değil (birbank.az kart görsellerini JS ile
    // yüklüyor, sunucu HTML'inden doğrulanamadı). Zemin: uygulamanın
    // mürekkebiyle (#111) karışmasın diye bir tık açık antrasit.
    color: Color(0xFF161616),
    country: 'AZ',
    currency: 'AZN',
    // NEDEN split: siyah → kırmızı köşegen, tarif edilen görünüm bu; ayrıca
    // kırmızı Kapital kartının yanında Birbank'ı ayırıyor. Kırmızı, Kapital
    // kırmızısının (#E4002B) krem kâğıtta ucuz durmayan vişneye çekilmişi
    // (≈ #C41230, beyazla ~6:1 — simge ve rozet onun üstüne düşüyor).
    style: CardStyle.split,
    accents: [Color(0xFFC41230)],
  ),
  BankBrand(
    key: 'abb',
    name: 'ABB',
    // Azərbaycan Beynəlxalq Bankı mavisi (≈ #0B4EA2). Olduğu gibi.
    color: Color(0xFF0B4EA2),
    country: 'AZ',
    currency: 'AZN',
  ),

  // ── Kazakistan ─────────────────────────────────────────────────────────
  BankBrand(
    key: 'kaspi',
    name: 'Kaspi',
    // NEDEN altın, kırmızı değil: Kaspi'nin logosu kırmızı ama herkesin
    // cebindeki kart "Kaspi Gold" — altın metalik. Kullanıcı kartını
    // altından tanıyor. Ton (≈ #CFA54C) sarıya kaçmayan, hafif sıcak altın;
    // mürekkeple ~7.9:1. Metal gradyanının en koyu durağı da eşiği geçer
    // (account_card_test doğrular).
    color: Color(0xFFCFA54C),
    country: 'KZ',
    currency: 'KZT',
    // NEDEN metal: altın hissini düz sarı veremez; çapraz koyu→parlak→koyu
    // gradyan verir. Zemin açık → yazı mürekkep.
    style: CardStyle.metal,
    surface: Brightness.light,
  ),
  BankBrand(
    key: 'halyk',
    name: 'Halyk',
    // Halyk yeşili (≈ #00A651) beyazla ~3.3:1 — geçmez. Koyulaştırıldı
    // → #007A3D.
    color: Color(0xFF007A3D),
    country: 'KZ',
    currency: 'KZT',
  ),
  BankBrand(
    key: 'freedom',
    name: 'Freedom Bank',
    // Freedom Finance yeşili (≈ #1AB248) limona çalar, beyazla ~2.6:1.
    // Koyulaştırıldı → #1B7A2E; Halyk'tan biraz daha sarı kalsın diye
    // kırmızı kanalı bırakıldı.
    color: Color(0xFF1B7A2E),
    country: 'KZ',
    currency: 'KZT',
  ),
  BankBrand(
    key: 'jusan',
    name: 'Jusan',
    // Jusan turuncusu (≈ #F28C00) beyazla ~2.4:1 — geçmez. Kehribara
    // koyulaştırıldı → #9A6200.
    color: Color(0xFF9A6200),
    country: 'KZ',
    currency: 'KZT',
  ),

  // ── Rusya ──────────────────────────────────────────────────────────────
  BankBrand(
    key: 'tbank',
    name: 'T-Bank',
    // NEDEN siyah: T-Bank'ın kart karakteri koyu/siyah (sarı logo, siyah
    // plastik); sarıyı (#FFDD2D) zemin yapmak beyaz yazıyla ~1.3:1, okunmaz,
    // koyultunca da hardal olup markayı kaybediyordu. Uygulamanın
    // mürekkebi (#111) ile karışmasın diye bir tık açık antrasit. Flat kaldı:
    // siyah kartın karakteri düzlüğünde.
    color: Color(0xFF1E1E1E),
    country: 'RU',
    currency: 'RUB',
  ),
  BankBrand(
    key: 'sber',
    name: 'Sber',
    // Sber yeşili (#21A038, resmî) beyazla ~3.4:1 — geçmez. Koyulaştırıldı
    // → #137A2B.
    color: Color(0xFF137A2B),
    country: 'RU',
    currency: 'RUB',
  ),
  BankBrand(
    key: 'alfa',
    name: 'Alfa-Bank',
    // Alfa kırmızısı (#EF3124, resmî) beyazla ~4.1:1 — sınırın altında.
    // Hafif koyulaştırıldı → #C9261B.
    color: Color(0xFFC9261B),
    country: 'RU',
    currency: 'RUB',
  ),

  // ── Genel ──────────────────────────────────────────────────────────────
  BankBrand(
    key: 'other',
    name: 'Diğer banka',
    // Nötr, markasız gri: hiçbir bankayı çağrıştırmasın. Ülkeye göre
    // sunulurken para birimi `banksForCountry` içinde o ülkeye uyarlanır.
    color: Color(0xFF4A4A46),
    country: '',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'cash',
    name: 'Nakit',
    // Nakit kart olarak çizilmez (AccountCard kâğıt görünümüne düşer);
    // renk yalnız liste/çip gibi küçük yerler için var — para yeşili.
    color: Ex.brand,
    country: '',
    currency: 'TRY',
  ),
];

/// Bir ülkenin bankaları + sonunda genel kayıtlar (Diğer banka, Nakit).
///
/// Genel kayıtlar o ülkenin para birimiyle döner: Azerbaycan seçen biri
/// "Diğer banka" dediğinde varsayılan AZN olmalı, TRY değil.
List<BankBrand> banksForCountry(String code) {
  final cc = code.toUpperCase();
  final cur = currencyForCountry(cc);
  return [
    for (final b in kBankCatalog)
      if (b.country == cc) b,
    for (final b in kBankCatalog)
      if (b.isGeneric) b.copyWith(country: cc, currency: cur),
  ];
}

/// Anahtara göre kayıt; yoksa null (eski/silinmiş anahtar çökertmesin).
BankBrand? bankByKey(String key) {
  for (final b in kBankCatalog) {
    if (b.key == key) return b;
  }
  return null;
}

/// Hesap adından banka tahmini ("Enpara Maaş" → enpara). Hesap modelinde
/// henüz banka anahtarı alanı yok; eski hesaplar da yalnız adla geldi. Ad
/// içinde marka adı (veya anahtarı) geçiyorsa yakalar, yoksa null.
BankBrand? bankByName(String name) {
  final n = name.toLowerCase();
  if (n.trim().isEmpty) return null;
  for (final b in kBankCatalog) {
    if (b.isGeneric) continue;
    final full = b.name.toLowerCase();
    // "Garanti BBVA" için "garanti" de yetsin: adın ilk kelimesi.
    final first = full.split(' ').first;
    if (n.contains(full) || n.contains(b.key) || n.contains(first)) return b;
  }
  return null;
}
