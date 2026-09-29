import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/redesign_l10n.dart';
import '../../core/motion.dart';
import 'onboarding_palette.dart';

// ---------------------------------------------------------------------------
// Dünyalar
// ---------------------------------------------------------------------------

/// Onboarding'de seçilebilen "dünya": kimlik, iki renkli gökyüzü gradyanı ve
/// zeminin koyu mu açık mı olduğu (metin/düğme rengi buna göre ters döner).
///
/// Sayfa kendisi hiçbir ayar yazmaz: seçilen kimlik [ThemePickerPage.onNext]
/// ile dışarı verilir; akış [dark] bayrağına göre koyu/açık tema tercihini
/// kaydeder (bkz. `onboarding_flow.dart`).
class OnboardingWorld {
  const OnboardingWorld({
    required this.id,
    required this.top,
    required this.bottom,
    required this.dark,
  });

  final String id;

  /// Gökyüzü gradyanı: üst ve alt renk.
  final Color top;
  final Color bottom;

  /// Zemin koyu ise metin ve düğme açık (kâğıt), değilse mürekkep.
  final bool dark;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      );

  /// Bu zeminde okunur ana renk.
  Color get ink => dark ? Poster.paper : Poster.ink;

  /// Gövde metni: ana rengin yumuşatılmışı.
  Color get inkSoft => ink.withValues(alpha: dark ? 0.78 : 0.62);
}

/// Dört dünya — sade, karikatür değil: gece (lacivert + ay + yıldız), şafak
/// (turuncu + tepe silueti), orman (yeşil + ağaç silueti), okyanus
/// (turkuaz + dalga).
const kOnboardingWorlds = <OnboardingWorld>[
  OnboardingWorld(
    id: 'night',
    top: Color(0xFF1B2247),
    bottom: Color(0xFF0B0F26),
    dark: true,
  ),
  OnboardingWorld(
    id: 'dawn',
    top: Color(0xFFFFD9A8),
    bottom: Color(0xFFF7935C),
    dark: false,
  ),
  OnboardingWorld(
    id: 'forest',
    top: Color(0xFF2E7D57),
    bottom: Color(0xFF0F3B2B),
    dark: true,
  ),
  OnboardingWorld(
    id: 'ocean',
    top: Color(0xFFB6EFE8),
    bottom: Color(0xFF3AB8B5),
    dark: false,
  ),
];

/// Arka planın bir dünyadan diğerine akış süresi.
const _worldSwitch = Duration(milliseconds: 420);

/// Dünya kimliği → RS'deki adı.
String _worldName(RS rs, String id) => switch (id) {
      'night' => rs.worldNight,
      'dawn' => rs.worldDawn,
      'forest' => rs.worldForest,
      'ocean' => rs.worldOcean,
      _ => id,
    };

// ---------------------------------------------------------------------------
// Tema seçimi
// ---------------------------------------------------------------------------

/// Tema seçimi — seçim canlı olarak arka plana yansır.
///
/// Kartlar yatay kayar; bir kart seçilince tüm sayfa zemini yumuşak geçişle o
/// dünyanın gökyüzüne döner, metin ve düğme zemine göre açık/koyu olur.
/// "Hadi başlayalım" [onNext]'e seçilen dünyanın kimliğini verir
/// (`kOnboardingWorlds` içindeki `id`).
class ThemePickerPage extends ConsumerStatefulWidget {
  const ThemePickerPage({super.key, required this.onNext});

  final void Function(String themeId) onNext;

  @override
  ConsumerState<ThemePickerPage> createState() => _ThemePickerPageState();
}

class _ThemePickerPageState extends ConsumerState<ThemePickerPage> {
  /// Başlangıçta ikinci dünya (şafak): açık zemin, beyaz afişten yumuşak
  /// devam eder; kullanıcı ilk dokunuşta "gece"ye geçince fark çarpıcı olur.
  int _selected = 1;

  OnboardingWorld get _world => kOnboardingWorlds[_selected];

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final instant = reduceMotion(context);
    final duration = instant ? Duration.zero : _worldSwitch;
    final world = _world;
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 340;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(gradient: world.gradient),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 16),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FinaleTitle(
                          rs.worldTitle,
                          color: world.ink,
                          maxWidth: width - 40,
                          size: narrow ? 32 : 36,
                          duration: duration,
                        ),
                        const SizedBox(height: 12),
                        AnimatedDefaultTextStyle(
                          duration: duration,
                          style: _bodyStyle.copyWith(color: world.inkSoft),
                          child: Text(rs.worldSubtitle),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: _WorldCard.height + 24,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: kOnboardingWorlds.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final w = kOnboardingWorlds[i];
                        return _WorldCard(
                          key: ValueKey('world-${w.id}'),
                          world: w,
                          label: _worldName(rs, w.id),
                          selected: i == _selected,
                          ringColor: world.ink,
                          duration: duration,
                          onTap: () => setState(() => _selected = i),
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: duration,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.35,
                            color: world.ink.withValues(alpha: 0.55),
                          ),
                          textAlign: TextAlign.center,
                          child: Text(rs.worldFootnote, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: _FinalePillButton(
                            label: rs.worldGo,
                            fill: world.ink,
                            textColor: world.dark ? Poster.ink : Poster.paper,
                            duration: duration,
                            onTap: () => widget.onNext(world.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bir dünyanın kartı: köşeleri yuvarlak resim, altta ad; seçiliyken zemin
/// mürekkebi renginde halka ve tam ölçek, değilken hafif küçük.
class _WorldCard extends StatelessWidget {
  const _WorldCard({
    super.key,
    required this.world,
    required this.label,
    required this.selected,
    required this.ringColor,
    required this.duration,
    required this.onTap,
  });

  static const double width = 150;
  static const double height = 200;

  final OnboardingWorld world;
  final String label;
  final bool selected;
  final Color ringColor;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: selected ? 1 : 0.94,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: duration,
            width: width,
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? ringColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _WorldPainter(world)),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'InterDisplay',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: world.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dünya resmi — dosya yok, her şey vektör. Şekiller kart oranına göre
/// (0..1) çizilir ki 150×200 kartta da, ileride büyük bir önizlemede de aynı
/// dursun.
class _WorldPainter extends CustomPainter {
  const _WorldPainter(this.world);

  final OnboardingWorld world;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = world.gradient.createShader(rect));
    switch (world.id) {
      case 'night':
        _night(canvas, size);
      case 'dawn':
        _dawn(canvas, size);
      case 'forest':
        _forest(canvas, size);
      case 'ocean':
        _ocean(canvas, size);
    }
  }

  /// Gece: dağınık küçük yıldızlar, hilal, altta koyu tepe.
  void _night(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final star = Paint()..color = Colors.white.withValues(alpha: 0.85);
    // Sabit tohum: her çizimde aynı gökyüzü.
    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.62;
      final r = 0.6 + rnd.nextDouble() * 1.1;
      canvas.drawCircle(Offset(x, y), r, star);
    }
    // Hilal: dolu daireden kaydırılmış daire çıkarılır.
    final c = Offset(w * 0.68, h * 0.26);
    final r = w * 0.13;
    final moon = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()
      ..addOval(Rect.fromCircle(center: c.translate(r * 0.45, -r * 0.2), radius: r * 0.88));
    canvas.drawPath(
      Path.combine(PathOperation.difference, moon, bite),
      Paint()..color = const Color(0xFFF3E9C8),
    );
    // Tepe silueti.
    final hill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.3, h * 0.62, w * 0.55, h * 0.78)
      ..quadraticBezierTo(w * 0.8, h * 0.9, w, h * 0.74)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF070A1A));
  }

  /// Şafak: ufukta güneş, önünde iki tepe silueti.
  void _dawn(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.62),
      w * 0.2,
      Paint()..color = const Color(0xFFFFF1C7),
    );
    final back = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.25, h * 0.5, w * 0.5, h * 0.66)
      ..quadraticBezierTo(w * 0.75, h * 0.82, w, h * 0.6)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFFD9694A));
    final front = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.35, h * 0.7, w * 0.62, h * 0.84)
      ..quadraticBezierTo(w * 0.85, h * 0.94, w, h * 0.82)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF9C3F2E));
  }

  /// Orman: sis bandı, arkada açık çamlar, önde koyu çamlar, zemin.
  void _forest(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.5, w, h * 0.18),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    void tree(double cx, double base, double height, Color color) {
      final half = height * 0.32;
      final p = Paint()..color = color;
      // Üç katlı çam: üst üste üç üçgen.
      for (var k = 0; k < 3; k++) {
        final top = base - height + k * height * 0.22;
        final bottom = base - height * (0.55 - k * 0.22);
        final spread = half * (0.55 + k * 0.25);
        canvas.drawPath(
          Path()
            ..moveTo(cx, top)
            ..lineTo(cx - spread, bottom)
            ..lineTo(cx + spread, bottom)
            ..close(),
          p,
        );
      }
    }

    const back = Color(0xFF1B5A40);
    const front = Color(0xFF082619);
    for (final x in [0.12, 0.38, 0.64, 0.9]) {
      tree(w * x, h * 0.8, h * 0.3, back);
    }
    for (final x in [0.05, 0.28, 0.52, 0.78, 1.0]) {
      tree(w * x, h * 0.92, h * 0.38, front);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.9, w, h * 0.1),
      Paint()..color = front,
    );
  }

  /// Okyanus: solgun güneş, üç dalga bandı (arkadan öne koyulaşır).
  void _ocean(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(
      Offset(w * 0.3, h * 0.3),
      w * 0.09,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    Path wave(double baseline, double amp, double phase) {
      final p = Path()..moveTo(0, h);
      p.lineTo(0, baseline + amp * math.sin(phase));
      const steps = 24;
      for (var i = 1; i <= steps; i++) {
        final x = w * i / steps;
        final y = baseline + amp * math.sin(phase + i / steps * math.pi * 2.2);
        p.lineTo(x, y);
      }
      p
        ..lineTo(w, h)
        ..close();
      return p;
    }

    canvas.drawPath(
      wave(h * 0.66, h * 0.025, 0.4),
      Paint()..color = const Color(0xFF63CFC8),
    );
    canvas.drawPath(
      wave(h * 0.78, h * 0.03, 2.1),
      Paint()..color = const Color(0xFF2A9E9C),
    );
    canvas.drawPath(
      wave(h * 0.9, h * 0.025, 4.0),
      Paint()..color = const Color(0xFF1C7A7A),
    );
  }

  @override
  bool shouldRepaint(_WorldPainter old) => old.world != world;
}

// ---------------------------------------------------------------------------
// Karşılama: düşen paralar
// ---------------------------------------------------------------------------

/// Kutlama ekranı; [onDone] animasyon bitince çağrılır.
///
/// 16 madeni para farklı gecikme, boy, dönüş ve konumla yukarıdan düşer,
/// yere sekerek yerleşir; ortada karşılama başlığı belirir. Tek seferlik
/// [AnimationController], ~1,8 s. Hareket azaltmada paralar yerleşik son
/// karede çizilir ve [onDone] ilk kareden sonra çağrılır.
class WelcomeBurstPage extends ConsumerStatefulWidget {
  const WelcomeBurstPage({super.key, required this.onDone});

  final VoidCallback onDone;

  /// Toplam süre (yerleşme + kısa bekleme).
  static const duration = Duration(milliseconds: 1800);

  @override
  ConsumerState<WelcomeBurstPage> createState() => _WelcomeBurstPageState();
}

class _WelcomeBurstPageState extends ConsumerState<WelcomeBurstPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: WelcomeBurstPage.duration,
  );
  late final List<_Coin> _coins = _Coin.scatter(16);
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    // reduceMotion MediaQuery ister; ilk kareden sonra bakılır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reduceMotion(context)) {
        _ctrl.value = 1; // yerleşik son kare
        _finish();
      } else {
        _ctrl.forward();
      }
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 340;
    return ColoredBox(
      color: Poster.paper,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Paralar: tüm sayfa üstünde, metnin arkasında.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => CustomPaint(
                painter: _CoinRainPainter(coins: _coins, t: _ctrl.value),
              ),
            ),
          ),
          // Metin: paralar yere yaklaşırken (0,35 → 0,75) belirir.
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  final p = const Interval(0.35, 0.75, curve: Curves.easeOut)
                      .transform(_ctrl.value);
                  return Opacity(
                    opacity: p,
                    child: Transform.translate(
                      offset: Offset(0, (1 - p) * 10),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FinaleTitle(
                      rs.welcomeBurstTitle,
                      color: Poster.ink,
                      maxWidth: width - 56,
                      size: narrow ? 32 : 36,
                      duration: Duration.zero,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rs.welcomeBurstSub,
                      textAlign: TextAlign.center,
                      style: _bodyStyle.copyWith(color: Poster.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir paranın hareket parametreleri; hepsi 0..1 aralığında, ekran boyutu
/// çizimde uygulanır.
class _Coin {
  const _Coin({
    required this.x,
    required this.rest,
    required this.delay,
    required this.size,
    required this.spin,
    required this.tilt,
  });

  /// Yatay konum (genişliğin oranı).
  final double x;

  /// Yerleşeceği yükseklik (yüksekliğin oranı, alt bölgede dağınık).
  final double rest;

  /// Düşmeye başlama anı (toplam sürenin oranı).
  final double delay;

  /// Çap (px).
  final double size;

  /// Toplam dönüş (radyan) — para düşerken kendi ekseninde döner. π'nin
  /// katı: yere yüzü yukarı iner, kenar üstünde durmaz.
  final double spin;

  /// Düz duruşta ufak eğim (radyan), hepsi aynı hizada durmasın.
  final double tilt;

  /// [n] para, sabit tohumla dağıtılır: her açılışta aynı, testte kararlı.
  static List<_Coin> scatter(int n) {
    final rnd = math.Random(42);
    return [
      for (var i = 0; i < n; i++)
        _Coin(
          // Genişliğe düzgün yay, hafif rastgele kaydır.
          x: ((i + 0.5) / n + (rnd.nextDouble() - 0.5) * 0.08).clamp(0.05, 0.95),
          rest: 0.80 + rnd.nextDouble() * 0.14,
          delay: rnd.nextDouble() * 0.3,
          size: 18 + rnd.nextDouble() * 12,
          spin: (rnd.nextBool() ? 1 : -1) * math.pi * (2 + rnd.nextInt(2)),
          tilt: (rnd.nextDouble() - 0.5) * 0.4,
        ),
    ];
  }
}

/// Paraları çizer: her para kendi gecikmesinden sonra, yerçekimi hissi için
/// [Curves.bounceOut] ile düşüp sekerek yerleşir; düşerken Y ekseninde döner
/// (ölçek = cos), böylece madeni para "takla atıyor" hissi verir.
class _CoinRainPainter extends CustomPainter {
  const _CoinRainPainter({required this.coins, required this.t});

  final List<_Coin> coins;
  final double t;

  /// Düşüşün toplam sürede kapladığı pay (gerisi bekleme).
  static const _fallShare = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      final local = ((t - c.delay) / _fallShare).clamp(0.0, 1.0);
      if (local <= 0) continue; // henüz düşmeye başlamadı
      final fall = Curves.bounceOut.transform(local);
      final startY = -c.size;
      final endY = size.height * c.rest;
      final y = startY + (endY - startY) * fall;
      final x = size.width * c.x;
      // Dönüş düşüşle biter, yerde sabit eğim kalır.
      final angle = c.spin * Curves.easeOut.transform(local) + c.tilt;
      canvas.save();
      canvas.translate(x, y);
      // Yatay ölçek cos(açı): kenar görünümünde incelir, yüzde tam daire.
      final flip = math.cos(angle).abs().clamp(0.18, 1.0);
      canvas.scale(flip, 1);
      _drawCoin(canvas, c.size / 2);
      canvas.restore();
    }
  }

  /// Tek para: altın dolgu, koyu kenar, iç halka, sol üstte parlama.
  static void _drawCoin(Canvas canvas, double r) {
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFF2C14E));
    canvas.drawCircle(
      Offset.zero,
      r - 1,
      Paint()
        ..color = const Color(0xFFC8962B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.62,
      Paint()
        ..color = const Color(0xFFC8962B).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.32, -r * 0.36),
        width: r * 0.55,
        height: r * 0.32,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_CoinRainPainter old) => old.t != t || old.coins != coins;
}

// ---------------------------------------------------------------------------
// Ortak parçalar (onboarding_flow.dart'takilerin bu dosyaya özel eşdeğerleri)
// ---------------------------------------------------------------------------

/// Gövde metni: Inter.
const _bodyStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 16,
  height: 1.4,
);

/// İç sayfa display başlığı: Inter Display Black 36/32 px, sıkı harfler.
/// En uzun sözcük satıra sığmıyorsa punto o sözcük sığana kadar küçülür
/// (TR "başlayalım", RU "Добро пожаловать" gibi). Renk [duration] ile akar.
class _FinaleTitle extends StatelessWidget {
  const _FinaleTitle(
    this.text, {
    required this.color,
    required this.maxWidth,
    required this.size,
    required this.duration,
    this.align = TextAlign.start,
  });

  final String text;
  final Color color;
  final double maxWidth;
  final double size;
  final Duration duration;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    TextStyle styleAt(double s) => TextStyle(
          fontFamily: 'InterDisplay',
          fontWeight: FontWeight.w900,
          fontSize: s,
          height: 0.98,
          letterSpacing: -1.5 * (s / size),
          color: color,
        );
    final longest = text
        .split(RegExp(r'\s+'))
        .reduce((a, b) => a.length >= b.length ? a : b);
    final painter = TextPainter(
      text: TextSpan(text: longest, style: styleAt(size)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    var fitted = size;
    if (painter.width > maxWidth) {
      fitted = (size * maxWidth / painter.width).floorToDouble();
    }
    painter.dispose();
    return AnimatedDefaultTextStyle(
      duration: duration,
      style: styleAt(fitted),
      textAlign: align,
      child: Text(text, textAlign: align),
    );
  }
}

/// Siyah hap düğmenin bu sayfaya özel hâli: zemin koyuysa kâğıt rengine
/// döner (siyah lacivertte kaybolur). Renk geçişi zeminle aynı sürede.
class _FinalePillButton extends StatelessWidget {
  const _FinalePillButton({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 15, 30, 15),
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: TextStyle(
                fontFamily: 'InterDisplay',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: textColor,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}
