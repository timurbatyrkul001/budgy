import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../home/fx_providers.dart';
import '../onboarding/onboarding_flow.dart';
import '../profile/currency_screen.dart';
import '../profile/language_screen.dart';
import '../pro/pro_state.dart';
import 'app_settings.dart';
import 'settings_hub.dart';
import 'voice_language_screen.dart';

/// Görünüm — hub'daki "Uygulama" bölümünün alt ekranı.
///
/// İki kart:
///  1. Tercihler — tuş takımı düzeni, dil, para birimi, sesli giriş dili.
///     Dördü de "tercih" türünden, hiçbiri tehlikeli değil ve her satır
///     sağda mevcut değerini gösteriyor — kullanıcı ekrana girmeden ne
///     seçili olduğunu görür.
///  2. Kurulum — "Kurulum sihirbazını göster": onboarding'i yeniden açar.
///
/// BİLİNÇLİ OLARAK "TEMA" SATIRI YOK. Uygulama tek temalı (app.dart →
/// `ThemeMode.light`) ve ekranların büyük kısmı `Ex.*` derleme-zamanı
/// sabitleriyle boyanıyor (~910 kullanım); tema anahtarı koysak hiçbir şey
/// değişmezdi. Hiçbir işe yaramayan ayar, olmayan ayardan kötüdür — sahibin
/// kararı. Onboarding'in dünya seçimi de artık `themeMode` yazmıyor; alan ve
/// `themeModeProvider` 1.1 için yerinde bekliyor, burada okunmaz/yazılmaz.
///
/// AYNI SEBEPLE "YAZI KONTRASTINI ARTIR" ANAHTARI DA YOK (1.1'e ertelendi).
/// Anahtar `context.budgy` okuyan paleti değiştiriyordu — ama bu ekran dahil
/// ~50 ekran `Ex.*` ile boyanıyor; kullanıcı anahtarı çevirip çevirdiği
/// ekranda bile hiçbir fark görmüyordu. Çalışan yarısı bırakılsa daha kötü:
/// uygulamanın yarısı değişir, yarısı değişmez. Mekanizma duruyor
/// (`highContrastProvider`, `setHighContrast`, `BudgyColors.highContrast`,
/// app.dart'taki palet seçimi) — `Ex` çalışma zamanına taşınınca anahtar
/// buraya geri gelir. Test dosyası iki satırın da yokluğunu sınar.
class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  /// Onboarding'i yeniden aç — ama veriyi silmeden.
  ///
  /// Neden bayrağı sıfırlamak YETMİYOR: auth kapısı onboarding'i yalnız
  /// `onboardingDone != true && zarf yok` ise gösteriyor. Mevcut
  /// kullanıcının zarfları var; bayrağı düşürsek de kapı ana ekranda kalır.
  /// Bu yüzden akış buradan `Navigator.push` ile üste açılıyor —
  /// `auth_gate` değişmiyor, yeni kullanıcı mantığı olduğu gibi kalıyor.
  ///
  /// Akışın sonu ([OnboardingFlow]'un `_closeOnboarding`'i) route'u
  /// kapatmaz; yalnız `onboardingDone = true` yazar ve auth kapısının
  /// ekranı değiştirmesini bekler. Üste açılmış bir route'u kapı
  /// kapatamaz; o yüzden:
  ///   1. Açmadan önce bayrak `false` yapılır — böylece akışın bitişi
  ///      gerçek bir `false → true` geçişi olur.
  ///   2. [_OnboardingRerunHost] bu geçişi dinler ve köke kadar pop eder.
  ///   3. Route kapanınca bayrak koşulsuz `true` yazılır: akış bittiyse
  ///      zaten true (idempotent), yarıda bırakıldıysa (geri hareketi)
  ///      eski hâline döner — hesap "kurulmamış" görünmesin.
  ///
  /// Veri güvenliği: [OnboardingFlow] var olan preset'li kategorileri
  /// atlar, para birimi/cüzdan adı/başlangıç bakiyesi yalnız kullanıcı
  /// seçtiğinde ÜSTÜNE yazılır; hiçbir şey silinmez. Diyalog bunu açıkça
  /// söyler ki kimse bunu "her şeyi sıfırla" sanmasın.
  Future<void> _rerunOnboarding(BuildContext context, WidgetRef ref) async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ex.surface,
        title: Text(rs.rerunOnboardingDialogTitle),
        content: Text(rs.rerunOnboardingDialogBody,
            style: const TextStyle(color: Ex.text, height: 1.35)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(str.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(rs.rerunOnboardingConfirm,
                  style: const TextStyle(color: Ex.mint))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Repository'yi push'tan ÖNCE al: akış köke kadar pop edince bu ekran
    // da gidiyor, dispose'dan sonra `ref` kullanılamaz.
    final repo = ref.read(budgetRepositoryProvider);
    await repo.saveProfile({'onboardingDone': false});
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const _OnboardingRerunHost()),
    );
    // Route kapandı: ya akış bitti (bayrak zaten true → bu yazı idempotent
    // bir tekrar) ya da geri hareketiyle yarıda bırakıldı (bayrak false →
    // geri koy; bu kullanıcı zaten kurulmuştu, yarım sihirbaz onu bozmasın).
    // Önce okuyup sonra yazmak yerine koşulsuz yazıyoruz: iki durumda da
    // doğru sonuç aynı ve ekstra bir snapshot beklemeye gerek kalmıyor.
    await repo.setOnboardingDone();
  }

  Future<void> _pickKeypad(BuildContext context, WidgetRef ref) async {
    final rs = ref.read(rsProvider);
    final onTop = ref.read(keypadOneTwoThreeOnTopProvider);
    final picked = await showExSheet<bool>(
      context,
      SheetFrame(
        title: rs.keypadLayout,
        child: Column(
          children: [
            _OptionRow(
                label: rs.keypadBottom,
                selected: !onTop,
                onTap: () => Navigator.of(context).pop(false)),
            _OptionRow(
                label: rs.keypadTop,
                selected: onTop,
                onTap: () => Navigator.of(context).pop(true)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(budgetRepositoryProvider)
        .saveProfile({'keypadLayout': picked ? 'top' : 'bottom'});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final language = ref.watch(languageProvider).value ?? AppLanguage.en;
    final currency = ref.watch(currencyCodeProvider);
    final keypadTop = ref.watch(keypadOneTwoThreeOnTopProvider);
    final voice = ref.watch(voiceLocaleProvider) ?? rs.voiceAppLanguage;

    return SettingsPage(
      hero: SettingsHero(
        icon: Icons.tune_rounded,
        title: rs.hubAppearance,
        // 1.0: AI kapalı — "sesli giriş" demeyen açıklama (kAiEnabled).
        body: kAiEnabled ? rs.hubAppearanceBody : rs.hubAppearanceBodyNoVoice,
      ),
      children: [
        SettingsCard(label: rs.appearancePrefsLabel, rows: [
          SettingsRow(
            icon: Icons.dialpad_rounded,
            title: rs.keypadLayout,
            value: keypadTop ? rs.keypadTop : rs.keypadBottom,
            onTap: () => _pickKeypad(context, ref),
          ),
          SettingsRow(
            icon: Icons.language_rounded,
            title: str.languageTitle,
            value: language.title,
            onTap: () => pushSettings(context, const LanguageScreen()),
          ),
          SettingsRow(
            icon: Icons.payments_rounded,
            title: str.currencyTitle,
            value: currency,
            onTap: () => pushSettings(context, const CurrencyScreen()),
          ),
          // 1.0: AI kapalı — sesli giriş yokken dil seçtirmek özelliği ele
          // verir; satır hiç çizilmez. Bkz. pro_state.dart, kAiEnabled.
          if (kAiEnabled)
            SettingsRow(
              icon: Icons.mic_rounded,
              title: rs.voiceLanguage,
              value: voice,
              onTap: () => pushSettings(context, const VoiceLanguageScreen()),
            ),
        ]),
        // "Okunabilirlik" kartı (yüksek kontrast anahtarı) bilinçli olarak
        // yok — sınıf notuna bak. Geri geldiğinde: ayrı kart, satırın tamamı
        // dokunulabilir (küçük anahtara nişan almak görme zorluğu çekenler
        // için en zor hareket); RS metinleri (`highContrastTitle/Body`,
        // `appearanceReadabilityLabel`) üç dilde hazır duruyor.
        // Eylem satırı: ikon + açıklama + ok. [SettingsActionRow] (ikonsuz
        // yeşil metin) "tümünü aç" gibi küçük eylemler için; burada
        // kullanıcı neyin açılacağını ve verisine dokunmayacağını okumalı.
        SettingsCard(label: rs.appearanceSetupLabel, rows: [
          SettingsRow(
            icon: Icons.auto_awesome_rounded,
            title: rs.rerunOnboardingTitle,
            description: rs.rerunOnboardingBody,
            onTap: () => _rerunOnboarding(context, ref),
          ),
        ]),
      ],
    );
  }
}

/// Yeniden açılan onboarding'in kabuğu: akış `onboardingDone`'ı true yapınca
/// köke kadar pop eder (auth kapısı ana ekranı zaten gösteriyor).
///
/// Neden [OnboardingFlow]'un içinde değil: onboarding klasörü yeni kullanıcı
/// akışıdır ve auth kapısına güvenir; "üste açıldım, kendimi kapatmalıyım"
/// bilgisi oraya ait değil. Kabuk bu ekranın özelidir ve yalnız buradan
/// kullanılır.
class _OnboardingRerunHost extends ConsumerWidget {
  const _OnboardingRerunHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<bool>>(onboardingDoneProvider, (prev, next) {
      // Yalnız true'ya GEÇİŞ: ekran açılırken gelen ilk false'a ya da
      // olası tekrar false'a tepki verme.
      if (next.value == true && prev?.value != true) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    return const OnboardingFlow();
  }
}

/// Alt sayfadaki seçenek satırı (tuş takımı düzeni).
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ExCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? Ex.mint : Ex.text)),
              ),
              if (selected) const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
            ],
          ),
        ),
      );
}
