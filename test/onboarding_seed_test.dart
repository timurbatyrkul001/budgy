import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';

/// Onboarding'in para yazan adımları İKİ KEZ çalışmamalı.
///
/// Gerçek olay: son adım (`setDay`, transaction — çevrimdışı patlar) ağ
/// koptuğu için başarısız oluyor, kullanıcı hata şeridini görüp tekrar
/// deniyor ve başlangıç bakiyesi ikinci kez yazılıyordu. 5.000 ₺ giren
/// biri 10.000 ₺ ile açılıyordu. Kategoriler `presetKey` ile zaten
/// tekilleniyordu; korumasız olan yalnız para yazan iki çağrıydı.
void main() {
  group('onboardingSeeded', () {
    test('işaret yoksa yazmak serbest', () {
      expect(onboardingSeeded(null), isFalse);
      expect(onboardingSeeded(const {}), isFalse);
      expect(onboardingSeeded(const {'name': 'Timur'}), isFalse);
    });

    test('profildeki işaret tekrar yazmayı durdurur', () {
      expect(onboardingSeeded(const {kOnboardingSeededKey: true}), isTrue);
    });

    test('aynı oturumdaki tekrar deneme bellekten durdurulur', () {
      // Profil akışı daha tazelenmemiş olabilir; bellek kesin bilgi.
      expect(onboardingSeeded(null, inMemory: true), isTrue);
      expect(onboardingSeeded(const {}, inMemory: true), isTrue);
    });

    test('işaret true dışında bir değerse yok sayılır', () {
      // Yarım kalmış/bozuk veri yüzünden başlangıç bakiyesi SESSİZCE
      // atlanmasın: emin değilsek yazmak, yazmamaktan iyidir — ikizlenme
      // diğer korumalarda yakalanır, eksik bakiye hiç yakalanmaz.
      expect(onboardingSeeded(const {kOnboardingSeededKey: 'evet'}), isFalse);
      expect(onboardingSeeded(const {kOnboardingSeededKey: 1}), isFalse);
      expect(onboardingSeeded(const {kOnboardingSeededKey: false}), isFalse);
    });
  });

  group('missingWalletCodes', () {
    test('hiç cüzdan yoksa hepsi yazılır, sıra korunur', () {
      expect(missingWalletCodes(const [], const ['USD', 'EUR']),
          ['USD', 'EUR']);
    });

    test('ilk denemede yazılan cüzdan ikinci denemede atlanır', () {
      // Cüzdan zarfının `currency` alanı kendi işaretidir.
      expect(missingWalletCodes(const ['USD'], const ['USD', 'EUR']), ['EUR']);
    });

    test('hepsi varsa hiçbiri yazılmaz', () {
      expect(missingWalletCodes(const ['USD', 'EUR'], const ['USD', 'EUR']),
          isEmpty);
    });

    test('₺ zarflarının boş currency alanı karıştırmaz', () {
      // Normal kategoriler (market, kira) `currency` taşımaz.
      expect(missingWalletCodes(const ['', '', 'USD'], const ['USD', 'EUR']),
          ['EUR']);
    });

    test('istekte aynı kod iki kez geçse de bir kez döner', () {
      expect(missingWalletCodes(const [], const ['USD', 'USD']), ['USD']);
    });
  });
}
