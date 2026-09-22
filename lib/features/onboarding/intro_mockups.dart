import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/category_avatar.dart';
import '../../core/category_catalog.dart';
import '../../core/category_rules.dart';
import '../../core/category_visual.dart';
import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../budget/budget_ring.dart';

/// Tanıtım sayfalarının maketleri — ekran görüntüsü değil, kendi
/// bileşen ve token'larımızla küçültülmüş "canlı" parçalar. Kategori
/// paleti renk sözlüğümüz; koyu zümrüt zemin ve marka yeşili çapa.
/// Hareket: yalnız giriş + sayfa başına tek anlamlı vuruş, döngü yok;
/// hareket azaltmada yerleşik durum.

const _mockWidth = 264.0;

/// Kahraman öğenin arkasındaki yumuşak ışık (radyal, token renginden).
class IntroGlow extends StatelessWidget {
  const IntroGlow({super.key, required this.color, this.size = 260, this.alpha = 0.34});

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}

/// Kartlara derinlik: yumuşak, geniş gölge.
List<BoxShadow> _softShadow([Color color = Colors.black]) => [
      BoxShadow(
        color: color.withValues(alpha: 0.45),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ];

// ── 2) Hızlı giriş ───────────────────────────────────────────────────────

/// Hafif eğik tuş takımı paneli, alt kenarı kırpılmış; tutar basamak basamak
/// "yazılır" (tek vuruş). Sağ altta üç giriş yolu: yaz / söyle / tara.
class FastEntryMock extends StatelessWidget {
  const FastEntryMock({super.key, required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final amount = formatMoneyIn(450, currency);
    return SizedBox(
      width: _mockWidth,
      height: 236,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          const Positioned(top: -30, child: IntroGlow(color: Ex.brand, size: 300)),
          // Panel: -3° eğik, alt sıra kırpılıp solduruluyor.
          Positioned(
            top: 6,
            left: 14,
            right: 14,
            child: Transform.rotate(
              angle: -3 * math.pi / 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Ex.cardRadius),
                child: Container(
                  height: 214,
                  decoration: BoxDecoration(
                    color: Ex.surface,
                    borderRadius: BorderRadius.circular(Ex.cardRadius),
                    border: Border.all(color: Ex.borderHi),
                    boxShadow: _softShadow(),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        child: TypingScene(
                          amount: amount,
                          builder: (shown, glow) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Yazılan tutar; yüksekliği sabit kalsın diye
                              // boşken de satır yer kaplar.
                              SizedBox(
                                height: 42,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    shown,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                      color: Ex.text,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final (r, row) in const [
                                ['7', '8', '9'],
                                ['4', '5', '6'],
                                ['1', '2', '3'],
                              ].indexed) ...[
                                if (r > 0) const SizedBox(height: 6),
                                Row(
                                  children: [
                                    for (final (i, k) in row.indexed) ...[
                                      if (i > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: _MockKey(k, accent: glow(k))
                                            .enterPop(context, index: r * 3 + i),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Alt kenar solması.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 70,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Ex.surface.withValues(alpha: 0),
                                  Ex.bg.withValues(alpha: 0.96),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).enterUp(context, index: 0, dy: 16),
          // Üç yol: yaz / söyle / tara — panelin sağ alt köşesine tutunur.
          Positioned(
            right: 0,
            bottom: 0,
            child: Row(
              children: [
                for (final (i, w) in const [
                  (Icons.dialpad_rounded, Ex.brand),
                  (Icons.mic_rounded, CategoryPalette.violet),
                  (Icons.document_scanner_outlined, CategoryPalette.sky),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _WayChip(w.$1, color: w.$2)
                      .enterPop(context, index: i, baseDelay: kEnterStep * 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockKey extends StatelessWidget {
  const _MockKey(this.label, {required this.accent});

  final String label;

  /// 0 = sönük, 1 = tam basılı. Arası basışın sönme anı.
  final double accent;

  @override
  Widget build(BuildContext context) {
    final a = accent.clamp(0.0, 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: 40,
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(1 - 0.04 * a, 1 - 0.04 * a, 1, 1),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(Ex.surfaceHi, Ex.brand.withValues(alpha: 0.26), a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color.lerp(Ex.border, Ex.glassBorder, a)!),
        boxShadow: a > 0.05
            ? [
                BoxShadow(
                  color: Ex.brand.withValues(alpha: 0.35 * a),
                  blurRadius: 14 * a,
                )
              ]
            : null,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color.lerp(Ex.text, Ex.mint, a))),
    );
  }
}

/// Sayfa 2'nin sahnesi: tutar rakam rakam "yazılır", her basamakta o tuş
/// yanıp söner, sonra sahne başa döner.
///
/// [LoadingDots] gibi bilinçli döngü: burada hareket özelliği anlatıyor
/// (klavyeden saniyeler içinde giriş), süs değil. Hareket azaltmada ve
/// testlerde tutar tam yazılmış, tuşlar sönük çizilir.
class TypingScene extends StatefulWidget {
  const TypingScene({super.key, required this.amount, required this.builder});

  /// Biçimlenmiş tutar, örn. "450 ₺".
  final String amount;

  /// (görünen metin, o an basılı tuş → parlaklık) ile gövdeyi kurar.
  final Widget Function(String shown, double Function(String key) keyGlow)
      builder;

  @override
  State<TypingScene> createState() => _TypingSceneState();
}

class _TypingSceneState extends State<TypingScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  /// Rakamların ortaya çıkma anları (0-1). Son rakamdan sonra tutar
  /// [_holdUntil]'e kadar ekranda kalır, sonra solup baştan başlar.
  static const _firstAt = 0.10;
  static const _stepAt = 0.09;
  static const _holdUntil = 0.86;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Tutarın rakam konumları — semboller (₺, boşluk) rakamla birlikte gelir.
  List<int> get _digitIndexes => [
        for (final (i, c) in widget.amount.characters.indexed)
          if (RegExp(r'\d').hasMatch(c)) i,
      ];

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return widget.builder(widget.amount, (_) => 0);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final digits = _digitIndexes;
        // Kaç rakam yazıldı?
        var typed = 0;
        for (var i = 0; i < digits.length; i++) {
          if (t >= _firstAt + i * _stepAt) typed = i + 1;
        }
        final fading = t > _holdUntil;
        final shown = fading || typed == 0
            ? (fading ? widget.amount : '')
            : widget.amount.substring(
                0,
                typed == digits.length
                    ? widget.amount.length
                    : digits[typed - 1] + 1,
              );

        double glow(String key) {
          for (var i = 0; i < digits.length; i++) {
            if (widget.amount[digits[i]] != key) continue;
            final at = _firstAt + i * _stepAt;
            final since = t - at;
            // Basıştan sonra ~0.05 tur (≈200 ms) içinde söner.
            if (since >= 0 && since < 0.05) return 1 - since / 0.05;
          }
          return 0;
        }

        return Opacity(
          opacity: fading ? (1 - (t - _holdUntil) / (1 - _holdUntil)) : 1,
          child: widget.builder(shown, glow),
        );
      },
    );
  }
}

class _WayChip extends StatelessWidget {
  const _WayChip(this.icon, {required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.22), Ex.surface),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: _softShadow(),
      ),
      child: Icon(icon, size: 21, color: Color.lerp(color, Colors.white, 0.35)),
    );
  }
}

// ── 3) Kurallar ──────────────────────────────────────────────────────────

/// Not → nokta nokta ok → renkli kategori. Her satır kendi hapı; sağa doğru
/// kayan yerleşim akışı anlatır. Vuruş: not önce gelir, kategori "çözülür".
class RulesMock extends StatelessWidget {
  const RulesMock({super.key, required this.locale});

  final String locale;

  static const merchants = ['migros', 'uber', 'netflix'];

  @override
  Widget build(BuildContext context) {
    final mid = categoryVisual(matchCategory(merchants[1])?.catalogKey)?.color ??
        Ex.brand;
    return SizedBox(
      width: 280,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          IntroGlow(color: mid, size: 300, alpha: 0.28),
          Column(
            children: [
              for (final (i, m) in merchants.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                Padding(
                  // Akış hissi: her satır biraz daha sağda.
                  padding: EdgeInsets.only(left: i * 7.0, right: (2 - i) * 7.0),
                  child: _RuleRow(merchant: m, locale: locale, order: i),
                ).enterUp(context, index: i * 2, dy: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Üç noktalı "yükleniyor" göstergesi: parlaklık dalgası soldan sağa akar
/// ve baştan başlar — işletme adından kategoriye giden yolu anlatır.
///
/// Uygulamadaki TEK döngülü animasyon. Gerekçesi: burada nokta bir durum
/// anlatıyor (çözülüyor), süs değil; sayfa da yalnız birkaç saniye görünür.
/// Hareket azaltmada ve widget testlerinde (harness `disableAnimations`
/// veriyor) duruk çizilir — yoksa `pumpAndSettle` sonsuza kadar beklerdi.
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key, required this.color, this.size = 4});

  final Color color;
  final double size;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hareket azaltma açıkken hiç dönmesin (pil + erişilebilirlik).
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Nokta [i] için parlaklık: dalga her noktaya biraz gecikmeli ulaşır,
  /// yumuşak inip çıkar.
  double _alpha(int i) {
    final phase = (_controller.value - i * 0.18) % 1.0;
    final t = phase < 0.5
        ? Curves.easeInOut.transform(phase * 2)
        : Curves.easeInOut.transform((1 - phase) * 2);
    return 0.25 + 0.75 * t;
  }

  Widget _row(double Function(int) alpha) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: alpha(i).clamp(0, 1)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return _row((i) => 0.35 + i * 0.3);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => _row(_alpha),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.merchant, required this.locale, required this.order});

  final String merchant;
  final String locale;
  final int order;

  @override
  Widget build(BuildContext context) {
    // Gerçek yerleşik kurallar: kopya değil, uygulamanın kendisi.
    final key = matchCategory(merchant)?.catalogKey;
    final name = key == null ? '?' : catalogItem(key)!.name(locale);
    final color = categoryVisual(key)?.color ?? Ex.textMuted;
    // Kategori, nottan ~120 ms sonra "çözülür".
    final resolve = kEnterStep * (order * 2) + const Duration(milliseconds: 120);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: BoxDecoration(
        color: Ex.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ex.borderHi),
        boxShadow: _softShadow(),
      ),
      child: Row(
        children: [
          // İşletme adı kısa ve sabit: doğal genişlik; kategori kalan yeri alır.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Ex.surfaceHi,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                merchant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Ex.textSoft),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LoadingDots(color: color),
          ),
          Expanded(
            child: Row(
              children: [
                CategoryAvatar(catalogKey: key, size: 30),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color.lerp(color, Colors.white, 0.45)),
                  ),
                ),
              ],
            ).enterPop(context, baseDelay: resolve),
          ),
        ],
      ),
    );
  }
}

// ── 4) Bütçe ─────────────────────────────────────────────────────────────

/// Büyük gerçek BudgetRing (bir kez dolar) + altında iki kategori sınırı.
class BudgetMock extends StatelessWidget {
  const BudgetMock({
    super.key,
    required this.currency,
    required this.locale,
    required this.title,
  });

  final String currency;
  final String locale;

  /// Halkanın altındaki küçük etiket ("Aylık bütçe").
  final String title;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    return SizedBox(
      width: _mockWidth,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const IntroGlow(color: Ex.brand, size: 300),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, boxShadow: _softShadow()),
                      child: BudgetRing(
                          value: 0.62, over: false, size: 108, animate: !reduce),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatMoneyIn(_scaled(5700), currency)} · $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Ex.onGlowMuted),
                    ),
                  ],
                ).enterPop(context),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final (i, e) in const [
            ('groceries', 0.74),
            ('taxi', 0.38),
          ].indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _LimitBar(
              catalogKey: e.$1,
              name: catalogItem(e.$1)!.name(locale),
              fraction: e.$2,
              // Çubuk, halkayla birlikte bir kez dolar.
              animate: !reduce,
              delay: kEnterStep * (4 + i * 2) + const Duration(milliseconds: 200),
            ).enterUp(context, index: 4 + i * 2, dy: 12),
          ],
        ],
      ),
    );
  }

  /// Örnek tutar para birimine göre makul ölçekte (₺ 5.700 ↔ $ 570).
  double _scaled(double tryAmount) => switch (currency) {
        'TRY' => tryAmount,
        'RUB' => tryAmount * 2.5,
        'KZT' => tryAmount * 13,
        _ => tryAmount / 10,
      };
}

class _LimitBar extends StatelessWidget {
  const _LimitBar({
    required this.catalogKey,
    required this.name,
    required this.fraction,
    required this.animate,
    required this.delay,
  });

  final String catalogKey;
  final String name;
  final double fraction;
  final bool animate;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final color = categoryVisual(catalogKey)?.color ?? Ex.brand;
    final fill = fraction > 0.7 ? Ex.amber : color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Ex.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ex.border),
        boxShadow: _softShadow(),
      ),
      child: Row(
        children: [
          CategoryAvatar(catalogKey: catalogKey, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Ex.text)),
                    ),
                    Text('${(fraction * 100).round()}%',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: fill)),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(color: Ex.surfaceHi),
                        // Bir kez dolar (giriş vuruşu), döngü yok.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: animate ? 0 : fraction, end: fraction),
                          duration: animate
                              ? const Duration(milliseconds: 700) + delay
                              : Duration.zero,
                          curve: Interval(
                            animate ? delay.inMilliseconds / (700 + delay.inMilliseconds) : 0,
                            1,
                            curve: Curves.easeOutCubic,
                          ),
                          builder: (context, v, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: v.clamp(0, 1),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  fill.withValues(alpha: 0.7),
                                  fill,
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
