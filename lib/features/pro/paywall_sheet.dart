import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/motion.dart';
import '../../core/redesign_l10n.dart';
import '../profile/terms_of_use_screen.dart';
import 'pro_state.dart';

/// Pro paywall'ı açar. [feature] hangi kilidin tetiklediğini söyler —
/// başlık ona göre değişir, çünkü "analizi aç" demek "Pro al" demekten
/// çok daha ikna edici: kullanıcı tam o an ne istediğini biliyor.
Future<void> showPaywall(BuildContext context, ProFeature feature) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaywallSheet(feature: feature),
  );
}

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet({required this.feature});

  final ProFeature feature;

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  // Yıllık önde: aylığı seçen kullanıcı bilerek seçsin, varsayılan olarak
  // düşmesin. Mağaza vitrinlerinde de standart olan düzen bu.
  ProPlan _plan = ProPlan.yearly;

  String _title(RS rs) => switch (widget.feature) {
        ProFeature.analytics => rs.paywallTitleAnalytics,
        ProFeature.aiEntry => rs.paywallTitleAi,
        ProFeature.automation => rs.paywallTitleAutomation,
      };

  Future<void> _subscribe() async {
    final rs = ref.read(rsProvider);
    // RevenueCat bağlanana kadar satın alma yok; sessizce hiçbir şey
    // yapmak yerine durumu açıkça söylüyoruz.
    showErrorSnack(context, rs.paywallSoon);
  }

  Future<void> _restore() async {
    final rs = ref.read(rsProvider);
    showErrorSnack(context, rs.paywallSoon);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Ex.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(title: _title(rs), rs: rs),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  for (var i = 0; i < _benefits(rs).length; i++)
                    _BenefitRow(
                      icon: _benefits(rs)[i].$1,
                      text: _benefits(rs)[i].$2,
                    ).enterUp(context, index: i),
                  const SizedBox(height: 18),
                  for (final plan in ProPlan.values) ...[
                    _PlanRow(
                      plan: plan,
                      rs: rs,
                      selected: _plan == plan,
                      onTap: () => setState(() => _plan = plan),
                    ),
                    if (plan != ProPlan.values.last)
                      const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _subscribe,
                      style: FilledButton.styleFrom(
                        backgroundColor: Ex.brand,
                        foregroundColor: Ex.onBrand,
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Ex.buttonRadius)),
                      ),
                      child: Text(
                        rs.paywallStartTrialTpl
                            .replaceFirst('{days}', '$kProTrialDays'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Apple, satın alımları geri yükleme yolunu ZORUNLU
                  // tutuyor — cihaz değiştiren kullanıcı buradan erişir.
                  TextButton(
                    onPressed: _restore,
                    child: Text(rs.paywallRestore,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Ex.textSoft)),
                  ),
                  const SizedBox(height: 6),
                  // Otomatik yenileme bildirimi + Kullanım Şartları
                  // bağlantısı: ikisi de Apple'ın abonelik şartı.
                  Text(
                    rs.paywallAutoRenew,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11.5, height: 1.5, color: Ex.textFaint),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const TermsOfUseScreen()),
                    ),
                    child: Text(
                      rs.paywallTerms,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: Ex.textSoft,
                        decoration: TextDecoration.underline,
                        decorationColor: Ex.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<(IconData, String)> _benefits(RS rs) => [
        (Icons.insights_rounded, rs.paywallBenefitAnalytics),
        (Icons.document_scanner_rounded, rs.paywallBenefitScan),
        (Icons.mic_rounded, rs.paywallBenefitVoice),
        (Icons.repeat_rounded, rs.paywallBenefitRecurring),
      ];
}

/// Üst blok: marka gradyanı + deneme rozeti + başlık.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.rs});

  final String title;
  final RS rs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C6B4E), Color(0xFF0E2E24)],
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.close_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              rs.paywallTrialTpl.replaceFirst('{days}', '$kProTrialDays'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.15,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rs.paywallSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, height: 1.45, color: Ex.onGlowMuted),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Ex.surfaceHi,
              borderRadius: BorderRadius.circular(Ex.iconRadius),
            ),
            child: Icon(icon, size: 18, color: Ex.mint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14.5, height: 1.35, color: Ex.text)),
          ),
        ],
      ),
    );
  }
}

/// Tek plan satırı — seçiliyken marka kenarlığı ve hafif dolgu.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.rs,
    required this.selected,
    required this.onTap,
  });

  final ProPlan plan;
  final RS rs;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        plan == ProPlan.yearly ? rs.paywallYearly : rs.paywallMonthly;

    return Material(
      color: selected ? Ex.surfaceHi : Ex.surface,
      borderRadius: BorderRadius.circular(Ex.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ex.cardRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Ex.cardRadius),
            border: Border.all(
              color: selected ? Ex.brand : Ex.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? Ex.brand : Ex.textFaint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Ex.text)),
                        ),
                        if (plan.savingPercent != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Ex.brand,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              rs.paywallSaveTpl
                                  .replaceFirst('{n}', '${plan.savingPercent}'),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Ex.onBrand),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (plan.billingNote != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        rs.paywallBilledYearlyTpl
                            .replaceFirst('{price}', plan.billingNote!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: Ex.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(plan.perMonthLabel,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Ex.text)),
                  Text(rs.paywallPerMonth,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: Ex.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
