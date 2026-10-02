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
/// RENKLER NEREDEN: Her kayıttaki hex 2026-10-02'de birincil kaynaktan
/// doğrulandı: bankanın kendi sitesindeki logo SVG/PNG dosyası, sitenin
/// <meta theme-color> değeri ya da site CSS'indeki marka rengi; siteye
/// erişilemeyen birkaç bankada (Kapital, Sber) Wikimedia Commons'taki logo
/// dosyası ikincil kaynak olarak kullanıldı. Kaynak ve tarih her kaydın
/// "KAYNAK:" satırında. Doğrulanamayan tonlar (Kaspi'nin altını, T-Bank /
/// Birbank / Papara'nın siyahı) açıkça "DOĞRULANAMADI" diye işaretli;
/// orada amaç "o bankanın kartı" diye tanınması, pikseli pikseline
/// eşleşmesi değil.
///
/// KONTRAST KURALI: Kart üstündeki yazı rengi [BankBrand.surface]'tan türer:
/// koyu zeminde BEYAZ, açık zeminde mürekkep (`Ex.text`). WCAG AA metin için
/// yazı ile zemin arasında en az 4.5:1 gerekir. Sarı (VakıfBank, Jusan),
/// turuncu (ING), açık yeşil (TEB, Freedom, Sber) ve parlak kırmızı (Alfa,
/// Birbank'ın vurgusu) marka tonları beyazla bunu geçmez; o kayıtlarda ton
/// KOYULAŞTIRILDI — ton (hue) sabit, RGB orantılı ölçeklendi, eşiği ilk
/// geçen değer alındı — ve resmî hex ile birlikte yanına yazıldı. Açık zeminli kartlarda (Kaspi altını, Enpara beyazı) tam tersi:
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
///
/// Her kayıtta "KAYNAK:" satırı var — renk nereden alındı, hangi tarihte
/// bakıldı. Kısaltmalar: "site logo SVG" = bankanın kendi sitesindeki logo
/// dosyasının fill değeri; "theme-color" = sitenin <meta name=theme-color>
/// değeri (bankanın tarayıcıya bildirdiği kendi rengi); "Commons" =
/// Wikimedia Commons'taki logo dosyası (ikincil kaynak, yalnız site
/// erişilemeyince veya çapraz doğrulama için).
const kBankCatalog = <BankBrand>[
  // ── Türkiye ────────────────────────────────────────────────────────────
  BankBrand(
    key: 'enpara',
    name: 'Enpara',
    // Enpara moru #AA55A1 — Pantone 2603 (#702082) sanılmıştı, yanlıştı:
    // gerçek logo daha açık, pembeye çalan bir mor. Çipte görünür.
    // KAYNAK (2026-10-02): enpara.com/Frontend/dist/images/enpara.svg
    // (logo fill ×6) + Commons "Enpara.com Logo.svg" aynı değer.
    color: Color(0xFFAA55A1),
    country: 'TR',
    currency: 'TRY',
    // NEDEN ribbon: Enpara'nın kartı beyaz üstüne renkli çapraz şerittir;
    // mor tek başına "Enpara" demiyor, beyaz + üç renk şerit diyor. Zemin
    // açık, yazı mürekkep. Şerit paleti logonun kendi üç rengi (turuncu
    // #F99D1C, mor #AA55A1, yeşil #8DC63F — aynı SVG'den), bizim açımız ve
    // oranımızla (bankanın şeridi birebir değil).
    style: CardStyle.ribbon,
    surface: Brightness.light,
    accents: [Color(0xFFF99D1C), Color(0xFFAA55A1), Color(0xFF8DC63F)],
  ),
  BankBrand(
    key: 'garanti',
    name: 'Garanti BBVA',
    // BBVA laciverti #004480 — birleşmeden beri ana renk bu, eski Garanti
    // yeşili logoda yalnız amblemde kaldı. Beyazla ~9.8:1, olduğu gibi.
    // KAYNAK (2026-10-02): garantibbva.com.tr/content/dam/public-website/
    // logo/logo.svg (fill #004480); sitenin theme-color'ı #004481 (1 birim
    // fark, aynı renk).
    color: Color(0xFF004480),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'isbank',
    name: 'İş Bankası',
    // İş Bankası mavisi #00559F — "Pantone 288 laciverti" sanılmıştı, logo
    // aslında daha açık, orta mavi. Beyazla ~7.5:1, olduğu gibi.
    // KAYNAK (2026-10-02): Commons "Türkiye İş Bankası logo.svg" (fill
    // #00559F) + isbank.com.tr v2.css'te aynı değer ×9. Site başlık
    // zemini daha koyu bir lacivert (#013682) ama o logo değil, zemin.
    color: Color(0xFF00559F),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'yapikredi',
    name: 'Yapı Kredi',
    // Yapı Kredi laciverti #004587. Beyazla ~9.5:1, olduğu gibi.
    // KAYNAK (2026-10-02): assets.yapikredi.com.tr/WebSite/_assets/img/
    // Yapikredi_logo.svg (fill ×10). Site HTML'inde #004990 da geçiyor
    // (buton tonu); logo değeri esas alındı.
    color: Color(0xFF004587),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'akbank',
    name: 'Akbank',
    // Akbank kırmızısı #DC0005. Beyazla ~5.2:1, geçiyor; koyulaştırmadık.
    // KAYNAK (2026-10-02): akbank.com/SiteAssets/img/logo.svg (fill) +
    // sitenin theme-color'ı aynı değer.
    color: Color(0xFFDC0005),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'ziraat',
    name: 'Ziraat',
    // Ziraat kırmızısı #E10514. Beyazla ~5.0:1, olduğu gibi.
    // KAYNAK (2026-10-02): ziraatbank.com.tr theme-color + site CSS'inde
    // en sık renk (×183). Commons'taki 2025 logo SVG'si #D71920 veriyor
    // (baskı/vektör farkı); bankanın sitesinde kullandığı değer esas.
    color: Color(0xFFE10514),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'papara',
    name: 'Papara',
    // Papara 2023'te (Ağustos) logosunu yeniledi: mor/gradyan BIRAKILDI,
    // kimlik sade SİYAH-BEYAZ oldu. Eski mor (#4B2A8A) artık marka değil.
    // Siyahın tam hex'i DOĞRULANAMADI: papara.com sunucudan yalnız
    // Bootstrap değişkenli bir kabuk döndürüyor, logo JS ile geliyor.
    // Uygulamanın mürekkebi (#111) ile karışmasın diye bir tık açık
    // antrasit — T-Bank/Birbank ile aynı gerekçe, ayrı ülke, yan yana
    // görünmezler.
    // KAYNAK (2026-10-02): fintechistanbul.org 24.08.2023 "Papara logosunu
    // yeniledi" (ikincil; siyah-beyaz tercihi açıkça yazıyor).
    color: Color(0xFF1A1A1A),
    country: 'TR',
    currency: 'TRY',
    // NEDEN split: Papara'nın kartları tek düz yüzey değil, kesik/iki tonlu;
    // köşegen bunu düz siyah T-Bank kartından ayırır. İkinci ton grafit
    // (#2E2E2E, beyazla ~13.6:1) — simge ve rozet onun üstüne düşüyor.
    style: CardStyle.split,
    accents: [Color(0xFF2E2E2E)],
  ),
  BankBrand(
    key: 'denizbank',
    name: 'DenizBank',
    // DenizBank MAVİ #004899 — kırmızı sanılmıştı, yanlıştı: logo yazısı
    // mavi, kırmızı yalnız eski logonun dalga vurgusuydu (Commons eski
    // "DenizBank logo.svg": mavi #004C91 + kırmızı #CE163A); 2026 logosu
    // tamamen mavi. Beyazla ~8.8:1, olduğu gibi.
    // KAYNAK (2026-10-02): denizbank.com/_assets/img/DenizbankLOGO-en-v6.svg
    // (tek fill ×9) + Commons "DenizBank logo 2026.svg" birebir aynı dosya;
    // site theme-color'ı #00529A (komşu ton).
    color: Color(0xFF004899),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'qnb',
    name: 'QNB',
    // QNB Türkiye laciverti #1B124B — "QNB" yazısının rengi (mor-bordo
    // #6B1E5C sanılmıştı, o amblemdeki ikincil ton). Beyazla ~17:1.
    // KAYNAK (2026-10-02): qnb.com.tr/_assets/img/logo.png — PNG'deki
    // doygun piksellerin %99'u #1B124B; brandfetch de #1A164E veriyor.
    // Sitenin theme-color'ı #870052 (amblemin mor-bordosu), yazı rengi değil.
    color: Color(0xFF1B124B),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'vakifbank',
    name: 'VakıfBank',
    // VakıfBank sarısı #FDB913 beyaz yazıyla ~1.7:1 — okunmaz. Aynı tonun
    // koyusu kullanıldı (RGB orantılı ölçek, ton sabit) → #956D0B, ~4.7:1.
    // KAYNAK (2026-10-02): vakifbank.com.tr/Templates/Default/assets/img/
    // logo.svg (fill #FDB913) + site CSS'inde en sık renk (×149).
    color: Color(0xFF956D0B),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'teb',
    name: 'TEB',
    // TEB / BNP Paribas yeşili #00915A beyazla ~4.0:1, eşiğin altında;
    // aynı tonda hafif koyultuldu → #008553, ~4.7:1.
    // KAYNAK (2026-10-02): teb.com.tr HTML'inde en sık marka rengi (×15);
    // logo PNG'si (images/TEB/fLogo.png) aynı yeşil ailesini veriyor.
    // Commons'taki "TEB logo.svg" eski mavi logo (#164194), güncel değil.
    color: Color(0xFF008553),
    country: 'TR',
    currency: 'TRY',
  ),
  BankBrand(
    key: 'ing',
    name: 'ING',
    // ING turuncusu #FF6200 beyazla ~3.0:1 — geçmez. Aynı tonda koyultuldu
    // → #C94D00, ~4.6:1; hâlâ "ING turuncusu" diye okunuyor.
    // KAYNAK (2026-10-02): ing.com.tr/documents/IngBank/assets/css/ui.css
    // (#FF6200 ×27) ve site.css; ING Group'un küresel turuncusuyla aynı.
    color: Color(0xFFC94D00),
    country: 'TR',
    currency: 'TRY',
  ),

  // ── Azerbaycan ─────────────────────────────────────────────────────────
  BankBrand(
    key: 'kapital',
    name: 'Kapital Bank',
    // Kapital Bank kırmızısı #B61D29 (2025 logosu). Beyazla ~6.6:1.
    // KAYNAK (2026-10-02): İKİNCİL — Commons "Kapital Bank logo 2025.png"
    // (doygun piksellerin tamamı #B61D29). kapitalbank.az Cloudflare
    // doğrulaması istiyor, sunucudan alınamadı; /az yolu Birbank temasına
    // yönleniyor. Eski logo (Commons SVG) bordo #6A062B + kırmızı #E0262C.
    color: Color(0xFFB61D29),
    country: 'AZ',
    currency: 'AZN',
  ),
  BankBrand(
    key: 'pasha',
    name: 'PAŞA Bank',
    // PAŞA Bank yeşili #007D57. Beyazla ~5.2:1, olduğu gibi.
    // KAYNAK (2026-10-02): pashabank.az/favicon.svg (fill #007D57 ×4,
    // yanında kırmızı vurgu #CF3A4B) + sitenin sohbet eklentisine verdiği
    // theme_color aynı değer.
    color: Color(0xFF007D57),
    country: 'AZ',
    currency: 'AZN',
  ),
  BankBrand(
    key: 'birbank',
    name: 'Birbank',
    // Birbank, Kapital Bank'ın dijital markası. SİYAH zemin kullanıcı
    // tarifinden — DOĞRULANAMADI (birbank.az kart görsellerini JS ile
    // yüklüyor); yaklaşık ton, uygulamanın mürekkebiyle (#111) karışmasın
    // diye bir tık açık antrasit.
    color: Color(0xFF161616),
    country: 'AZ',
    currency: 'AZN',
    // NEDEN split: siyah → kırmızı köşegen, tarif edilen görünüm bu; ayrıca
    // kırmızı Kapital kartının yanında Birbank'ı ayırıyor. Kırmızı #FF0039
    // beyazla ~4.0:1, eşiğin altında; aynı tonda hafif koyultuldu →
    // #E80034, ~4.7:1 — simge ve rozet onun üstüne düşüyor.
    // KAYNAK (2026-10-02): birbank.az/file/new_logo_*.svg (fill #FF0039);
    // site CSS değişkeni --red #BC0C19, theme-color #DF3A4C (UI tonları).
    style: CardStyle.split,
    accents: [Color(0xFFE80034)],
  ),
  BankBrand(
    key: 'abb',
    name: 'ABB',
    // Azərbaycan Beynəlxalq Bankı mavisi #0056C1. Beyazla ~6.8:1.
    // KAYNAK (2026-10-02): abb-bank.az theme-color + mask-icon rengi
    // (ikisi de #0056C1); Commons "ABB Logo.png" #0057C2 (1 birim fark).
    color: Color(0xFF0056C1),
    country: 'AZ',
    currency: 'AZN',
  ),

  // ── Kazakistan ─────────────────────────────────────────────────────────
  BankBrand(
    key: 'kaspi',
    name: 'Kaspi',
    // NEDEN altın, kırmızı değil: Kaspi'nin logosu kırmızı (#F14635 —
    // kaspi.kz/favicon/icon.svg, 2026-10-02) ama herkesin cebindeki kart
    // "Kaspi Gold" — altın metalik. Kullanıcı kartını altından tanıyor.
    // ALTIN TONU DOĞRULANAMADI: kartın altını için yayımlanmış bir hex yok,
    // yaklaşık ton (≈ #CFA54C, sarıya kaçmayan sıcak altın); mürekkeple
    // ~7.9:1. Metal gradyanının en koyu durağı da eşiği geçer
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
    // Halyk yeşili #008669 (logo; yanında sarı #F8AE00). Beyazla ~4.55:1,
    // sınırda ama geçiyor; koyulaştırmadık.
    // KAYNAK (2026-10-02): halykbank.kz/themes/halyk/assets/images/logo.svg
    // (fill ×2); favicon.svg komşu ton #00896B.
    color: Color(0xFF008669),
    country: 'KZ',
    currency: 'KZT',
  ),
  BankBrand(
    key: 'freedom',
    name: 'Freedom Bank',
    // Freedom yeşili #02B140 (logo kalkanının parlak yeşili) beyazla ~2.9:1
    // — geçmez. Aynı tonda koyultuldu → #028731, ~4.7:1. Logonun koyu
    // tonu #164734 de var ama kartı tanıtan parlak yeşil.
    // KAYNAK (2026-10-02): bankffin.kz/images/logo.svg (fill #02B140 +
    // #164734).
    color: Color(0xFF028731),
    country: 'KZ',
    currency: 'KZT',
  ),
  BankBrand(
    key: 'jusan',
    name: 'Jusan',
    // Jusan kehribarı #EDB110 beyazla ~1.9:1 — geçmez. Aynı tonda
    // koyultuldu → #936E0A, ~4.7:1. "Turuncu #F28C00" sanılmıştı; eski
    // logo turuncuydu (Commons "Jusan Bank.png" #FF6700), güncel marka
    // sarı-kehribar.
    // KAYNAK (2026-10-02): jusan.kz/favicon/favicon.svg (fill #EDB110 ×4)
    // + site HTML'inde aynı değer.
    color: Color(0xFF936E0A),
    country: 'KZ',
    currency: 'KZT',
  ),

  // ── Rusya ──────────────────────────────────────────────────────────────
  BankBrand(
    key: 'tbank',
    name: 'T-Bank',
    // NEDEN siyah: T-Bank'ın kart karakteri koyu/siyah (sarı logo, siyah
    // plastik); sarıyı zemin yapmak beyaz yazıyla ~1.3:1, okunmaz,
    // koyultunca da hardal olup markayı kaybediyordu. SİYAHIN HEX'İ
    // DOĞRULANAMADI (kart plastiği için yayımlanmış değer yok), yaklaşık
    // ton: uygulamanın mürekkebi (#111) ile karışmasın diye bir tık açık
    // antrasit. Flat kaldı: siyah kartın karakteri düzlüğünde.
    // KAYNAK (2026-10-02): marka sarısı #FFDD2D — tbank.ru HTML'inde ×15
    // + Commons "T-Bank RU logo.svg" fill; sarı doğrulandı, zemin değil.
    color: Color(0xFF1E1E1E),
    country: 'RU',
    currency: 'RUB',
  ),
  BankBrand(
    key: 'sber',
    name: 'Sber',
    // Sber yeşili #21A038 beyazla ~3.4:1 — geçmez. Aynı tonda koyultuldu
    // → #1C862F, ~4.7:1.
    // KAYNAK (2026-10-02): Commons "Sberbank Logo 2020.svg" fill
    // rgb(12.94%, 62.75%, 21.96%) = #21A038 (ikincil kaynak: sberbank.ru
    // bu ağdan engelli, yalnız engel sayfası dönüyor).
    color: Color(0xFF1C862F),
    country: 'RU',
    currency: 'RUB',
  ),
  BankBrand(
    key: 'alfa',
    name: 'Alfa-Bank',
    // Alfa kırmızısı #EF3124 beyazla ~4.1:1 — sınırın altında. Aynı tonda
    // hafif koyultuldu → #DE2E21, ~4.7:1.
    // KAYNAK (2026-10-02): alfabank.ru mask-icon rengi + favicon SVG fill
    // (ikisi de #EF3124), HTML'de ×14.
    color: Color(0xFFDE2E21),
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
