import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';

/// «Budget Completed» — kutlama ekranı: konfeti + 👍👍 + Continue / Add more.
class BudgetCompletedScreen extends ConsumerWidget {
  const BudgetCompletedScreen({
    super.key,
    required this.onContinue,
    this.onAddMore,
  });

  final VoidCallback onContinue;
  final VoidCallback? onAddMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final str = ref.watch(strProvider);

    // Afiş dili: saf beyaz değil krem kâğıt — diğer ekranlarla aynı zemin,
    // yoksa kutlama ekranı akışın içinde "yabancı" beyaz bir sayfa gibi
    // parlıyordu.
    return Scaffold(
      backgroundColor: Ex.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Confetti()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  const Spacer(),
                  const Text('👍🏽', style: TextStyle(fontSize: 96)),
                  const SizedBox(height: 32),
                  Text(
                    str.budgetDoneTitle,
                    // Afiş başlığı: InterDisplay Black, sıkı aralık —
                    // onboarding'deki kahraman başlıklarla aynı ses.
                    style: const TextStyle(
                      fontFamily: 'InterDisplay',
                      fontSize: 26,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                      color: Ex.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    str.budgetDoneSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, height: 1.5, color: Ex.textSoft),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Ex.brand,
                        foregroundColor: Ex.onBrand,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: onContinue,
                      child: Text(str.continueButton),
                    ),
                  ),
                  if (onAddMore != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          // Krem zeminde yeşil çerçevenin alfası düşük
                          // kalınca kayboluyordu; kenarlık tam marka
                          // yeşili, metin ise okunur koyu yeşil.
                          foregroundColor: Ex.mint,
                          side: const BorderSide(color: Ex.brand),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: onAddMore,
                        child: Text(str.addMore),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üstten düşen renkli konfeti — paketsiz, AnimationController + CustomPainter.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  // Konfeti kasıtlı olarak çok renkli: tek yeşil paletten kutlama çıkmaz.
  // Marka tonları token'dan geliyor; mavi/mor/pembe palette olmadığı için
  // burada sabit — hepsi krem kâğıt üstünde doygun kalacak koyulukta seçildi
  // (açık pastel konfeti zeminde kayboluyordu).
  static const _colors = [
    Ex.brand,
    Ex.amber,
    Ex.red,
    Color(0xFF2F55D4), // mavi
    Color(0xFF6E5BD6), // mor
    Color(0xFFD1458F), // pembe
  ];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    _particles = List.generate(80, (i) {
      return _Particle(
        x: rnd.nextDouble(),
        startY: -0.1 - rnd.nextDouble() * 0.3,
        fall: 0.7 + rnd.nextDouble() * 0.6,
        drift: (rnd.nextDouble() - 0.5) * 0.3,
        size: 6 + rnd.nextDouble() * 8,
        color: _colors[rnd.nextInt(_colors.length)],
        spin: (rnd.nextDouble() - 0.5) * 12,
        phase: rnd.nextDouble(),
        round: rnd.nextBool(),
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // Continue'ya basana kadar dönsün
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(_particles, _c.value),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.startY,
    required this.fall,
    required this.drift,
    required this.size,
    required this.color,
    required this.spin,
    required this.phase,
    required this.round,
  });

  final double x; // 0..1
  final double startY; // negatif (ekran üstü)
  final double fall; // düşme mesafesi (ekran yüksekliği oranı)
  final double drift; // yatay kayma
  final double size;
  final Color color;
  final double spin; // dönüş hızı
  final double phase; // sallanma fazı
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final progress = (t + p.phase) % 1.0;
      final y = (p.startY + progress * p.fall) * size.height;
      if (y < -20 || y > size.height + 20) continue;
      final sway = math.sin((progress * 6 + p.phase * 6)) * 0.04;
      final x = (p.x + p.drift * progress + sway) * size.width;
      // Düşerken solma (son %20'de).
      final fade = progress > 0.8 ? (1 - (progress - 0.8) / 0.2) : 1.0;
      paint.color = p.color.withValues(alpha: fade.clamp(0, 1));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
