import 'package:flutter/material.dart';

import '../features/envelopes/envelope.dart';
import 'category_catalog.dart';

/// Kategori görseli: yuvarlak renkli zemin + beyaz Material simgesi.
/// Katalog (ve eski onboarding preset) anahtarlarının her biri için bir
/// simge + renk; bölüm bir aile olarak okunsun diye renkler bölüme göre
/// verilir (günlük: sıcak, ulaşım: mavi/sarı, ev: kırmızı/amber, sağlık:
/// turkuaz/limon, abonelik: mor...). Marka yeşili (#25BE86) seçili/aktif
/// durum için ayrılmıştır — paletteki hiçbir ton ona yakın değil.
class CategoryVisual {
  const CategoryVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// Koyu zümrüt zeminde birbirinden ayırt edilebilen, üstünde beyaz glif
/// okunur 12 ton.
abstract class CategoryPalette {
  static const coral = Color(0xFFE85D5D);
  static const orange = Color(0xFFF0863A);
  static const amber = Color(0xFFD9A020);
  static const yellow = Color(0xFFC9B227);
  static const lime = Color(0xFF8DB03A);
  static const teal = Color(0xFF2299AE);
  static const sky = Color(0xFF3F8FE0);
  static const indigo = Color(0xFF5C6CE0);
  static const violet = Color(0xFF8E5FE0);
  static const magenta = Color(0xFFC85AB8);
  static const caramel = Color(0xFFB07A48);
  static const slate = Color(0xFF6F7F92);

  static const all = [
    coral, orange, amber, yellow, lime, teal, sky, indigo, violet, magenta,
    caramel, slate,
  ];
}

const _visuals = <String, CategoryVisual>{
  // Günlük — sıcak tonlar
  'groceries': CategoryVisual(Icons.shopping_cart_rounded, CategoryPalette.amber),
  'restaurants': CategoryVisual(Icons.restaurant_rounded, CategoryPalette.orange),
  'delivery': CategoryVisual(Icons.delivery_dining_rounded, CategoryPalette.coral),
  'coffee': CategoryVisual(Icons.local_cafe_rounded, CategoryPalette.caramel),
  // Ulaşım — mavi / sarı
  'publicTransport': CategoryVisual(Icons.directions_bus_rounded, CategoryPalette.indigo),
  'fuel': CategoryVisual(Icons.local_gas_station_rounded, CategoryPalette.amber),
  'taxi': CategoryVisual(Icons.local_taxi_rounded, CategoryPalette.yellow),
  'car': CategoryVisual(Icons.directions_car_rounded, CategoryPalette.sky),
  // Ev & faturalar — kırmızı / amber
  'rent': CategoryVisual(Icons.home_rounded, CategoryPalette.coral),
  'utilities': CategoryVisual(Icons.bolt_rounded, CategoryPalette.amber),
  'internet': CategoryVisual(Icons.wifi_rounded, CategoryPalette.orange),
  'home': CategoryVisual(Icons.chair_rounded, CategoryPalette.caramel),
  // Alışveriş — pembe / mor
  'clothes': CategoryVisual(Icons.checkroom_rounded, CategoryPalette.magenta),
  'electronics': CategoryVisual(Icons.devices_rounded, CategoryPalette.indigo),
  'online': CategoryVisual(Icons.shopping_bag_rounded, CategoryPalette.violet),
  'personalCare': CategoryVisual(Icons.spa_rounded, CategoryPalette.coral),
  // Yaşam
  'entertainment': CategoryVisual(Icons.movie_rounded, CategoryPalette.violet),
  'travel': CategoryVisual(Icons.flight_rounded, CategoryPalette.sky),
  'hobbies': CategoryVisual(Icons.palette_rounded, CategoryPalette.orange),
  'sport': CategoryVisual(Icons.fitness_center_rounded, CategoryPalette.teal),
  // Sağlık — turkuaz / limon
  'pharmacy': CategoryVisual(Icons.medication_rounded, CategoryPalette.lime),
  'doctor': CategoryVisual(Icons.medical_services_rounded, CategoryPalette.teal),
  // Finans — gri-mavi / indigo
  'bankFees': CategoryVisual(Icons.account_balance_rounded, CategoryPalette.slate),
  'insurance': CategoryVisual(Icons.shield_rounded, CategoryPalette.indigo),
  'taxes': CategoryVisual(Icons.receipt_long_rounded, CategoryPalette.coral),
  'loans': CategoryVisual(Icons.credit_card_rounded, CategoryPalette.amber),
  // Aile & diğer
  'gifts': CategoryVisual(Icons.card_giftcard_rounded, CategoryPalette.magenta),
  'donations': CategoryVisual(Icons.volunteer_activism_rounded, CategoryPalette.teal),
  'education': CategoryVisual(Icons.school_rounded, CategoryPalette.sky),
  'pets': CategoryVisual(Icons.pets_rounded, CategoryPalette.caramel),
  'kids': CategoryVisual(Icons.child_care_rounded, CategoryPalette.yellow),
  'other': CategoryVisual(Icons.category_rounded, CategoryPalette.slate),
  // Abonelikler — morlar
  'streaming': CategoryVisual(Icons.live_tv_rounded, CategoryPalette.violet),
  'music': CategoryVisual(Icons.music_note_rounded, CategoryPalette.magenta),
  'cloud': CategoryVisual(Icons.cloud_rounded, CategoryPalette.indigo),
  'games': CategoryVisual(Icons.sports_esports_rounded, CategoryPalette.violet),
  'software': CategoryVisual(Icons.extension_rounded, CategoryPalette.sky),
  'otherSubs': CategoryVisual(Icons.autorenew_rounded, CategoryPalette.slate),
  // Eski onboarding preset'leri (katalog dışı anahtarlar)
  'food': CategoryVisual(Icons.lunch_dining_rounded, CategoryPalette.orange),
  'transport': CategoryVisual(Icons.commute_rounded, CategoryPalette.indigo),
  'health': CategoryVisual(Icons.favorite_rounded, CategoryPalette.teal),
  'savings': CategoryVisual(Icons.savings_rounded, CategoryPalette.amber),
};

/// Katalog/preset anahtarının görseli; bilinmeyen anahtar → null.
CategoryVisual? categoryVisual(String? key) => key == null ? null : _visuals[key];

/// Kullanıcının kendi kategorileri emojisini korur (oluştururken seçer);
/// aynı boy daire içinde emoji, zemin ise zarf id'sinden türeyen SABİT
/// bir palet tonu — karışık listede tek sistem gibi görünsün.
Color envelopeTint(String seed) {
  var h = 0;
  for (final u in seed.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return CategoryPalette.all[h % CategoryPalette.all.length];
}

/// Zarfın görseli: preset anahtarı katalogda/preset'te varsa simge+renk,
/// yoksa null (emoji ile çizilir).
CategoryVisual? visualForEnvelope(Envelope e) => categoryVisual(e.presetKey);

/// Zarfın rengi — tembel göç: kayıtlı `color` varsa o; yoksa katalog
/// rengi; o da yoksa id'den türeyen ton. Ekranda hiçbir şey kaymaz, yazma
/// yalnız kullanıcı düzenleyince olur.
Color envelopeColor(Envelope e) {
  final i = e.colorIndex;
  if (i != null && i >= 0 && i < CategoryPalette.all.length) {
    return CategoryPalette.all[i];
  }
  return categoryVisual(e.presetKey)?.color ?? envelopeTint(e.id);
}

/// Zarfın bölümü — kayıtlı `section` varsa o, yoksa katalogdan türetilir;
/// katalog dışıysa null (bölümsüz).
String? envelopeSection(Envelope e) => e.section ?? sectionOfCatalogKey(e.presetKey);

/// Katalog anahtarının bölümü (eski preset'ler: food→everyday,
/// transport→transport, health→health, savings→finance).
String? sectionOfCatalogKey(String? key) {
  if (key == null) return null;
  for (final s in kCategoryCatalog) {
    if (s.items.any((i) => i.key == key)) return s.key;
  }
  return const {
    'food': 'everyday',
    'transport': 'transport',
    'health': 'health',
    'savings': 'finance',
  }[key];
}

/// Palet indeksi (kaydetmek için); renk palette yoksa null.
int? paletteIndexOf(Color c) {
  final i = CategoryPalette.all.indexOf(c);
  return i < 0 ? null : i;
}

/// Kullanıcı zarflarını bölüme göre gruplar: anahtar bölüm (null =
/// bölümsüz → "Kendi kategorilerin"). Sıra korunur.
Map<String?, List<Envelope>> groupBySection(Iterable<Envelope> envelopes) {
  final m = <String?, List<Envelope>>{};
  for (final e in envelopes) {
    m.putIfAbsent(envelopeSection(e), () => []).add(e);
  }
  return m;
}

/// Her katalog anahtarının bir görseli olduğunu garanti eden yardımcı
/// (testler için).
Iterable<String> visualKeys() => _visuals.keys;

bool hasVisualForAllCatalogItems() => kCategoryCatalog
    .every((s) => s.items.every((i) => _visuals.containsKey(i.key)));
