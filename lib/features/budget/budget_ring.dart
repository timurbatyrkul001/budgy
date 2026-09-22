import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ex_style.dart';

/// Bütçe halkası: harcanan oran dolarak gelir, sınır aşılınca kırmızıya
/// döner. Ortadaki yüzde de aynı animasyonla sayar.
///
/// Bilerek paketsiz (CustomPainter + örtük animasyon): uygulama boyutunu
/// artırmaz ve Rive'a geçilecekse aynı iki girdiyle sürülür —
/// [value] → `progress` (0-100), [over] → `over` (bool).
class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.value,
    required this.over,
    this.size = 84,
    this.animate = true,
  });

  /// Harcanan / bütçe. 1'in üstü aşım demektir (halka dolu kalır).
  final double value;
  final bool over;
  final double size;

  /// false: halka anında yerleşik durumda çizilir (hareket azaltma).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final target = value.isFinite && value > 0 ? value : 0.0;
    final color = over ? Ex.red : Ex.brand;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : target, end: target),
      duration: animate ? const Duration(milliseconds: 900) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: v.clamp(0, 1),
            color: color,
            stroke: size * 0.12,
          ),
          child: Center(
            child: Text(
              '${(v * 100).round()}%',
              style: TextStyle(
                fontSize: size * 0.24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Ex.surfaceHi;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Saat 12'den başlayıp saat yönünde dolar.
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}
