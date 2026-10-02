import 'package:flutter/material.dart';

import 'ex_style.dart';
import 'tokens.dart';

/// Budgy marka ikonu — yeşil yuvarlak kare üzerinde monoline (çizgisel) zarf.
/// App ikonuyla (konsept 04) birebir aynı sembol. Ölçeklenebilir.
///
/// Dolgu [Ex.brand]: afişteki banknotun koyu yeşili. Eski #0F9E6C krem kâğıt
/// üstünde parlak ve "dijital" duruyordu; app ikonu ile aynı aileden kalsın
/// diye yeşil bırakıldı ama mürekkep ağırlığına çekildi.
class BudgyIcon extends StatelessWidget {
  const BudgyIcon({super.key, this.size = 44, this.radiusFactor = 0.2237});

  final double size;

  /// iOS "squircle" oranı (~22.37%). Wordmark/intro için köşe yumuşaklığı.
  final double radiusFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Ex.brand,
        borderRadius: BorderRadius.circular(size * radiusFactor),
      ),
      child: CustomPaint(painter: _EnvelopePainter()),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1024'lük tasarım ölçeğinden ölçekle.
    final s = size.width / 1024.0;
    // Zarf çizgisi beyaz kalır: koyu yeşil dolgu üstünde en net okunan bu;
    // krem (Ex.bg) kullansak kâğıtla aynı tonda olur ve ikon "delik" görünür.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = Ex.onBrand
      ..strokeWidth = 52 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Zarf gövdesi: rect x216 y336 w592 h384 rx72
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(216 * s, 336 * s, 592 * s, 384 * s),
      Radius.circular(72 * s),
    );
    canvas.drawRRect(body, stroke);

    // Kapak: M244 384 L512 576 L780 384
    final flap = Path()
      ..moveTo(244 * s, 384 * s)
      ..lineTo(512 * s, 576 * s)
      ..lineTo(780 * s, 384 * s);
    canvas.drawPath(flap, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Yatay logo (wordmark): monoline ikon + "Budg" mürekkep + "y" yeşil.
/// Intro, splash, giriş ekranı başlığı ve ayarlar altbilgisi için.
///
/// Eskiden "Budg" yeşil, "y" amberdi. Afiş dilinde tipografi mürekkeptir ve
/// yeşil yalnız para/eylem için ayrılır; iki renkli bir kelime krem kâğıtta
/// logo yerine reklam gibi okunuyordu. Tek vurgu ("y") yeşil kaldı ki ikonla
/// bağ kopmasın.
class BudgyWordmark extends StatelessWidget {
  const BudgyWordmark({
    super.key,
    this.iconSize = 44,
    this.fontSize = 30,
    this.gap = 12,
  });

  final double iconSize;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BudgyIcon(size: iconSize),
        SizedBox(width: gap),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.045 * fontSize,
              height: 1,
            ),
            children: [
              TextSpan(text: 'Budg', style: TextStyle(color: c.text)),
              TextSpan(text: 'y', style: TextStyle(color: c.accent)),
            ],
          ),
        ),
      ],
    );
  }
}
