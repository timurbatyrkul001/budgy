import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/redesign_l10n.dart';
import 'paywall_sheet.dart';
import 'pro_state.dart';

/// Pro'ya kilitli bir ekranı sarar.
///
/// Kilitliyken içerik SİLİNMEZ, bulanıklaştırılır: kullanıcı kendi verisinin
/// orada durduğunu görür, sadece okuyamaz. Boş bir "Pro al" ekranı göstermek
/// aynı işi yapar ama neyi kaçırdığını anlatmaz — dönüşüm oranı da düşer.
///
/// Bulanık katman [IgnorePointer] ile etkileşime kapalı; altındaki ekranın
/// düğmelerine yanlışlıkla basılamaz.
class ProGate extends ConsumerWidget {
  const ProGate({super.key, required this.feature, required this.child});

  final ProFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [proUnlockedProvider]: kProEnabled kapalıyken (1.0) herkes için true —
    // kilit hiç çizilmez. Bkz. pro_state.dart'taki açıklama.
    if (ref.watch(proUnlockedProvider)) return child;
    final rs = ref.watch(rsProvider);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: child,
            ),
          ),
        ),
        // Bulanık içeriğin üstünde kâğıt renginde bir perde ([Ex.bg]).
        // Koyu zeminde bu katman "karartma"ydı; krem zeminde tersine, içeriği
        // kâğıda gömer: üstte hafif ki başlık/grafik soluk soluk seçilsin,
        // altta neredeyse opak ki kilit kartı temiz bir zemine otursun.
        // Açık renkli bulanık içerik koyu olana göre daha çok sızdığı için
        // alfalar eski 0.25/0.82'den yukarı çekildi.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Ex.bg.withValues(alpha: 0.55),
                    Ex.bg.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: _UnlockCard(
            rs: rs,
            onTap: () => showPaywall(context, feature),
          ),
        ),
        // Kilitli ekrandan çıkış: bulanık katman tıklamaları yuttuğu için
        // geri düğmesi burada ayrıca duruyor.
        Positioned(
          left: 20,
          top: 8,
          child: ExBackButton(onTap: () => Navigator.of(context).maybePop()),
        ),
      ],
    );
  }
}

class _UnlockCard extends StatelessWidget {
  const _UnlockCard({required this.rs, required this.onTap});

  final RS rs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Ex.surface,
        borderRadius: BorderRadius.circular(Ex.cardRadius),
        border: Border.all(color: Ex.borderHi),
        // Kart kâğıt perdenin üstünde yüzer: koyu zemindeki ağır siyah gölge
        // (%50) krem üstünde çamur gibi dururdu. Mürekkebin düşük alfalı hâli
        // kartı zeminden ayırmaya yeter.
        boxShadow: [
          BoxShadow(
            color: Ex.text.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Ex.brand.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(Ex.iconRadius),
                ),
                child: const Icon(Icons.lock_rounded, size: 18, color: Ex.mint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rs.proLocked,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Ex.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rs.paywallSubtitle,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Ex.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Ex.brand,
                foregroundColor: Ex.onBrand,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Ex.buttonRadius),
                ),
              ),
              child: Text(
                rs.paywallTrialTpl.replaceFirst('{days}', '$kProTrialDays'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── eylem kilidi ────────────────────────────────────────────────────────────
//
// Her Pro özelliği tam ekran bulanıklığa uygun değil. Fiş tarama ve sesli
// giriş gibi TEK DÜĞMELİK özelliklerde düğme yerinde durur (gizlenen özellik
// satılamaz), üstünde küçük bir "Pro" rozeti olur ve basınca paywall açılır.

/// Pro gerektiren bir eylemin kapısı. Kullanıcı Pro ise `true` döner ve
/// çağıran eylemi yapar; değilse paywall'ı açıp `false` döner. Böylece
/// kilitli her yerden çıkış yolu paywall'dır, çıkmaz sokak kalmaz.
///
/// Paywall kapandıktan sonra da `false` döner: abonelik satın alma akışı
/// (RevenueCat) bağlanınca [isProProvider] değişecek, kullanıcı düğmeye
/// yeniden basar. Paywall'dan dönüşte eylemi otomatik başlatmak sürpriz
/// olurdu (ör. kamera birden açılır).
Future<bool> requirePro(
  BuildContext context,
  WidgetRef ref,
  ProFeature feature,
) async {
  // kProEnabled kapalıyken (1.0) herkes için true: paywall hiç açılmaz.
  if (ref.read(proUnlockedProvider)) return true;
  await showPaywall(context, feature);
  return false;
}

/// Not: Burada bir zamanlar `ProBadge` / `ProBadged` vardı — kilitli
/// düğmelerin köşesine iliştirilen küçük "Pro" etiketi. Kaldırıldı:
/// arayüzde kilidi rozet değil, basınca açılan paywall anlatıyor.
/// Rozetler ekranı rozetle dolduruyordu ve satış yapmıyordu.
