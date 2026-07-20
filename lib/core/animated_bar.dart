import 'package:flutter/material.dart';

/// Sayfaya girerken hafif fade + yukarı kayma. [delayIndex] ile kademeli.
class EntranceFade extends StatelessWidget {
  const EntranceFade({super.key, required this.child, this.delayIndex = 0});

  final Widget child;
  final int delayIndex;

  @override
  Widget build(BuildContext context) {
    final start = (delayIndex * 0.06).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
            offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}

/// Değerine doğru yumuşak dolan ilerleme çubuğu (bütçe/hedef).
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    this.background = const Color(0xFFEDEFF3),
    this.height = 10,
    this.radius = 6,
  });

  final double value;
  final Color color;
  final Color background;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: background,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}
