import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/redesign_l10n.dart';
import '../../core/motion.dart';
import 'onboarding_palette.dart';

// ---------------------------------------------------------------------------
// Dünyalar
// ---------------------------------------------------------------------------

/// Onboarding'de seçilebilen "dünya": kimlik, iki renkli gökyüzü gradyanı ve
/// zeminin koyu mu açık mı olduğu (metin/düğme rengi buna göre ters döner).
///
/// Dünya YALNIZ bu sayfanın gökyüzüdür — uygulama teması değil. Sayfa hiçbir
/// ayar yazmaz: seçilen kimlik [WorldPickerPage.onNext] ile dışarı verilir;
/// akış onu yalnız anket cevabı (`onboardingAnswers.world`) olarak saklar.
/// Eskiden [dark] bayrağından bir tema tercihi (`themeMode`) türetiliyordu;
/// uygulama tek temalı olduğu için o yazma kaldırıldı — mekanizma
/// (`themeModeProvider`, `setThemeMode`) 1.1 için yerinde bekliyor.
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

/// Arka planın bir dünyadan diğerine akış süresi. Akış da aynı süreyi
/// kullanıyor: zemini o boyuyor (tam sayfa), sayfa yalnız içeriği.
const kWorldSwitch = Duration(milliseconds: 420);

/// Dünya kimliği → RS'deki adı.
String _worldName(RS rs, String id) => switch (id) {
  'night' => rs.worldNight,
  'dawn' => rs.worldDawn,
  'forest' => rs.worldForest,
  'ocean' => rs.worldOcean,
  _ => id,
};

// ---------------------------------------------------------------------------
// Dünya seçimi
// ---------------------------------------------------------------------------

/// Dünya seçimi — seçim canlı olarak bu sayfanın arka planına yansır.
///
/// Kartlar yatay kayar; bir kart seçilince tüm sayfa zemini yumuşak geçişle o
/// dünyanın gökyüzüne döner, metin ve düğme zemine göre açık/koyu olur.
/// "Hadi başlayalım" [onNext]'e seçilen dünyanın kimliğini verir
/// (`kOnboardingWorlds` içindeki `id`).
///
/// Metinler bilinçli olarak tema VAAT ETMEZ ("görünüm tercihi olarak
/// kaydedilir" yok): seçimin tek görünür etkisi bu ekranın gökyüzü, ve
/// metin tam olarak bunu söyler. Uygulama geneline tema 1.1'de.
class WorldPickerPage extends ConsumerStatefulWidget {
  const WorldPickerPage({
    super.key,
    required this.onNext,
    required this.onWorldChanged,
  });

  final void Function(String worldId) onNext;

  /// Seçim değiştikçe akışa haber verir: gökyüzünü akış çiziyor, böylece
  /// gradyan durum çubuğunun ve alt güvenli alanın arkasına da geçiyor.
  final void Function(OnboardingWorld world) onWorldChanged;

  @override
  ConsumerState<WorldPickerPage> createState() => _WorldPickerPageState();
}

class _WorldPickerPageState extends ConsumerState<WorldPickerPage> {
  /// Başlangıçta ikinci dünya (şafak): açık zemin, beyaz afişten yumuşak
  /// devam eder; kullanıcı ilk dokunuşta "gece"ye geçince fark çarpıcı olur.
  int _selected = 1;

  OnboardingWorld get _world => kOnboardingWorlds[_selected];

  @override
  void initState() {
    super.initState();
    // İlk kare çizilmeden akışa haber veremeyiz (setState sırası); açılışta
    // gökyüzü zaten şafak, akış da onu bekliyor.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onWorldChanged(_world),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final instant = reduceMotion(context);
    final duration = instant ? Duration.zero : kWorldSwitch;
    final world = _world;
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 340;

    // Gökyüzünü akış çiziyor (tam sayfa); burada yalnız içerik var.
    return LayoutBuilder(
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
                      horizontal: 20,
                      vertical: 12,
                    ),
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
                        onTap: () {
                          setState(() => _selected = i);
                          widget.onWorldChanged(_world);
                        },
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
                        child: Text(
                          rs.worldFootnote,
                          textAlign: TextAlign.center,
                        ),
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
      ..addOval(
        Rect.fromCircle(
          center: c.translate(r * 0.45, -r * 0.2),
          radius: r * 0.88,
        ),
      );
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
  const WelcomeBurstPage({
    super.key,
    required this.onDone,
    this.currencyCode = 'TRY',
  });

  final VoidCallback onDone;

  /// Uçan banknotların üstündeki simge, kullanıcının az önce seçtiği para
  /// biriminden gelir: kendi parası uçuyor, yabancı bir dolar değil.
  final String currencyCode;

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
        _ctrl.value = 1; // yerleşik son kare, süzülme yok
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
          BillRain(currencyCode: widget.currencyCode, fall: _ctrl),
          // Paralar artık sayfanın tamamına dağıldığı için yazının arkasına
          // kâğıt renginde yumuşak bir hale konuyor: başlık paraların
          // üstünde okunur kalsın, ama kesik bir kutu görünmesin.
          IgnorePointer(
            child: Center(
              child: SizedBox(
                height: 320,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        Poster.paper,
                        Poster.paper.withValues(alpha: 0.92),
                        Poster.paper.withValues(alpha: 0),
                      ],
                      // Geçiş erken başlayıp uzun sürüyor: kenarda yarım
                      // silinmiş para değil, yumuşak bir sis kalıyor.
                      stops: const [0, 0.3, 1],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
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
                  final p = const Interval(
                    0.35,
                    0.75,
                    curve: Curves.easeOut,
                  ).transform(_ctrl.value);
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

/// Ekranı kaplayan banknot yağmuru — kutlama ve kapanış sayfalarının ortak
/// zemini. İkisinde de aynı tohumla (42) dizildiği için banknotlar aynı
/// yerde duruyor: sayfa değişince yağmur baştan başlamış gibi olmuyor.
///
/// [fall] giriş animasyonu; tamamlanmış bir animasyon verilirse (kapanış
/// sayfası) banknotlar yerleşmiş hâlde açılır. Yerleştikten sonra hepsi
/// yavaşça süzülmeye devam eder — süzülme bu widget'ın kendi saatinden
/// geliyor ve o saat asla durmuyor, bu yüzden testlerde `pumpAndSettle`
/// yerine ölçülü `pump` kullanılmalı.
class BillRain extends StatefulWidget {
  const BillRain({super.key, required this.currencyCode, required this.fall});

  /// Banknotların üstündeki simge bu koddan gelir.
  final String currencyCode;

  /// Düşüş ilerlemesi 0..1.
  final Animation<double> fall;

  @override
  State<BillRain> createState() => _BillRainState();
}

class _BillRainState extends State<BillRain>
    with SingleTickerProviderStateMixin {
  /// Süzülme saati: 60 sn'de bir başa sarar, değeri saniyeye çevrilip faz
  /// olarak kullanılır.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  late final List<_Bill> _bills = _Bill.scatter(30);
  late final ui.Paragraph _symbol = _buildSymbol(
    kCurrencies[widget.currencyCode] ?? '₺',
  );

  @override
  void initState() {
    super.initState();
    // reduceMotion MediaQuery ister; ilk kareden sonra bakılır. Hareket
    // azaltmada banknotlar yerinde durur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !reduceMotion(context)) _idle.repeat();
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.fall, _idle]),
        builder: (_, _) => CustomPaint(
          painter: _BillRainPainter(
            bills: _bills,
            symbol: _symbol,
            t: widget.fall.value,
            idle: _idle.value * 60,
          ),
        ),
      ),
    );
  }
}

/// Uçan bir banknotun hareket parametreleri; hepsi 0..1 aralığında, ekran
/// boyutu çizimde uygulanır.
class _Bill {
  const _Bill({
    required this.x,
    required this.rest,
    required this.delay,
    required this.width,
    required this.spin,
    required this.tilt,
    required this.phase,
    required this.drift,
  });

  /// Yatay konum (genişliğin oranı).
  final double x;

  /// Yerleşeceği yükseklik (yüksekliğin oranı). Alt şeride değil, sayfanın
  /// tamamına yayılır: banknotlar arkada duran bir doku gibi kalır.
  final double rest;

  /// Düşmeye başlama anı (toplam sürenin oranı).
  final double delay;

  /// Banknot genişliği (px); yükseklik [_kBillRatio] ile türetilir.
  final double width;

  /// Toplam dönüş (radyan) — banknot düşerken kendi ekseninde takla atar.
  final double spin;

  /// Düz duruşta ufak eğim (radyan), hepsi aynı hizada durmasın.
  final double tilt;

  /// Yerleştikten sonraki süzülmenin faz kayması — hepsi aynı anda aynı
  /// yöne gitmesin diye.
  final double phase;

  /// Süzülme genliği (px).
  final double drift;

  /// [n] banknot, sabit tohumla dağıtılır: her açılışta aynı, testte kararlı.
  ///
  /// Aynı satıra denk gelmesinler diye yükseklik sırayla taranır (i/n) ve
  /// üstüne ufak sapma biner.
  static List<_Bill> scatter(int n) {
    final rnd = math.Random(42);
    return [
      for (var i = 0; i < n; i++)
        _Bill(
          x: (rnd.nextDouble() * 0.86 + 0.07).clamp(0.07, 0.93),
          rest: (((i + 0.5) / n) * 0.9 + 0.05 + (rnd.nextDouble() - 0.5) * 0.06)
              .clamp(0.04, 0.96),
          delay: rnd.nextDouble() * 0.45,
          width: 46 + rnd.nextDouble() * 30,
          spin: (rnd.nextBool() ? 1 : -1) * math.pi * (2 + rnd.nextInt(2)),
          tilt: (rnd.nextDouble() - 0.5) * 0.5,
          phase: rnd.nextDouble() * math.pi * 2,
          drift: 5 + rnd.nextDouble() * 8,
        ),
    ];
  }
}

/// Banknot en/boy oranı (gerçek kâğıt paraya yakın).
const _kBillRatio = 0.46;

/// Marka yeşili ailesi: beyaz afiş burada bitiyor, uygulama bu renkle
/// açılıyor — finalin işi o geçişi hazırlamak.
///
/// Kapanış sayfasındaki zarfın içinden görünen banknot da aynı üçlüyü
/// kullanıyor (`widgets/budgy_money_envelope.dart`): iki sayfadaki kâğıt
/// para tek bir yerden renk alsın.
const kBillFill = Color(0xFF3FA97C);
const kBillEdge = Color(0xFF1F7B57);
const kBillInk = Color(0xFF0E3F2D);

/// Para birimi simgesini bir kez dizer; çizimde banknot genişliğine göre
/// ölçekleniyor, böylece her karede TextPainter kurulmuyor.
ui.Paragraph _buildSymbol(String symbol) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'InterDisplay',
            fontSize: 100,
            fontWeight: FontWeight.w900,
            textAlign: TextAlign.center,
          ),
        )
        ..pushStyle(ui.TextStyle(color: kBillInk.withValues(alpha: 0.55)))
        ..addText(symbol);
  return builder.build()..layout(const ui.ParagraphConstraints(width: 120));
}

/// Banknotları çizer: her biri kendi gecikmesinden sonra [Curves.bounceOut]
/// ile süzülüp yerleşir, düşerken kendi ekseninde takla atar (yatay ölçek =
/// cos), yerleştikten sonra da yavaşça salınmaya devam eder.
class _BillRainPainter extends CustomPainter {
  const _BillRainPainter({
    required this.bills,
    required this.symbol,
    required this.t,
    required this.idle,
  });

  final List<_Bill> bills;
  final ui.Paragraph symbol;

  /// Giriş ilerlemesi 0..1 (düşüş).
  final double t;

  /// Yerleştikten sonra duran saniye — süzülme buradan geliyor, sayfa açık
  /// kaldığı sürece artar.
  final double idle;

  /// Düşüşün toplam sürede kapladığı pay (gerisi bekleme).
  static const _fallShare = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bills) {
      final local = ((t - b.delay) / _fallShare).clamp(0.0, 1.0);
      if (local <= 0) continue; // henüz düşmeye başlamadı
      final fall = Curves.bounceOut.transform(local);
      final startY = -b.width;
      final endY = size.height * b.rest;
      // Yerleştikten sonra yerinde durmuyor: dikeyde tam, yatayda yarım
      // periyot salınım — sayfa canlı kalıyor, hepsi aynı yöne gitmiyor.
      final settled = local >= 1 ? 1.0 : 0.0;
      final w = idle * 0.9 + b.phase;
      final y =
          startY + (endY - startY) * fall + settled * math.sin(w) * b.drift;
      final x = size.width * b.x + settled * math.cos(w * 0.5) * b.drift * 0.7;
      // Takla düşüşle biter; yerleşince çok yavaş salınarak sürer.
      final angle =
          b.spin * Curves.easeOut.transform(local) +
          b.tilt +
          settled * math.sin(w * 0.35) * 0.5;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.tilt + settled * math.sin(w * 0.4) * 0.12);
      // Yatay ölçek cos(açı): kenarından görününce incelir, yüzde tam boy.
      canvas.scale(math.cos(angle).abs().clamp(0.12, 1.0), 1);
      _drawBill(canvas, b.width, symbol);
      canvas.restore();
    }
  }

  /// Tek banknot: yeşil dolgu, koyu kenar, iç çerçeve, ortada para birimi
  /// simgesi ve iki yanında ufak çizgiler.
  static void _drawBill(Canvas canvas, double w, ui.Paragraph symbol) {
    final h = w * _kBillRatio;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(rect, Paint()..color = kBillFill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = kBillEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025,
    );
    // İç çerçeve: gerçek banknotlardaki ince kenar süsü.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.86, height: h * 0.74),
        Radius.circular(w * 0.03),
      ),
      Paint()
        ..color = kBillEdge.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014,
    );
    // İki yanda üçer çizgi — uzaktan "yazı" hissi, okunacak bir şey yok.
    final line = Paint()
      ..color = kBillEdge.withValues(alpha: 0.45)
      ..strokeWidth = h * 0.045
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      final dy = i * h * 0.16;
      canvas.drawLine(Offset(-w * 0.36, dy), Offset(-w * 0.22, dy), line);
      canvas.drawLine(Offset(w * 0.22, dy), Offset(w * 0.36, dy), line);
    }
    // Simge: 100 punto dizildi, banknot boyuna indiriliyor.
    final scale = h * 0.62 / 100;
    canvas.save();
    canvas.scale(scale);
    canvas.drawParagraph(symbol, Offset(-60, -symbol.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BillRainPainter old) =>
      old.t != t || old.idle != idle || old.bills != bills;
}

// ---------------------------------------------------------------------------
// Ortak parçalar (onboarding_flow.dart'takilerin bu dosyaya özel eşdeğerleri)
// ---------------------------------------------------------------------------

/// Gövde metni: Inter.
const _bodyStyle = TextStyle(fontFamily: 'Inter', fontSize: 16, height: 1.4);

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
