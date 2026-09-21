import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Budgy mikro-hareket yardımcıları.
///
/// Kurallar: yalnız giriş / durum geçişi, asla döngü; süre ≤ 320 ms, toplam
/// sıralı gecikme ≤ ~250 ms; sistem "hareketi azalt" açıkken hiç animasyon
/// yok — son durum doğrudan çizilir. Her çağrı bu dosyadan geçer, kontrol
/// tek yerde.

/// Sistem "hareketi azalt" ayarı.
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

const kEnterDuration = Duration(milliseconds: 280);
const kEnterStep = Duration(milliseconds: 35);
const kEnterCurve = Curves.easeOutCubic;

/// Sıralı gecikmenin üst sınırı (adım sayısı): 7 × 35 ms = 245 ms.
const _maxEnterSteps = 7;

extension BudgyMotion on Widget {
  /// Giriş: solma + hafif yukarı kayma. [index] sıralı gecikme adımı.
  /// Animate, süre/target değişmedikçe yeniden kurulumda tekrar oynamaz;
  /// yani ekran ilk gösterildiğinde bir kez oynar.
  Widget enterUp(BuildContext context, {int index = 0, double dy = 10}) {
    if (reduceMotion(context)) return this;
    return animate(delay: kEnterStep * math.min(index, _maxEnterSteps))
        .fadeIn(duration: kEnterDuration, curve: kEnterCurve)
        .move(
            begin: Offset(0, dy),
            end: Offset.zero,
            duration: kEnterDuration,
            curve: kEnterCurve);
  }

  /// Giriş: solma + 0.92'den büyüme (seçici karoları). [index] karo sırası,
  /// [baseDelay] kapsayan bölümün gecikmesi; karo adımı 20 ms, en çok 3 adım.
  Widget enterPop(BuildContext context,
      {int index = 0, Duration baseDelay = Duration.zero}) {
    if (reduceMotion(context)) return this;
    const step = Duration(milliseconds: 20);
    const d = Duration(milliseconds: 220);
    return animate(delay: baseDelay + step * math.min(index, 3))
        .fadeIn(duration: d, curve: Curves.easeOut)
        .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: d,
            curve: kEnterCurve);
  }

  /// Durum geçişi: [visible] true olunca yukarı kayarak belirir, false
  /// olunca solarak iner. Hareket azaltmada anında görünür/gizli.
  Widget reveal(BuildContext context, {required bool visible, double dy = 12}) {
    if (reduceMotion(context)) return Visibility(visible: visible, child: this);
    const d = Duration(milliseconds: 240);
    return animate(target: visible ? 1 : 0)
        .fade(begin: 0, end: 1, duration: d, curve: Curves.easeOut)
        .move(begin: Offset(0, dy), end: Offset.zero, duration: d, curve: kEnterCurve);
  }
}

/// Basılıyken ~0.94'e küçülen dokunma geri bildirimi (dock düğmeleri).
/// Parmağı izler: jest tabanlı AnimatedScale, flutter_animate değil.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.94,
    this.shape = const CircleBorder(),
    this.color,
  });

  final VoidCallback onTap;
  final Widget child;
  final double scale;
  final ShapeBorder shape;
  final Color? color;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final instant = reduceMotion(context);
    return AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: instant ? Duration.zero : const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Material(
        color: widget.color ?? Colors.transparent,
        shape: widget.shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: widget.shape,
          onTap: widget.onTap,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          child: widget.child,
        ),
      ),
    );
  }
}
