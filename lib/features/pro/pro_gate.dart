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
    if (ref.watch(isProProvider)) return child;
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
        // Bulanık içeriğin üstünde okunabilirlik için hafif karartma.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Ex.bg.withValues(alpha: 0.25),
                    Ex.bg.withValues(alpha: 0.82),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
                child: const Icon(Icons.lock_rounded,
                    size: 18, color: Ex.mint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(rs.proLocked,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Ex.text)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(rs.paywallSubtitle,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.45, color: Ex.textMuted)),
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
                    borderRadius: BorderRadius.circular(Ex.buttonRadius)),
              ),
              child: Text(
                rs.paywallTrialTpl.replaceFirst('{days}', '$kProTrialDays'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
