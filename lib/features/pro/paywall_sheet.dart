import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/motion.dart';
import '../../core/redesign_l10n.dart';
import '../profile/privacy_policy_screen.dart';
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

/// Planların vitrindeki sırası: yıllık önde (varsayılan), aylık ortada,
/// ömür boyu sonda. Enum sırası (monthly, yearly, lifetime) mağaza ürün
/// sırasıdır; gösterim sırası bilinçli olarak farklı.
const _planOrder = [ProPlan.yearly, ProPlan.monthly, ProPlan.lifetime];

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

  // Her açılışta EN ÜSTTEN başlasın: kendi denetleyicimiz olmazsa
  // ScrollView konumunu rotanın PageStorage'ından geri yükleyip önceki
  // açılışta kalınan yere düşüyordu.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);

    // Sayfa yüksekliği sabit (ekranın %94'ü); içerik baştan sona tek
    // kaydırma: üstte marka paneli (kapat, marka kilidi, başlık, planlar,
    // ana düğme, not), altında faydalar ve en altta yasal bağlantılar.
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: const BoxDecoration(
          color: Ex.sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          controller: _scroll,
          primary: false,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandPanel(
                rs: rs,
                title: _title(rs),
                plan: _plan,
                onPlan: (p) => setState(() => _plan = p),
                onSubscribe: _subscribe,
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _BenefitGroups(rs: rs),
              ),
              _LegalLinks(rs: rs),
            ],
          ),
        ),
      ),
    );
  }
}

/// Üst panel: marka yeşili tek bir yuvarlatılmış kutu. İçinde sırayla kapat
/// düğmesi, marka kilidi (ikon + "Budgy" + "Pro" hapı), ortalanmış başlık ve
/// açıklama, üç plan satırı, ana düğme ve ücretlendirme notu.
///
/// Yeşil üstünde beyaz okunmuyor; metinler [_onPanel] (koyu), vurgular
/// [Ex.text] (açık). Yalnız Ex.* sabitleri, alfa ile tonlanmış.
/// Panel zemini koyu olduğu için üzerindeki metin ve ikonlar açık renk.
/// Tek yerden yönetiliyor ki zemin tonu değişince hepsi birlikte dönsün.
const _onPanel = Ex.text;

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({
    required this.rs,
    required this.title,
    required this.plan,
    required this.onPlan,
    required this.onSubscribe,
  });

  final RS rs;
  final String title;
  final ProPlan plan;
  final ValueChanged<ProPlan> onPlan;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    // Ömür boyu planda deneme süresi yok (tek seferlik ürünlerde mağaza
    // deneme sunmaz); düğme ve not ona göre değişir. Aboneliklerde deneme
    // + otomatik yenileme uyarısı.
    final cta = plan.isLifetime
        ? rs.paywallBuyLifetimeTpl.replaceFirst('{price}', plan.priceLabel)
        : rs.paywallStartTrialTpl.replaceFirst('{days}', '$kProTrialDays');
    final note = plan.isLifetime ? rs.paywallLifetimeNote : rs.paywallAutoRenew;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        // Düz parlak yeşil tüm paneli kaplayınca fazla baskındı. Ana ekranın
        // zemininde kullanılan koyu yeşil geçişin aynısı (bkz. ExBackground),
        // böylece paywall uygulamanın geri kalanıyla aynı dili konuşuyor.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F6E4D), Color(0xFF0A3B2A)],
        ),
        borderRadius: BorderRadius.circular(Ex.cardRadius + 4),
        border: Border.all(color: Ex.brand.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kapat: panelin sol üst köşesinde.
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: _onPanel.withValues(alpha: 0.12),
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: _onPanel,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _BrandLock(rs: rs),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.15,
              color: _onPanel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rs.paywallSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: _onPanel.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 20),
          for (final p in _planOrder) ...[
            _PlanRow(
              plan: p,
              rs: rs,
              selected: plan == p,
              onTap: () => onPlan(p),
            ),
            if (p != _planOrder.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          // Ana düğme: açık zeminli hap, koyu metin (panel zaten yeşil).
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: onSubscribe,
              style: FilledButton.styleFrom(
                backgroundColor: Ex.text,
                foregroundColor: Ex.onBrand,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(cta, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            note,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: _onPanel.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    ).enterUp(context);
  }
}

/// Marka kilidi: küçük uygulama ikonu + "Budgy" + yuvarlak "Pro" hapı.
class _BrandLock extends StatelessWidget {
  const _BrandLock({required this.rs});

  final RS rs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BudgyIcon(size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            rs.paywallBrand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: _onPanel,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: const BoxDecoration(
            color: _onPanel,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: Text(
            rs.paywallProPill,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Ex.mint,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tek plan satırı (panel içinde). Solda plan adı + varsa indirim rozeti,
/// altında fiyat satırı; SAĞDA radio. Seçili: açık kenarlık + dolu radio.
/// Seçili değil: hafif saydam dolgu, boş radio.
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
    final label = switch (plan) {
      ProPlan.yearly => rs.paywallYearly,
      ProPlan.monthly => rs.paywallMonthly,
      ProPlan.lifetime => rs.paywallLifetime,
    };
    // Fiyat satırı: aboneliklerde "₺47,42 / ay", yıllıkta ek olarak
    // "(yılda ₺569,00)"; ömür boyunda tek fiyat + "Tek seferlik".
    final price = plan.isLifetime
        ? plan.priceLabel
        : '${plan.perMonthLabel} / ${rs.paywallPerMonth}';
    final tail = plan.isLifetime
        ? rs.paywallOneTime
        : plan.billingNote == null
        ? null
        : rs.paywallBilledYearlyTpl.replaceFirst('{price}', plan.billingNote!);

    return Material(
      color: _onPanel.withValues(alpha: selected ? 0.16 : 0.09),
      borderRadius: BorderRadius.circular(Ex.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ex.buttonRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Ex.buttonRadius),
            border: Border.all(
              color: selected ? Ex.text : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: _onPanel,
                            ),
                          ),
                        ),
                        if (plan.savingPercent != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _onPanel,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              rs.paywallSaveTpl.replaceFirst(
                                '{n}',
                                '${plan.savingPercent}',
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Ex.mint,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _onPanel,
                            ),
                          ),
                          if (tail != null)
                            TextSpan(
                              text: '  $tail',
                              style: TextStyle(
                                color: _onPanel.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? Ex.text : _onPanel.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlıklı fayda grupları. Liste Budgy'nin GERÇEKTEN yaptığı
/// şeylerle sınırlı — burada olmayan bir özelliği vadetmek mağaza
/// incelemesinde ve iade taleplerinde geri döner.
class _BenefitGroups extends StatelessWidget {
  const _BenefitGroups({required this.rs});

  final RS rs;

  // Sıra referanstaki gibi: önce para/hesap, sonra otomasyon ve giriş
  // kolaylıkları, EN SON içgörüler. Insights'ı başa koymak yanlıştı.
  /// Madde: ikon, başlık, açıklama, henüz yok mu (rozet).
  List<(String, List<(IconData, String, String, bool)>)> _groups() => [
    (
      rs.paywallGroupSpaces,
      [
        (
          Icons.layers_rounded,
          rs.paywallSpacesMultiTitle,
          rs.paywallSpacesMultiDesc,
          true,
        ),
        (
          Icons.person_add_alt_1_rounded,
          rs.paywallSpacesSharedTitle,
          rs.paywallSpacesSharedDesc,
          true,
        ),
        (
          Icons.groups_rounded,
          rs.paywallSpacesFamilyTitle,
          rs.paywallSpacesFamilyDesc,
          true,
        ),
      ],
    ),
    (
      rs.paywallGroupMoney,
      [
        (
          Icons.currency_exchange_rounded,
          rs.paywallWalletsTitle,
          rs.paywallWalletsDesc,
          false,
        ),
        (
          Icons.savings_rounded,
          rs.paywallGoalsTitle,
          rs.paywallGoalsDesc,
          false,
        ),
      ],
    ),
    (
      rs.paywallGroupAutomation,
      [
        (
          Icons.repeat_rounded,
          rs.paywallRecurringTitle,
          rs.paywallRecurringDesc,
          false,
        ),
        (Icons.rule_rounded, rs.paywallRulesTitle, rs.paywallRulesDesc, false),
      ],
    ),
    (
      rs.paywallGroupEntry,
      [
        (
          Icons.auto_awesome_rounded,
          rs.paywallAiCatTitle,
          rs.paywallAiCatDesc,
          false,
        ),
        (
          Icons.document_scanner_rounded,
          rs.paywallScanTitle,
          rs.paywallScanDesc,
          false,
        ),
        (Icons.mic_rounded, rs.paywallVoiceTitle, rs.paywallVoiceDesc, false),
        // Çoklu giriş kipi gerçekten var: quick_entry_screen'deki _multi.
        (
          Icons.bolt_rounded,
          rs.paywallQuickAddTitle,
          rs.paywallQuickAddDesc,
          false,
        ),
      ],
    ),
    (
      rs.paywallGroupInsights,
      [
        (
          Icons.insights_rounded,
          rs.paywallAnalyticsTitle,
          rs.paywallAnalyticsDesc,
          false,
        ),
        (
          Icons.ios_share_rounded,
          rs.paywallShareTitle,
          rs.paywallShareDesc,
          false,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Giriş animasyonu sırası gruplar arasında devam eder; enterUp adımı
    // 7'de kapandığı için alt maddeler birlikte belirir, uzun bekleme olmaz.
    var index = 0;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(
          rs.paywallBenefitsTitle,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: Ex.text,
          ),
        ),
      ),
    ];
    for (final (title, items) in _groups()) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            // Referansta grup başlığı küçük gri etiket DEĞİL: normal
            // yazımlı, beyaz ve büyük. Önce yanlış okumuştum.
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Ex.text,
            ),
          ),
        ).enterUp(context, index: index++),
      );
      children.add(
        // Kart zemini yok: maddeler doğrudan sayfanın üstünde akıyor.
        Column(
          children: [
            for (var i = 0; i < items.length; i++)
              _BenefitRow(
                icon: items[i].$1,
                title: items[i].$2,
                description: items[i].$3,
                divider: false,
              ),
          ],
        ).enterUp(context, index: index++),
      );
      children.add(const SizedBox(height: 26));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Tek fayda: ikon + başlık + açıklama.
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.divider,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 11, 2, 11),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Ex.border)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zeminsiz ikon: referansta simge doğrudan sayfanın üstünde duruyor.
          SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 22, color: Ex.mint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.3,
                    color: Ex.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.35,
                    color: Ex.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// En altta, koyu zeminde: Apple'ın paywall'da ZORUNLU tuttuğu Kullanım
/// Şartları + Gizlilik Politikası bağlantıları.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.rs});

  final RS rs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: _LegalLink(
            text: rs.paywallTerms,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TermsOfUseScreen())),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: TextStyle(fontSize: 11.5, color: Ex.textFaint),
          ),
        ),
        Flexible(
          child: _LegalLink(
            text: rs.privacyPolicy,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.5,
          color: Ex.textSoft,
          decoration: TextDecoration.underline,
          decorationColor: Ex.textFaint,
        ),
      ),
    );
  }
}
