import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Halka grafik: sektörler + ortada özet + (Cashly) etrafta yüzen ↑↓% rozetleri.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.centerTitle,
    required this.centerSubtitle,
    this.changes = const [],
  });

  final List<double> values;
  final List<Color> colors;
  final String centerTitle;
  final String centerSubtitle;

  /// values ile paralel: her segmentin geçen aya göre % değişimi (null = yok).
  final List<int?> changes;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    const box = 230.0;
    const center = box / 2;
    final total = values.fold<double>(0, (a, b) => a + b);

    // Sektör orta açısına göre yüzen rozetler.
    final badges = <Widget>[];
    if (total > 0 && changes.isNotEmpty) {
      var start = -math.pi / 2;
      for (var i = 0; i < values.length; i++) {
        final sweep = values[i] / total * 2 * math.pi;
        final mid = start + sweep / 2;
        final change = i < changes.length ? changes[i] : null;
        if (change != null && values[i] > 0) {
          const r = 96.0;
          badges.add(Positioned(
            left: center + r * math.cos(mid),
            top: center + r * math.sin(mid),
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: _SliceBadge(
                  percent: change, color: colors[i % colors.length]),
            ),
          ));
        }
        start += sweep;
      }
    }

    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, p, _) => CustomPaint(
              size: const Size(190, 190),
              painter: _DonutPainter(
                  values: values,
                  colors: colors,
                  progress: p,
                  emptyColor: c.track),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerTitle,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.text),
              ),
              Text(
                centerSubtitle,
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
            ],
          ),
          ...badges,
        ],
      ),
    );
  }
}

/// Donut etrafındaki pay rozeti: segment rengiyle "X%".
class _SliceBadge extends StatelessWidget {
  const _SliceBadge({required this.percent, required this.color});
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text('$percent%',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: c.text)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.emptyColor,
    this.progress = 1,
  });

  final List<double> values;
  final List<Color> colors;
  final Color emptyColor; // boş halka (veri yokken)
  final double progress; // 0..1 — açılışta çizilme

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final rect = Offset.zero & size;
    const stroke = 26.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final arcRect = rect.deflate(stroke / 2);

    if (total <= 0) {
      paint.color = emptyColor;
      canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * progress, false,
          paint);
      return;
    }

    // Tepeden saat yönünde [progress] kadarını çiz.
    const gap = 0.03;
    final limit = progress * 2 * math.pi;
    var start = -math.pi / 2;
    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      final allowed = limit - acc;
      if (allowed > 0) {
        final draw = math.min(math.max(sweep - gap, 0.01), allowed);
        paint.color = colors[i % colors.length];
        canvas.drawArc(arcRect, start + gap / 2, draw, false, paint);
      }
      start += sweep;
      acc += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.progress != progress;
}
