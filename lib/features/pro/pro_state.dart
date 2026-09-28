import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preview.dart';
import '../envelopes/budget_repository.dart';

// Pro aboneliğinin durumu ve satılan planlar.
//
// ŞİMDİLİK YEREL: gerçek abonelik RevenueCat üzerinden gelecek. O zaman
// değişecek tek yer isProProvider ile ProPlan fiyatlarıdır — paywall ve
// kilitli ekranlar olduğu gibi kalır. Apple Developer hesabı onaylanmadan
// mağazada ürün tanımlanamadığı için şimdilik bağlanamıyor.

/// Kullanıcı Pro mu?
///
/// RevenueCat geldiğinde [ProStatus.build] `CustomerInfo.entitlements.active`
/// akışını dinleyecek; paywall ve kilitli ekranlar değişmeyecek.
final isProProvider =
    NotifierProvider<ProStatus, bool>(ProStatus.new);

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
  );

  const ProPlan({
    required this.priceLabel,
    required this.perMonthLabel,
    required this.billingNote,
    required this.savingPercent,
  });

  /// Dönem başına ödenen toplam.
  final String priceLabel;

  /// Aya bölünmüş hâli — iki planı karşılaştırılabilir kılan sayı.
  final String perMonthLabel;

  /// Yıllıkta "yılda bir kez şu kadar" notu; aylıkta yok.
  final String? billingNote;

  /// Aylığa göre kazanç yüzdesi; aylıkta yok.
  final int? savingPercent;
}

/// Ücretsiz deneme uzunluğu (gün). Mağazada tanımlanan değerle aynı olmalı.
const kProTrialDays = 14;
