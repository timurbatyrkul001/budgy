import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// Плавная линия динамики баланса за месяц (как на главной Lume):
/// градиентная заливка снизу и точка на конце.
class BalanceChart extends StatelessWidget {
  const BalanceChart({super.key, required this.points});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(points)),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.points);

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.01 ? 1.0 : max - min;
    // Отступы, чтобы линия не липла к краям.
    const padTop = 10.0;
    const padBottom = 14.0;
    final h = size.height - padTop - padBottom;

    Offset pointAt(int i) {
      final x = size.width * i / (points.length - 1);
      final y = padTop + h * (1 - (points[i] - min) / span);
      return Offset(x, y);
    }

    // Плавная кривая через средние точки.
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = pointAt(i);
      final next = pointAt(i + 1);
      final mid = Offset(
          (current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    final last = pointAt(points.length - 1);
    path.lineTo(last.dx, last.dy);

    // Заливка под линией.
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Точка на конце линии.
    canvas.drawCircle(last, 5, Paint()..color = accent);
    canvas.drawCircle(last, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.points != points;
}
