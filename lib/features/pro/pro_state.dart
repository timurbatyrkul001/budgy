import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preview.dart';
import '../envelopes/budget_repository.dart';

// Pro aboneliğinin durumu ve satılan planlar.
//
// ŞİMDİLİK YEREL: gerçek abonelik RevenueCat üzerinden gelecek. O zaman
// değişecek tek yer isProProvider ile ProPlan fiyatlarıdır — paywall ve
// kilitli ekranlar olduğu gibi kalır. Apple Developer hesabı onaylanmadan
// mağazada ürün tanımlanamadığı için şimdilik bağlanamıyor.

// ── 1.0 sürümü: PRO KAPALI, HER ŞEY ÜCRETSİZ ────────────────────────────────
//
// Uygulama App Store'a çıkıyor ama satın alma altyapısı yok: pubspec'te ne
// `in_app_purchase` ne `purchases_flutter` var; paywall'daki "deneme başlat"
// düğmesi yalnız "yakında" diyor. Apple bunu iki ayrı gerekçeyle reddeder:
// bitmemiş özellik (Guideline 2.1) ve uygulama içi satın alma olmadan dijital
// ürün fiyatı göstermek (Guideline 3.1.1). Üstelik kilitli üç ekranı
// inceleyen kişi hiç göremezdi.
//
// Çözüm: SİLMEK DEĞİL, KAPATMAK. Pro mantığı (paywall, ProGate, requirePro,
// planlar, hak sahipliği akışı) olduğu gibi duruyor; tek bir anahtarın
// arkasına alındı. [kProEnabled] false iken:
//   • [proUnlockedProvider] herkes için `true` döner — ProGate içeriği
//     bulanıklaştırmaz, requirePro paywall açmadan `true` döner.
//   • Ayarlar'daki Pro tanıtım kartı ("Pro'ya geç" + "satın alımları geri
//     yükle") hiç çizilmez.
//   • Davranış kilitleri de açılır: tekrarlayan işlemler herkes için
//     üretilir (root_screen), nottan kategori otomasyonu herkes için
//     çalışır (quick_entry_screen).
//   • Paywall hiçbir yoldan açılmaz; fiyat, rozet, "Pro" etiketi görünmez.
//
// GERİ AÇMAK İÇİN:
//   1. Satın almayı bağla (RevenueCat / purchases_flutter): [ProStatus.build]
//      `CustomerInfo.entitlements.active`'i dinlesin, paywall'daki
//      `_subscribe` gerçek satın almayı başlatsın, [ProPlan] fiyatları
//      mağazadan gelsin.
//   2. [kProEnabled] = true yap. Başka kod değişikliği gerekmez: tüm kilitler
//      [proUnlockedProvider] üzerinden bu bayrağa bağlı.
//   3. test/widget/pro_locks_test.dart, paywall_test.dart, bottom_tabs_test
//      ("+" grubu) ve settings_hub_test (Pro kartı) "1.0 ücretsiz" hâlini
//      doğruluyor; kilitli davranışı yeniden yazmak gerekir (git geçmişinde
//      eski hâlleri duruyor).
//
// Dikkat: bu bayrak [isProProvider]'ı DEĞİŞTİRMEZ — o abonelik gerçeğini
// söylemeye devam eder (test harness'i de onu override ediyor). Kilitler
// "Pro mu?" yerine "Pro özellikleri bu kullanıcıya açık mı?" sorusunu
// [proUnlockedProvider]'a sorar.
const kProEnabled = false;

// ── 1.0 sürümü: AI KAPALI ───────────────────────────────────────────────────
//
// Üç AI özelliği var — fiş tarama (transactions/receipt_scan.dart), yaz/söyle
// hızlı giriş (transactions/ai_add_sheet.dart) ve bütçe dağılımını inceltme
// (core/ai/budget_advisor.dart, budget/budget_screen.dart'tan çağrılır).
// Hepsi `aiCall` Cloud Function'ı üzerinden Anthropic'e gider ve HER ÇAĞRI
// bize gerçek para eder.
//
// 1.0 ücretsiz çıkıyor ([kProEnabled] false): AI açık kalsaydı herkese
// bedava olurdu, faturayı biz öderdik. Üstelik fonksiyon deploy edilmedi,
// Secret Manager'da Anthropic anahtarı yok — bugün "fiş tara"ya basan
// herkes hata alırdı. Karar: 1.0'da AI YOK; 1.1'de Pro'nun ana satış
// gerekçesi olarak geri gelecek (ekonomisi docs/PRO_PLAN.md'de).
//
// Çözüm yine SİLMEK DEĞİL, KAPATMAK. [kAiEnabled] false iken:
//   • "+" seçim sayfası yalnız iki kart çizer (elle gider / elle gelir);
//     fiş tarama ve sesle ekleme kartları hiç yok (root/bottom_tab_bar.dart).
//   • [startReceiptScan] ve [showAiAdd] hiçbir şey yapmadan döner —
//     uyarı, "yakında", kilit yok; özellik yokmuş gibi.
//   • Bütçe "Öner" düğmesi yalnız yerel [autoSplit] sonucunu verir;
//     [BudgetAdvisor.refine] hiç çağrılmaz (budget_screen.dart).
//   • Ayarlar → Görünüm'deki "Sesli giriş dili" satırı çizilmez; kart
//     açıklaması "sesli giriş" demeyen varyanta düşer
//     (settings_appearance_screen.dart, RS.hubAppearanceBodyNoVoice).
//   • Onboarding'de "sesle söyle / fişi tara" geçen iki metin AI'sız
//     varyanta düşer (RS.introFastSubtitleNoAi, RS.rHabitBodyNoAi;
//     onboarding_flow.dart) ve hızlı giriş maketindeki mikrofon+tarayıcı
//     çipleri çizilmez (intro_mockups.dart).
//   • Android manifestinden RECORD_AUDIO çıkarıldı: kullanılmayan mikrofon
//     izni Play listesinde görünür. iOS Info.plist'teki dört kullanım
//     açıklaması (kamera, fotoğraf, mikrofon, konuşma tanıma) BİLİNÇLİ
//     OLARAK DURUYOR: image_picker ve speech_to_text pubspec'te kaldığı
//     için ikili bu API'lere başvuruyor; açıklama yoksa App Store Connect
//     yüklemeyi reddeder (ITMS-90683).
//     NOT: Fotoğraf açıklaması artık KULLANILIYOR — avatar galeriden
//     seçiliyor (settings_edit_avatar_screen.dart). iOS 14+ PHPicker izin
//     sormadan açıldığı için metin çoğu kullanıcıya yine görünmüyor, ama
//     eski sürümlerde ve kısıtlı durumlarda çıkabilir. Kamera, mikrofon ve
//     konuşma tanıma açıklamaları ise gerçekten kullanılmıyor.
//
// Dokunulmayanlar: nottan kategori (settings/category_resolver.dart) ve Siri
// eylemi (intents/) AI kullanmaz, yerel kurallarla çalışır — açık kalıyorlar.
//
// GERİ AÇMAK İÇİN (1.1):
//   1. functions/'ı deploy et, Secret Manager'a Anthropic anahtarını koy
//      (yoksa [ClaudeClient.available] false döner; kartlar görünür ama
//      "giriş yap" hatası verir).
//   2. [kAiEnabled] = true yap. Başka kod değişikliği gerekmez: yukarıdaki
//      her yer bu bayrağa bakar.
//   3. android/app/src/main/AndroidManifest.xml'e RECORD_AUDIO iznini geri
//      ekle — speech_to_text kendi manifestinde bildirmiyor (orada not var).
//   4. AI'yı Pro'ya bağla: [kProEnabled] ile birlikte aç; requirePro
//      kapıları bottom_tab_bar.dart'ta olduğu gibi duruyor.
//   5. Testler "1.0 AI'sız" hâli doğruluyor: test/widget/ai_hidden_test.dart,
//      pro_locks_test ("+" grubu), bottom_tabs_test ("+" grubu),
//      settings_hub_test (Görünüm açıklaması); receipt_scan_errors_test ve
//      voice_errors_test bayrağı atlayıp iç akışı sınıyor. AI'lı davranışın
//      eski testleri git geçmişinde.
const kAiEnabled = false;

/// Pro özellikleri bu kullanıcıya açık mı?
///
/// [kProEnabled] kapalıyken herkes için `true` (1.0: her şey ücretsiz);
/// açıkken [isProProvider]'ın değeri. Kilitlerin tek kapısı burası:
/// ProGate, requirePro, Ayarlar'daki Pro kartı ve davranış kilitleri
/// (tekrarlayan işlem üretimi, nottan kategori) hep buraya bakar.
final proUnlockedProvider = Provider<bool>(
  (ref) => !kProEnabled || ref.watch(isProProvider),
);

/// Kullanıcı Pro mu? (Abonelik gerçeği; kilitler için [proUnlockedProvider].)
///
/// RevenueCat geldiğinde [ProStatus.build] `CustomerInfo.entitlements.active`
/// akışını dinleyecek; paywall ve kilitli ekranlar değişmeyecek.
final isProProvider = NotifierProvider<ProStatus, bool>(ProStatus.new);

/// Abonelik durumu. Yazılabilir olması bilinçli: önizlemede ve testte
/// [set] ile açılıp kapanabiliyor.
class ProStatus extends Notifier<bool> {
  @override
  bool build() {
    // Sunucu tarafı hak sahipliği: users/{uid}/entitlements/pro.
    // Kurallarda istemciye salt okunur — geliştirici ve davetli test
    // hesapları konsoldan açılır, mağazadan indiren kullanıcı açamaz.
    // RevenueCat bağlanınca abonelik durumu buraya OR'lanacak.
    ref.listen(proEntitlementProvider, (_, next) {
      final granted = next.value ?? false;
      if (granted) state = true;
    }, fireImmediately: true);

    return kPreviewPro || (ref.read(proEntitlementProvider).value ?? false);
  }

  void set(bool value) => state = value;
}

/// Hak sahipliği belgesinin akışı. Hata/boş durumda false döner.
final proEntitlementProvider = StreamProvider<bool>((ref) {
  return ref.watch(budgetRepositoryProvider).watchProEntitlement();
});

/// Pro'ya kilitli özellikler. Kilit eklerken buraya bir madde yaz ki
/// paywall'daki liste ile gerçek kilitler aynı yerden beslensin.
enum ProFeature {
  /// Analiz ekranı: trendler, kategori dağılımı, içgörü kartları.
  analytics,

  /// Fiş tarama ve sesli giriş (bize gerçek AI maliyeti çıkaran özellikler).
  aiEntry,

  /// Tekrarlayan işlemler ve kategori otomasyonu.
  automation,
}

/// Satılan planlar. Fiyatlar şimdilik sabit — RevenueCat bağlandığında
/// mağazadan (yerel para birimiyle) gelecek, çünkü App Store fiyatı
/// kullanıcının ülkesine göre değişir ve elle yazılan fiyat yanıltıcı olur.
enum ProPlan {
  monthly(
    priceLabel: '₺69,99',
    perMonthLabel: '₺69,99',
    billingNote: null,
    savingPercent: null,
  ),
  yearly(
    priceLabel: '₺569,00',
    perMonthLabel: '₺47,42',
    billingNote: '₺569,00',
    savingPercent: 32,
  ),

  /// Tek seferlik satın alma (App Store'da non-consumable). Abonelik değil:
  /// yenilenmez, deneme süresi yok. [perMonthLabel] burada anlamsız — aya
  /// bölünecek bir dönem yok — o yüzden [priceLabel] ile aynı tutuluyor;
  /// paywall [isLifetime] üzerinden "ayda" etiketini gizleyip tek fiyatı
  /// gösterir. Alan yapısı diğer planlarla aynı kalsın diye null yapmadık.
  lifetime(
    priceLabel: '₺3.999,99',
    perMonthLabel: '₺3.999,99',
    billingNote: null,
    savingPercent: null,
  );

  const ProPlan({
    required this.priceLabel,
    required this.perMonthLabel,
    required this.billingNote,
    required this.savingPercent,
  });

  /// Dönem başına ödenen toplam (ömür boyunda: tek seferlik bedel).
  final String priceLabel;

  /// Aya bölünmüş hâli — abonelikleri karşılaştırılabilir kılan sayı.
  /// Ömür boyu planda [priceLabel] ile aynıdır, bkz. [lifetime].
  final String perMonthLabel;

  /// Yıllıkta "yılda bir kez şu kadar" notu; aylık ve ömür boyunda yok.
  final String? billingNote;

  /// Aylığa göre kazanç yüzdesi; yalnız yıllıkta var.
  final int? savingPercent;

  /// Tek seferlik satın alma mı? Paywall'da CTA metni, ücretlendirme notu
  /// ve fiyat gösterimi buna göre değişir.
  bool get isLifetime => this == ProPlan.lifetime;
}

/// Ücretsiz deneme uzunluğu (gün). Mağazada tanımlanan değerle aynı olmalı.
const kProTrialDays = 14;
