import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/motion.dart';

/// Mikro-hareket yardımcıları: giriş efektleri bitiyor (döngü yok), hareket
/// azaltmada hiç Animate kurulmuyor, reveal target'la açılıp kapanıyor,
/// PressScale basılıyken 0.94.
void main() {
  Widget host(Widget child, {bool reduce = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  // Rota geçişinin kendi FadeTransition'ları var; yalnız Animate içindekiler.
  Finder fades() => find.descendant(
      of: find.byType(Animate), matching: find.byType(FadeTransition));
  double opacityOf(WidgetTester tester) =>
      tester.widget<FadeTransition>(fades().first).opacity.value;

  testWidgets('enterUp: 0 → 1 ve biter (pumpAndSettle takılmaz)', (tester) async {
    await tester.pumpWidget(host(Builder(
      builder: (context) => const Text('hero').enterUp(context, index: 2),
    )));
    await tester.pump();
    expect(find.byType(Animate), findsOneWidget);
    expect(opacityOf(tester), lessThan(0.05), reason: 'gecikme sırasında görünmez');
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    expect(find.text('hero'), findsOneWidget);
  });

  testWidgets('enterPop: sıralı gecikme sınırlı, sonunda tam ölçek', (tester) async {
    await tester.pumpWidget(host(Builder(
      builder: (context) => Column(
        children: [
          for (var i = 0; i < 12; i++)
            Text('t$i').enterPop(context, index: i, baseDelay: kEnterStep * 4),
        ],
      ),
    )));
    await tester.pump();
    // En uzun gecikme 140 + 60 ms, süre 220 ms → 500 ms'de hepsi bitmiş olmalı
    // (kare kare: gecikme zamanlayıcısı kontrolcüyü başlatır, kareler ilerletir).
    for (var t = 0; t < 500; t += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (final f in tester.widgetList<FadeTransition>(fades())) {
      expect(f.opacity.value, 1);
    }
    expect(find.byType(Animate), findsNWidgets(12));
  });

  testWidgets('hareket azalt: Animate yok, çocuk anında görünür', (tester) async {
    await tester.pumpWidget(host(
      Builder(
        builder: (context) => Column(
          children: [
            const Text('a').enterUp(context, index: 3),
            const Text('b').enterPop(context, index: 3),
            const Text('c').reveal(context, visible: true),
            const Text('d').reveal(context, visible: false),
          ],
        ),
      ),
      reduce: true,
    ));
    await tester.pump();
    expect(find.byType(Animate), findsNothing);
    expect(
        find.descendant(of: find.byType(Column), matching: find.byType(FadeTransition)),
        findsNothing);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    expect(find.text('d'), findsNothing, reason: 'gizli durum anında');
  });

  testWidgets('reveal: görünürlük target ile açılır ve solar', (tester) async {
    var visible = false;
    late StateSetter set;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) {
        set = setState;
        return const Text('chip').reveal(context, visible: visible);
      },
    )));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
    set(() => visible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = opacityOf(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    set(() => visible = false);
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
  });

  testWidgets('PressScale: basılıyken 0.94, bırakınca 1, tıklama çalışır',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(PressScale(
      onTap: () => taps++,
      color: Colors.green,
      child: const SizedBox(width: 56, height: 56),
    )));
    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), 0.94);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(taps, 1);
  });
}
