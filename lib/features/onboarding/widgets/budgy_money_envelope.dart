import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../onboarding_finale.dart' show kBillEdge, kBillFill, kBillInk;
import '../onboarding_palette.dart';

/// Onboarding'in kapanış işareti: Budgy'nin zarfı, içinde para.
///
/// Zarfın geometrisi `assets/icon/budgy_icon_fg.svg` ile birebir aynı
/// (592×384 gövde, r=72, kontur 52, kapak 28,48 → 296,240 → 564,48); tek
/// eklenen şey arkadan görünen banknot. Kapak hafifçe aralanıp kapanıyor,
/// banknot bir parmak yükselip iniyor — başka hiçbir hareket yok.
///
/// Resim/Lottie yok, hepsi [CustomPainter].
class BudgyMoneyEnvelope extends StatefulWidget {
  const BudgyMoneyEnvelope({
    super.key,
    required this.size,
    required this.semanticsLabel,
    this.currencySymbol = '',
    this.sealed = false,
    this.onSealed,
  });

  /// Zarfın genişliği; yükseklik simgenin oranından türüyor.
  final double size;

  /// Ekran okuyucu için; sayfanın dilinden gelir.
  final String semanticsLabel;

  /// Banknotun üstündeki simge — kullanıcının seçtiği para birimi.
  final String currencySymbol;

  /// Hesap bağlandı: kapak sıkıca kapanır, para içeri iner, kapağın üstünde
  /// kısa bir onay işareti belirir.
  final bool sealed;

  /// Mühürleme bitti — sayfa bundan sonra ilerleyebilir.
  final VoidCallback? onSealed;

  /// Sakin döngünün uzunluğu.
  static const loop = Duration(milliseconds: 4000);

  /// [sealed] true olduktan sonra geçişin beklemesi gereken süre: kapanma +
  /// onay işareti.
  static const sealDuration = Duration(milliseconds: 650);

  @override
  State<BudgyMoneyEnvelope> createState() => _BudgyMoneyEnvelopeState();
}

// ---------------------------------------------------------------------------
// Zaman çizelgesi — [BudgyMoneyEnvelope.loop] içindeki oran
// ---------------------------------------------------------------------------

/// 1,2 sn: kapak aralanır, para yükselir.
const _tOpenEnd = 1.2 / 4.0;

/// 1,8 sn: açık bekleme.
const _tHoldEnd = 1.8 / 4.0;

/// 3,0 sn: her şey geri kapanır.
const _tCloseEnd = 3.0 / 4.0;

class _BudgyMoneyEnvelopeState extends State<BudgyMoneyEnvelope>
    with SingleTickerProviderStateMixin {
  /// Tek controller iki işi birden görüyor: 0..1 sakin döngü, −1..0 ise
  /// mühürleme. Böylece mühürleme için ikinci bir ticker açmaya gerek yok.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: BudgyMoneyEnvelope.loop,
    lowerBound: -1,
    upperBound: 1,
  );

  ui.Paragraph? _symbol;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _symbol = _buildSymbol(widget.currencySymbol);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = reduceMotion(context);
    if (still == _still && (_ctrl.isAnimating || _still)) return;
    _still = still;
    if (still || widget.sealed) {
      _ctrl.stop();
      _ctrl.value = 0; // kapak kapalı, para görünür: duruş pozu
    } else {
      _ctrl.repeat(min: 0, max: 1);
    }
  }

  @override
  void didUpdateWidget(BudgyMoneyEnvelope old) {
    super.didUpdateWidget(old);
    if (widget.currencySymbol != old.currencySymbol) {
      _symbol = _buildSymbol(widget.currencySymbol);
    }
    if (widget.sealed && !old.sealed) _seal();
  }

  /// Nerede olursa olsun kapağı kapatıp mühürleme aralığına geçer; sonunda
  /// [BudgyMoneyEnvelope.onSealed] tetiklenir.
  Future<void> _seal() async {
    _ctrl.stop();
    await _ctrl.animateTo(
      -1,
      duration: BudgyMoneyEnvelope.sealDuration,
      curve: Curves.easeInOutCubic,
    );
    if (mounted) widget.onSealed?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size * _kBoxHeight / _kBoxWidth,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => CustomPaint(
              painter: _EnvelopePainter(
                frame: _frameAt(_ctrl.value),
                symbol: _symbol,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Geometri — simgenin kendi birimleri (592 genişlik)
// ---------------------------------------------------------------------------

/// Gövde: `budgy_icon_fg.svg`'deki rect, sol üstü başlangıca taşınmış.
const _kBodyWidth = 592.0;
const _kBodyHeight = 384.0;
const _kRadius = 72.0;
const _kStroke = 52.0;

/// Kapak: aynı dosyadaki path, gövdenin sol üstüne göre.
const _kFlapLeft = Offset(28, 48);
const _kFlapDip = Offset(296, 240);
const _kFlapRight = Offset(564, 48);

/// Banknot: zarftan yukarı taşan kısmı görünür.
const _kNoteWidth = 404.0;
const _kNoteHeight = 300.0;

/// Duruşta banknotun üst kenarı gövdenin ne kadar üstünde — yüksekliğinin
/// yaklaşık %19'u görünüyor.
const _kNotePeek = 58.0;

/// Kutu, gövdenin üstünde banknota ve konturun yarısına yer bırakıyor.
const _kHeadroom = _kNotePeek + _kStroke / 2;
const _kBoxWidth = _kBodyWidth + _kStroke;
const _kBoxHeight = _kBodyHeight + _kStroke / 2 + _kHeadroom;

/// Gövdenin kutu içindeki sol üst köşesi.
const _kBodyOrigin = Offset(_kStroke / 2, _kHeadroom);

// ---------------------------------------------------------------------------
// Kare durumu
// ---------------------------------------------------------------------------

/// Tek karede çizilecek her şey; yalnız controller değerinden türüyor.
class _Frame {
  const _Frame({
    required this.open,
    required this.notePress,
    required this.check,
  });

  /// Kapağın aralanması, 0 kapalı 1 açık.
  final double open;

  /// Mühürleme: 0 normal, 1 para tamamen içeride ve kapak bastırılmış.
  final double notePress;

  /// Kapağın üstündeki onay işaretinin görünürlüğü.
  final double check;

  /// Simgenin tamamı kapakla aynı ritimde çok hafif nefes alıyor.
  double get scale => 1 + 0.015 * open;
}

_Frame _frameAt(double v) {
  // Mühürleme aralığı.
  if (v < 0) {
    final k = -v;
    return _Frame(
      open: 0,
      notePress: k,
      // Onay işareti son %40'ta beliriyor — kapak kapandıktan sonra.
      check: ((k - 0.6) / 0.4).clamp(0.0, 1.0),
    );
  }
  // Sakin döngü.
  final double open;
  if (v < _tOpenEnd) {
    open = Curves.easeInOutSine.transform(v / _tOpenEnd);
  } else if (v < _tHoldEnd) {
    open = 1;
  } else if (v < _tCloseEnd) {
    open =
        1 -
        Curves.easeInOutSine.transform(
          (v - _tHoldEnd) / (_tCloseEnd - _tHoldEnd),
        );
  } else {
    open = 0;
  }
  return _Frame(open: open, notePress: 0, check: 0);
}

// ---------------------------------------------------------------------------
// Çizim
// ---------------------------------------------------------------------------

/// Simgeyi bir kez dizer; çizimde banknot boyuna göre ölçekleniyor.
ui.Paragraph? _buildSymbol(String symbol) {
  if (symbol.isEmpty) return null;
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'InterDisplay',
            fontSize: 100,
            fontWeight: FontWeight.w800,
            textAlign: TextAlign.center,
          ),
        )
        ..pushStyle(ui.TextStyle(color: kBillInk.withValues(alpha: 0.6)))
        ..addText(symbol);
  return builder.build()..layout(const ui.ParagraphConstraints(width: 120));
}

class _EnvelopePainter extends CustomPainter {
  const _EnvelopePainter({required this.frame, required this.symbol});

  final _Frame frame;
  final ui.Paragraph? symbol;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _kBoxWidth;
    canvas.save();
    // Nefes: kutunun merkezinden.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(frame.scale);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.scale(k);
    canvas.translate(_kBodyOrigin.dx, _kBodyOrigin.dy);

    _paintNote(canvas);
    _paintBody(canvas);
    _paintFlap(canvas);
    if (frame.check > 0) _paintCheck(canvas);

    canvas.restore();
  }

  /// Banknot: gövdenin arkasında, üst kenarı dışarı taşıyor. Açılınca
  /// yükseliyor, mühürlenince tamamen içeri iniyor.
  void _paintNote(Canvas canvas) {
    final rise = _kNoteHeight * 0.09 * frame.open;
    final sink = (_kNotePeek + 8) * frame.notePress;
    final top = -_kNotePeek - rise + sink;
    final rect = Rect.fromLTWH(
      (_kBodyWidth - _kNoteWidth) / 2,
      top,
      _kNoteWidth,
      _kNoteHeight,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = kBillFill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = kBillEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    // Süsleme yalnız görünen şeride sığmalı: banknotun alt kısmı zarfın
    // arkasında. Simge şeridin tam ortasında, iki yanında kısa çizgiler.
    final mid = rect.top + _kNotePeek / 2;
    final guilloche = Paint()
      ..color = kBillEdge.withValues(alpha: 0.55)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (final sign in const [-1, 1]) {
      canvas.drawLine(
        Offset(rect.center.dx + sign * 70, mid),
        Offset(rect.center.dx + sign * 150, mid),
        guilloche,
      );
    }
    final p = symbol;
    if (p == null) return;
    canvas.save();
    canvas.translate(rect.center.dx, mid);
    canvas.scale(0.30);
    canvas.drawParagraph(p, Offset(-60, -p.height / 2));
    canvas.restore();
  }

  /// Zarfın ön yüzü: simgedeki rect. Dolgusu kâğıt rengi — banknotun alt
  /// kısmını kapatması gerekiyor, simgede ise dolgu yoktu.
  void _paintBody(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, _kBodyWidth, _kBodyHeight),
      const Radius.circular(_kRadius),
    );
    canvas.drawRRect(rrect, Paint()..color = Poster.paper);
    canvas.drawRRect(rrect, _ink());
  }

  /// Kapak. Açılma, derinliğin kısalmasıyla veriliyor: kapak izleyiciye
  /// doğru döndükçe izdüşümü kısalıyor (üst kenar sabit menteşe). Mühürlemede
  /// ise normalden bir tık daha derine bastırılıyor.
  void _paintFlap(Canvas canvas) {
    final depth = _kFlapDip.dy - _kFlapLeft.dy;
    final dip = Offset(
      _kFlapDip.dx,
      _kFlapLeft.dy + depth * (1 - 0.16 * frame.open + 0.03 * frame.notePress),
    );
    canvas.drawPath(
      Path()
        ..moveTo(_kFlapLeft.dx, _kFlapLeft.dy)
        ..lineTo(dip.dx, dip.dy)
        ..lineTo(_kFlapRight.dx, _kFlapRight.dy),
      _ink(),
    );
  }

  /// Bağlantı tamam: kapağın ortasında kısa bir onay işareti.
  void _paintCheck(Canvas canvas) {
    final c = Offset(_kBodyWidth / 2, _kFlapLeft.dy + 96);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 58, c.dy)
        ..lineTo(c.dx - 16, c.dy + 44)
        ..lineTo(c.dx + 62, c.dy - 44),
      Paint()
        ..color = kBillEdge.withValues(alpha: frame.check)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _kStroke * 0.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Paint _ink() => Paint()
    ..color = Poster.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = _kStroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_EnvelopePainter old) =>
      old.frame.open != frame.open ||
      old.frame.notePress != frame.notePress ||
      old.frame.check != frame.check ||
      old.symbol != symbol;
}
