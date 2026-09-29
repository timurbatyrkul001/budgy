import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/category_rules.dart';
import '../../core/currency_info.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/preview.dart';
import '../../core/redesign_l10n.dart';
import '../auth/sign_in_screen.dart';
import '../envelopes/budget_repository.dart';
import '../profile/privacy_policy_screen.dart';
import '../profile/terms_of_use_screen.dart';
import '../space/currency_wallet_sheet.dart';
import '../space/space.dart';
import 'intro_mockups.dart';
import 'onboarding_palette.dart';

/// 6 sayfalı onboarding: karşılama → hızlı giriş → kurallar → bütçe
/// (tanıtım) → para birimi → cüzdan (kurulum).
/// Sonunda para birimi + cüzdan + hazır kategoriler yazılır ve
/// `onboardingDone` işaretlenir; auth kapısı ana ekrana geçer.
///
/// [preview] (yalnız `--dart-define=PREVIEW_ONBOARDING=true`): hiçbir şey
/// yazmaz, son buton sadece geri döner — ekran görüntüsü almak için.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, this.preview = false, this.initialStep = 0});

  final bool preview;

  /// Başlangıç adımı (0-5) — önizlemede belirli bir adımı açmak için.
  final int initialStep;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late int _page = widget.initialStep.clamp(0, 5);
  bool _forward = true;
  bool _saving = false;
  late String _currency;
  SpaceInfo? _draft;

  /// Ana cüzdanın başlangıç tutarı (boş = 0) ve ek döviz cüzdanları —
  /// "Başlayalım"a kadar yalnız yerel taslak.
  final _mainAmount = TextEditingController();
  final _extras = <CurrencyWalletDraft>[];

  @override
  void initState() {
    super.initState();
    _currency =
        currencyForRegion(PlatformDispatcher.instance.locale.countryCode);
    // Önizlemede PREVIEW_AUTOPLAY: 1,6 s sonra kendiliğinden ileri gider —
    // sayfa geçişini ekran görüntüleriyle kare kare doğrulamak için.
    if (widget.preview && kPreviewOnboardingAutoplay && _page < 5) {
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) _go(_page + 1);
      });
    }
    // Önizleme doğrudan cüzdan adımında açılırsa dolu hâlini göster
    // (ekran görüntüsü için); veri yazılmaz.
    if (widget.preview && widget.initialStep == 5) {
      _mainAmount.text = '12500';
      _extras.addAll(const [
        CurrencyWalletDraft(code: 'USD', amount: 500),
        CurrencyWalletDraft(code: 'EUR', amount: 120),
      ]);
    }
  }

  @override
  void dispose() {
    _mainAmount.dispose();
    super.dispose();
  }

  /// Ana para birimi değişince aynı koddaki ek cüzdan anlamsızlaşır.
  void _setCurrency(String code) => setState(() {
        _currency = code;
        _extras.removeWhere((e) => e.code == code);
      });

  Future<void> _addExtra() async {
    final draft = await showCurrencyWalletSheet(context,
        exclude: {_currency, for (final e in _extras) e.code});
    if (draft != null) setState(() => _extras.add(draft));
  }

  /// Taslak cüzdan: dil değişirse varsayılan ad da değişsin diye tembel.
  SpaceInfo _space(RS rs) => _draft ??= SpaceInfo(
        name: rs.defaultWalletName,
        color: Ex.spaceColors.first.toARGB32(),
      );

  void _go(int page) => setState(() {
        _forward = page > _page;
        _page = page;
      });

  Future<void> _changeCurrency() async {
    final code = await showCurrencyPicker(context, selected: _currency);
    if (code != null) _setCurrency(code);
  }

  Future<void> _customize(RS rs) async {
    final result = await showSpaceEditor(context,
        initial: _space(rs), currency: _currency);
    if (result != null) {
      setState(() => _draft = result.info);
      _setCurrency(result.currency);
    }
  }

  void _signIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignInScreen(
          // Mevcut hesapta onboarding zaten bitmiş — auth kapısı ana
          // ekrana kendisi geçer; biz sadece köke dönüyoruz.
          onSignedIn: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  Future<void> _start(RS rs) async {
    if (_saving) return;
    if (widget.preview) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _saving = true);
    // Repo'yu ÖNCE al: yazma sırasında auth kapısı bu widget'ı değiştirebilir,
    // sonra ref okumak güvenli olmaz.
    final repo = ref.read(budgetRepositoryProvider);
    final str = ref.read(strProvider);
    final hasEnvelopes = ref.read(envelopesProvider).value?.isNotEmpty ?? false;
    final space = _space(rs);
    try {
      await repo.setCurrency(_currency);
      await repo.saveProfile(space.toProfile());
      // Harcama kategorileri hâlâ gerekli (gider sınıflandırma) — sessizce
      // hazır seti oluştur.
      if (!hasEnvelopes) {
        await repo.addEnvelopes([
          for (final p in presetEnvelopes)
            (
              key: p.key,
              emoji: p.emoji,
              name: str.presetNames[p.key] ?? p.key,
            ),
        ]);
      }
      // Başlangıç bakiyesi: ₺ cüzdana gelir; dövizler ayrı kumbara zarfı.
      final mainAmount = parseAmount(_mainAmount.text) ?? 0;
      if (mainAmount > 0) {
        await repo.addCashIncome(amount: mainAmount, note: rs.startingBalance);
      }
      // Sıra numarası mevcut/hazır zarfların ardından devam eder.
      var sortOrder = hasEnvelopes
          ? (ref.read(envelopesProvider).value?.length ?? 0)
          : presetEnvelopes.length;
      for (final e in _extras) {
        await repo.addCurrencyWallet(
          code: e.code,
          name: walletNameFor(rs, e.code),
          emoji: walletEmojiFor(e.code),
          amount: e.amount,
          sortOrder: sortOrder++,
          note: rs.startingBalance,
        );
      }
      await repo.setOnboardingDone();
    } catch (_) {
      if (mounted) {
        showErrorSnack(context, str.errorSaveFailed);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final locale = ref.watch(strProvider).localeCode;
    final pages = [
      _WelcomePage(
        rs: rs,
        onNext: () => _go(1),
        onSignIn: _signIn,
      ),
      // Tanıtım sayfaları: maket üstte, ortalı başlık + alt başlık, Devam.
      _IntroPage(
        title: rs.introFastTitle,
        subtitle: rs.introFastSubtitle,
        buttonLabel: rs.continueLabel,
        onNext: () => _go(2),
        mockup: const FastEntryMock(),
      ),
      _IntroPage(
        title: rs.introRulesTitle,
        subtitle: tpl(rs.introRulesSubtitleTpl,
            {'n': '${kBuiltinRuleCount ~/ 10 * 10}'}),
        buttonLabel: rs.continueLabel,
        onNext: () => _go(3),
        mockup: RulesMock(locale: locale),
      ),
      _IntroPage(
        title: rs.introBudgetTitle,
        subtitle: rs.introBudgetSubtitle,
        buttonLabel: rs.continueLabel,
        onNext: () => _go(4),
        mockup: BudgetMock(locale: locale, title: rs.monthlyBudget),
      ),
      _CurrencyPage(
        rs: rs,
        code: _currency,
        onChange: _changeCurrency,
        onUse: () => _go(5),
      ),
      _WalletPage(
        rs: rs,
        space: _space(rs),
        currency: _currency,
        amount: _mainAmount,
        extras: _extras,
        onAddExtra: _addExtra,
        onRemoveExtra: (i) => setState(() => _extras.removeAt(i)),
        onCustomize: () => _customize(rs),
        onStart: _saving ? null : () => _start(rs),
      ),
    ];

    // Tüm akış beyaz afiş dilinde; durum çubuğu simgeleri koyu. Karşılama
    // (0) üst şeritsiz poster, diğer adımlarda yalnız sol üstte geri oku
    // (ilerleme çubuğu bilinçli olarak yok — referansta da yok).
    final Widget body = _page == 0
        ? KeyedSubtree(key: const ValueKey('welcome'), child: pages[0])
        : Column(
            key: const ValueKey('flow'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _PaperBackButton(onTap: () => _go(_page - 1)),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: _pageSwitch,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => _slideFade(
                      child, anim, forward: (child.key == ValueKey(_page)) == _forward),
                  child: KeyedSubtree(
                    key: ValueKey(_page),
                    child: pages[_page],
                  ),
                ),
              ),
            ],
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Zemin geçiş boyunca kâğıt kalır: hiçbir karede boş/siyah flaş yok.
        backgroundColor: Poster.paper,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: _pageSwitch,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => _slideFade(
                child, anim, forward: (child.key == const ValueKey('flow')) == _forward),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Sayfa geçişi süresi.
const _pageSwitch = Duration(milliseconds: 360);

/// Sayfa geçişi: çıkan içerik blok hâlinde sola kayıp solar, gelen sağdan
/// kayıp belirir (geri giderken yönler ters). Kayma mütevazı — genişliğin
/// ~%22'si, ekran dışına itilmez. [anim] AnimatedSwitcher'ın animasyonu:
/// gelen için 0→1, çıkan için 1→0; [forward] gelen ile akış yönü aynı mı.
Widget _slideFade(Widget child, Animation<double> anim, {required bool forward}) {
  final dx = forward ? 0.22 : -0.22;
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
      child: child,
    ),
  );
}

/// Beyaz zeminde geri düğmesi: ince mürekkep çerçeveli yuvarlak kare.
class _PaperBackButton extends StatelessWidget {
  const _PaperBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ex.iconRadius),
        side: BorderSide(color: Poster.ink.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_rounded, color: Poster.ink, size: 22),
        ),
      ),
    );
  }
}

/// Küçük ekranda taşmadan yerleşen dikey düzen: içerik sığarsa Spacer'lar
/// boşluğu paylaşır, sığmazsa kayar.
class _FillScroll extends StatelessWidget {
  const _FillScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Form sayfalarının (para birimi, cüzdan) başlığı: sola yaslı display
/// başlık + Inter alt başlık — karşılamanın gölgesinde, onunla yarışmayan
/// ölçü (36/32 px).
class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // _FillScroll'un IntrinsicHeight'ı altında LayoutBuilder kullanılamaz
    // (intrinsic ölçü veremez); genişlik ekran genişliğinden türetilir.
    final width = MediaQuery.sizeOf(context).width - 40;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DisplayTitle(
          title,
          maxWidth: width,
          narrow: width < 310,
          size: 36,
          narrowSize: 32,
          spacing: -1.5,
          lineHeight: 0.98,
          dropFrom: Duration.zero,
        ),
        const SizedBox(height: 12),
        Text(subtitle, style: _bodyStyle)
            .dropIn(context, const Duration(milliseconds: 200), dy: -10),
      ],
    );
  }
}

/// Gövde metni: Inter, yumuşak mürekkep.
const _bodyStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 16,
  height: 1.4,
  color: Poster.inkSoft,
);

/// Form sayfalarındaki beyaz kart: ince mürekkep çerçeve, çok hafif gölge.
class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Ex.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Poster.ink.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ex.cardRadius),
          side: BorderSide(color: Poster.ink.withValues(alpha: 0.10)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ── 1) Karşılama ─────────────────────────────────────────────────────────

/// Karşılama: beyaz afiş. Sol üstte marka ikonu + rozet (fotoğraf kesiti
/// sonra buraya gelecek), sağ üstte gravür takvim, ortada el yazısı not ve
/// ondan gravüre giden kavisli ok, altında ekranın en baskın ögesi olan
/// sıkı display başlık + tek cümle. Altta ortalanmış siyah hap, "hesabım
/// var" ve yasal not. Arkada çok soluk takvim ızgarası.
///
/// Kenarlardaki iki küçük öge (piksel-art) daha sonra eklenecek: üst Stack
/// `clipBehavior: none`, sol kenar orta ve sağ kenar alt boş bırakıldı.
///
/// Sahne sırası: rozet → not → ok (35 ms adımlarla), gravür iner, başlık ve
/// alt başlık gelir, en son düğmeler yerleşir.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.rs,
    required this.onNext,
    required this.onSignIn,
  });

  final RS rs;
  final VoidCallback onNext;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final narrow = w < 350;
        // Gravür genişliğe göre; kolaj başlığı onun yüksekliğinden türer.
        final engraving = math.min(w * 0.42, 176.0);
        final headerH = math.max(engraving + 18, narrow ? 168.0 : 184.0);
        return Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _CalendarGridPainter())),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Kolaj başlığı: rozet, not, ok, gravür.
                      SizedBox(
                        height: headerH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Ok: nottan gravüre. Tüm başlık alanını kaplar,
                            // koordinatlar oranla verilir.
                            // Ok, not belirdikten hemen sonra kendini çizer.
                            Positioned.fill(
                              child: _SketchArrow(
                                from: Offset(w * 0.30, headerH * 0.84),
                                control: Offset(w * 0.50, headerH * 1.02),
                                to: Offset(w * 0.61, headerH * 0.60),
                                delay: const Duration(milliseconds: 380),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              top: 0,
                              child: Row(
                                children: [
                                  // Referanstaki yuvarlak fotoğrafın yeri —
                                  // şimdilik marka ikonu.
                                  const BudgyIcon(size: 36, radiusFactor: 0.5),
                                  const SizedBox(width: 10),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: w * 0.56),
                                    child: _AudienceBadge(rs.onbBadge),
                                  ),
                                ],
                              ).enterUp(context, index: 0),
                            ),
                            // El yazısı not: hafif eğik, gravürün solunda.
                            Positioned(
                              left: 22,
                              top: 56,
                              width: w * 0.50,
                              child: Transform.rotate(
                                angle: -4 * math.pi / 180,
                                alignment: Alignment.topLeft,
                                child: Text(
                                  rs.onbNote,
                                  style: TextStyle(
                                    fontFamily: 'Caveat',
                                    fontVariations: const [FontVariation('wght', 650)],
                                    fontSize: narrow ? 19 : 22,
                                    height: 1.08,
                                    color: Poster.ink,
                                  ),
                                ),
                              ).enterUp(context, index: 1),
                            ),
                            // Gravür takvim: sağ üstten hafif taşar.
                            Positioned(
                              right: -engraving * 0.06,
                              top: -4,
                              child: _CollageImage(
                                'assets/onboarding/engraving_calendar.png',
                                size: engraving,
                                angle: 6,
                              ).dropIn(context, const Duration(milliseconds: 240), dy: -12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DisplayTitle(rs.onbTitle,
                                    maxWidth: w - 40, narrow: narrow, narrowSpacing: -2.4)
                                .enterUp(context, index: 3),
                            const SizedBox(height: 18),
                            Text(
                              rs.onbSubtitle,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 17,
                                height: 1.4,
                                color: Poster.inkSoft,
                              ),
                            ).enterUp(context, index: 4),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _InkPillButton(label: rs.getStarted, onTap: onNext),
                            ).enterUp(context, index: 5),
                            const SizedBox(height: 6),
                            _PaperTextButton(label: rs.haveAccount, onTap: onSignIn)
                                .enterUp(context, index: 6),
                            const SizedBox(height: 6),
                            _LegalNote(rs: rs).enterUp(context, index: 7),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dev display başlık: Inter Display Black, satırlar neredeyse değiyor
/// (height 0.96), harfler sıkı (−3). Tek bir sözcük satıra sığmazsa Flutter
/// onu ortasından böler; bunu önlemek için en uzun sözcük ölçülür ve gerekirse
/// punto o sözcük sığana kadar küçültülür (TR "Çalıştığın", RU "Отмечай").
class _DisplayTitle extends StatelessWidget {
  const _DisplayTitle(
    this.text, {
    required this.maxWidth,
    required this.narrow,
    this.size = 64,
    this.narrowSize = 50,
    this.spacing = -3.0,
    this.narrowSpacing,
    this.lineHeight = 0.96,
    this.dropFrom,
  });

  final String text;
  final double maxWidth;
  final bool narrow;

  /// Verilirse başlık satırlara bölünür ve her satır bir öncekinden
  /// [_dropStep] sonra yukarıdan düşerek belirir (referanstaki "yazı aşağı
  /// indi" hissi). null: tek parça, animasyonsuz (çağıran kendisi sarar).
  final Duration? dropFrom;

  /// Satırlar arası gecikme.
  static const _dropStep = Duration(milliseconds: 80);

  /// Punto (geniş / dar ekran) ve harf aralığı; karşılama afişi
  /// varsayılanları kullanır, iç sayfalar daha küçük ölçü verir.
  final double size;
  final double narrowSize;
  final double spacing;
  final double? narrowSpacing;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final base = narrow ? narrowSize : size;
    final spacingAt =
        narrow ? (narrowSpacing ?? spacing * narrowSize / size) : spacing;
    TextStyle styleAt(double s) => TextStyle(
          fontFamily: 'InterDisplay',
          fontWeight: FontWeight.w900,
          fontSize: s,
          height: lineHeight,
          letterSpacing: spacingAt * (s / base),
          color: Poster.ink,
        );
    var fitted = base;
    final longest = text.split(RegExp(r'\s+')).reduce(
        (a, b) => a.length >= b.length ? a : b);
    final painter = TextPainter(
      text: TextSpan(text: longest, style: styleAt(fitted)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    if (painter.width > maxWidth) {
      fitted = (fitted * maxWidth / painter.width).floorToDouble();
    }
    final style = styleAt(fitted);
    final from = dropFrom;
    if (from == null || reduceMotion(context)) {
      painter.dispose();
      return Text(text, style: style);
    }
    // Aynı stil ve genişlikte gerçek satır kırılımlarını al; her satır ayrı
    // Text olarak çizilir (satır yüksekliği paragraftakiyle aynı çıkar).
    painter
      ..text = TextSpan(text: text, style: style)
      ..layout(maxWidth: maxWidth);
    final lines = <String>[];
    var start = 0;
    while (start < text.length) {
      final range = painter.getLineBoundary(TextPosition(offset: start));
      if (!range.isValid || range.end <= start) break;
      final line = text.substring(range.start, range.end).trim();
      if (line.isNotEmpty) lines.add(line);
      start = range.end;
      while (start < text.length && text[start].trim().isEmpty) {
        start++;
      }
    }
    painter.dispose();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, line) in lines.indexed)
          Text(line, maxLines: 1, softWrap: false, style: style)
              .dropIn(context, from + _dropStep * i, dy: -12),
      ],
    );
  }
}

/// Kimin için olduğunu söyleyen küçük hap — marka renginde dolu.
class _AudienceBadge extends StatelessWidget {
  const _AudienceBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 12, 7),
      decoration: BoxDecoration(
        color: Ex.brand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'InterDisplay',
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          letterSpacing: 0.1,
          color: Ex.onBrand,
        ),
      ),
    );
  }
}

/// Referanstaki ana düğme: tam genişlik değil, içeriğe göre daralan,
/// ortalanmış siyah hap.
class _InkPillButton extends StatelessWidget {
  const _InkPillButton({required this.label, required this.onTap});

  final String label;

  /// null = devre dışı (kaydediliyor).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? Poster.ink.withValues(alpha: 0.35) : Poster.ink,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 15, 30, 15),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'InterDisplay',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: Poster.paper,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Zaten hesabım var": [GhostButton]'ın beyaz zemin karşılığı — nane beyazda
/// okunmuyor, mürekkep rengi kullanılır.
class _PaperTextButton extends StatelessWidget {
  const _PaperTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Poster.ink,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'InterDisplay',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Kolaj parçası: şeffaf zeminli görsel, hafif döndürülmüş. 1024'lük PNG
/// bellek için ekran yoğunluğuna göre küçültülerek çözülür.
class _CollageImage extends StatelessWidget {
  const _CollageImage(this.asset, {required this.size, this.angle = 0});

  final String asset;
  final double size;

  /// Derece cinsinden.
  final double angle;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return IgnorePointer(
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          cacheWidth: (size * dpr).round(),
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// En alttaki yasal not: {terms} ve {privacy} tıklanınca ilgili ekranı açar.
/// Şablon dile göre bölünür; bağlantı sözcükleri ayrı metinlerden gelir.
class _LegalNote extends StatefulWidget {
  const _LegalNote({required this.rs});

  final RS rs;

  @override
  State<_LegalNote> createState() => _LegalNoteState();
}

class _LegalNoteState extends State<_LegalNote> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _open(const TermsOfUseScreen());
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open(const PrivacyPolicyScreen());

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;
    const base = TextStyle(
        fontFamily: 'Inter', fontSize: 11.5, height: 1.35, color: Poster.inkFaint);
    const link = TextStyle(
      color: Poster.inkSoft,
      decoration: TextDecoration.underline,
      decorationColor: Poster.inkFaint,
    );
    // Şablonu yer tutuculardan böl; sıra dile göre değişebilir.
    final parts = rs.onbLegalTpl.split(RegExp(r'(\{terms\}|\{privacy\})'));
    final matches = RegExp(r'\{terms\}|\{privacy\}').allMatches(rs.onbLegalTpl).toList();
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < matches.length) {
        final isTerms = matches[i].group(0) == '{terms}';
        spans.add(TextSpan(
          text: isTerms ? rs.onbLegalTerms : rs.onbLegalPrivacy,
          style: link,
          recognizer: isTerms ? _terms : _privacy,
        ));
      }
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: TextAlign.center,
    );
  }
}

/// Kendini çizen ok: sayfa açılırken [delay] sonra çizgi kuyruktan uca
/// doğru ilerleyerek oluşur (~520 ms, easeOutCubic), sonda ok ucu belirir.
/// Hareket azaltmada tam çizilmiş durur (motion.dart kuralı).
class _SketchArrow extends StatefulWidget {
  const _SketchArrow({
    required this.from,
    required this.control,
    required this.to,
    this.delay = Duration.zero,
  });

  final Offset from;
  final Offset control;
  final Offset to;
  final Duration delay;

  @override
  State<_SketchArrow> createState() => _SketchArrowState();
}

class _SketchArrowState extends State<_SketchArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _progress =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(
          painter: _SketchArrowPainter(
            from: widget.from,
            control: widget.control,
            to: widget.to,
            progress: _progress.value,
          ),
        ),
      ),
    );
  }
}

/// El çizimi ok: nottan gravüre, tek kavis (quadratic bezier). Elde çizilmiş
/// hissi için yol boyunca küçük bir salınım eklenir; ucunda iki kısa çizgi.
/// [progress] 0-1: yolun ne kadarının açığa çıktığı; ok ucu 0,85'ten sonra.
class _SketchArrowPainter extends CustomPainter {
  const _SketchArrowPainter({
    required this.from,
    required this.control,
    required this.to,
    this.progress = 1,
  });

  final Offset from;
  final Offset control;
  final Offset to;
  final double progress;

  Offset _bezier(double t) {
    final u = 1 - t;
    return from * (u * u) + control * (2 * u * t) + to * (t * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Poster.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Eğriyi örnekle, normale doğru küçük bir titreme ekle.
    final path = Path();
    const n = 28;
    Offset prev = from;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final p = _bezier(t);
      final next = _bezier(math.min(1, t + 1 / n));
      final tangent = next - p;
      final len = tangent.distance == 0 ? 1 : tangent.distance;
      final normal = Offset(-tangent.dy / len, tangent.dx / len);
      final wobble = math.sin(t * math.pi * 5) * 0.9 * (1 - t);
      final q = p + normal * wobble;
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
      prev = q;
    }
    // Açığa çıkma: yolun yalnız [progress] kadarı çizilir.
    if (progress <= 0) return;
    if (progress < 1) {
      final partial = Path();
      for (final metric in path.computeMetrics()) {
        partial.addPath(
            metric.extractPath(0, metric.length * progress), Offset.zero);
      }
      canvas.drawPath(partial, paint);
    } else {
      canvas.drawPath(path, paint);
    }
    if (progress < 0.85) return;

    // Ok ucu: son teğete göre iki kısa çizgi, hafif asimetrik.
    final dir = to - _bezier(0.9);
    final angle = math.atan2(dir.dy, dir.dx);
    const headLen = 9.0;
    for (final (side, spread) in const [(1.0, 0.55), (-1.0, 0.48)]) {
      final a = angle + math.pi + side * spread;
      final end = prev + Offset(math.cos(a), math.sin(a)) * headLen;
      canvas.drawLine(prev, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchArrowPainter old) =>
      old.from != from ||
      old.control != control ||
      old.to != to ||
      old.progress != progress;
}

/// Arka plan deseni: takvim kareleri ızgarası. Beyaz zeminde mürekkep çok
/// düşük alfayla, birkaç "işaretli gün" marka renginde biraz daha belirgin;
/// aşağı doğru dikey solar. Görsel yok, tamamen çizim.
class _CalendarGridPainter extends CustomPainter {
  const _CalendarGridPainter();

  static const _cell = 26.0;
  static const _gap = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Poster.ink.withValues(alpha: 0.05),
        Poster.ink.withValues(alpha: 0.03),
        Poster.ink.withValues(alpha: 0),
      ],
      stops: const [0, 0.45, 0.82],
    ).createShader(Offset.zero & size);
    final cell = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = fade;
    final marked = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Ex.brand.withValues(alpha: 0.09),
          Ex.brand.withValues(alpha: 0),
        ],
        stops: const [0, 0.8],
      ).createShader(Offset.zero & size);

    const step = _cell + _gap;
    // Izgara ekranın kenarına hizalı başlamasın diye yarım hücre kaydır.
    final cols = (size.width / step).ceil() + 1;
    final rows = (size.height / step).ceil() + 1;
    final r = const Radius.circular(6);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final rect = Rect.fromLTWH(
          x * step - _cell / 2,
          y * step - _cell / 2,
          _cell,
          _cell,
        );
        final rr = RRect.fromRectAndRadius(rect, r);
        // Deterministik "işaretli gün" serpiştirmesi (her ~9 hücrede bir).
        if ((x * 7 + y * 11) % 9 == 3) canvas.drawRRect(rr, marked);
        canvas.drawRRect(rr, cell);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CalendarGridPainter oldDelegate) => false;
}

// ── 2-4) Tanıtım sayfaları ───────────────────────────────────────────────

/// Ortak tanıtım düzeni: üstte maket (afiş paletinde, çerçevesiz), altında
/// sola yaslı display başlık + tek cümle, altta ortalanmış siyah hap.
class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onNext,
    required this.mockup,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onNext;
  final Widget mockup;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => _FillScroll(
        children: [
          const SizedBox(height: 18),
          // Maket çerçevesiz, doğrudan zeminde (karşılamadaki gravür gibi);
          // sabit genişlikte çizildiği için dar ekranda ölçeklenerek sığar.
          // Sahne sırası: maket → başlık satır satır → açıklama → düğme.
          Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: mockup),
          ).dropIn(context, Duration.zero, dy: -10),
          // Başlık makete yakın dursun: boşluğun büyüğü düğmeden önce.
          const Spacer(flex: 2),
          const SizedBox(height: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DisplayTitle(
                title,
                maxWidth: box.maxWidth - 40,
                narrow: box.maxWidth < 350,
                size: 40,
                narrowSize: 34,
                spacing: -1.8,
                lineHeight: 0.98,
                dropFrom: const Duration(milliseconds: 140),
              ),
              const SizedBox(height: 12),
              Text(subtitle, style: _bodyStyle)
                  .dropIn(context, const Duration(milliseconds: 340), dy: -10),
            ],
          ),
          const Spacer(flex: 3),
          const SizedBox(height: 28),
          Center(child: _InkPillButton(label: buttonLabel, onTap: onNext))
              .dropIn(context, const Duration(milliseconds: 460), dy: -8),
          // Karşılamadaki "hesabım var" + yasal notla aynı alt boşluk.
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── 5) Para birimi ───────────────────────────────────────────────────────

class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage({
    required this.rs,
    required this.code,
    required this.onChange,
    required this.onUse,
  });

  final RS rs;
  final String code;
  final VoidCallback onChange;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return _FillScroll(
      children: [
        const SizedBox(height: 24),
        _Title(rs.currencyTitle, rs.currencySubtitle),
        const SizedBox(height: 32),
        const Spacer(),
        _PaperCurrencyCard(code: code)
            .dropIn(context, const Duration(milliseconds: 300), dy: -12),
        const Spacer(flex: 2),
        const SizedBox(height: 20),
        Center(
          child: _InkPillButton(
              label: tpl(rs.continueWithTpl, {'code': code}), onTap: onUse),
        ).dropIn(context, const Duration(milliseconds: 420), dy: -8),
        const SizedBox(height: 4),
        _PaperTextButton(label: rs.chooseAnother, onTap: onChange)
            .dropIn(context, const Duration(milliseconds: 480), dy: -8),
      ],
    );
  }
}

/// Seçili para biriminin büyük beyaz kartı: simge rozeti, ad, bayrak + kod.
class _PaperCurrencyCard extends StatelessWidget {
  const _PaperCurrencyCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    const badge = 56.0;
    return _PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Container(
            width: badge,
            height: badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Ex.brand.withValues(alpha: 0.18),
              borderRadius: Ex.squircle(badge),
            ),
            child: Text(
              kCurrencies[code] ?? code,
              style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Poster.ink,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currencyName(code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'InterDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Poster.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${currencyFlag(code)}  $code',
                  style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 14, color: Poster.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle_rounded, color: Ex.brand, size: 26),
        ],
      ),
    );
  }
}

// ── 6) Cüzdan ────────────────────────────────────────────────────────────

/// Beyaz zeminde metin alanı dekorasyonu: temanın koyu dolgusu yerine
/// çok soluk mürekkep dolgu, çerçevesiz.
InputDecoration _paperInput({String? hint, String? suffix}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Poster.inkFaint, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: Poster.ink.withValues(alpha: 0.05),
      suffixText: suffix,
      suffixStyle: const TextStyle(
          fontFamily: 'Inter', color: Poster.inkSoft, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Poster.ink, width: 1.5),
      ),
    );

class _WalletPage extends StatelessWidget {
  const _WalletPage({
    required this.rs,
    required this.space,
    required this.currency,
    required this.amount,
    required this.extras,
    required this.onAddExtra,
    required this.onRemoveExtra,
    required this.onCustomize,
    required this.onStart,
  });

  final RS rs;
  final SpaceInfo space;
  final String currency;
  final TextEditingController amount;
  final List<CurrencyWalletDraft> extras;
  final VoidCallback onAddExtra;
  final ValueChanged<int> onRemoveExtra;
  final VoidCallback onCustomize;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      fontFamily: 'InterDisplay',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Poster.inkSoft,
    );
    return _FillScroll(
      children: [
        const SizedBox(height: 24),
        _Title(rs.walletTitle, rs.walletSubtitle),
        const SizedBox(height: 24),
        // Ana cüzdan: kimlik satırı + başlangıç tutarı.
        _PaperCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onCustomize,
                child: Row(
                  children: [
                    SpaceAvatar(space: space, size: 52),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            space.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'InterDisplay',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: Poster.ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Poster.ink.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${currencyFlag(currency)}  $currency',
                              style: const TextStyle(
                                  fontFamily: 'InterDisplay',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Poster.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit_rounded, size: 20, color: Poster.inkFaint),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Poster.ink.withValues(alpha: 0.10)),
              ),
              Text(rs.startingAmount, style: label),
              const SizedBox(height: 8),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                cursorColor: Poster.ink,
                style: const TextStyle(
                  fontFamily: 'InterDisplay',
                  color: Poster.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                decoration: _paperInput(
                    hint: '0', suffix: kCurrencies[currency] ?? currency),
              ),
            ],
          ),
        ).dropIn(context, const Duration(milliseconds: 300), dy: -12),
        const SizedBox(height: 22),
        // Ek döviz cüzdanları.
        Text(rs.otherCurrencies,
            style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: Poster.ink)).dropIn(context, const Duration(milliseconds: 380), dy: -8),
        const SizedBox(height: 4),
        Text(rs.otherCurrenciesHint,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.35,
                    color: Poster.inkSoft))
            .dropIn(context, const Duration(milliseconds: 380), dy: -8),
        const SizedBox(height: 10),
        for (final (i, e) in extras.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExtraRow(draft: e, onRemove: () => onRemoveExtra(i)),
          ).dropIn(context, Duration(milliseconds: 440 + i * 60), dy: -8),
        _PaperTextButton(label: rs.addCurrencyWallet, onTap: onAddExtra)
            .dropIn(context, const Duration(milliseconds: 520), dy: -8),
        const Spacer(),
        const SizedBox(height: 16),
        Center(child: _InkPillButton(label: rs.letsGo, onTap: onStart))
            .dropIn(context, const Duration(milliseconds: 600), dy: -8),
        const SizedBox(height: 4),
        _PaperTextButton(label: rs.customize, onTap: onCustomize)
            .dropIn(context, const Duration(milliseconds: 660), dy: -8),
      ],
    );
  }
}

/// Taslaktaki ek döviz cüzdanı satırı: bayrak + ad + tutar + kaldır.
class _ExtraRow extends StatelessWidget {
  const _ExtraRow({required this.draft, required this.onRemove});

  final CurrencyWalletDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          Text(currencyFlag(draft.code), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currencyName(draft.code),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'InterDisplay',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Poster.ink),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoneyIn(draft.amount, draft.code),
            style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Poster.ink),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20, color: Poster.inkFaint),
          ),
        ],
      ),
    );
  }
}
