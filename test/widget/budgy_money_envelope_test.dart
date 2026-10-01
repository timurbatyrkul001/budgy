import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/onboarding/widgets/budgy_money_envelope.dart';

/// Paralı zarf: kapanış sayfasının ortasındaki sakin döngü. Testin işi pozun
/// güzelliği değil — döngünün hatasız dönmesi, hareket azaltmada hiç
/// dönmemesi, mühürlemenin haber vermesi ve controller'ın sızmaması.
Future<void> pumpEnvelope(
  WidgetTester tester, {
  bool reduceMotion = false,
  bool sealed = false,
  VoidCallback? onSealed,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: BudgyMoneyEnvelope(
            size: 180,
            semanticsLabel: 'Your book, safely stored',
            currencySymbol: '₺',
            sealed: sealed,
            onSealed: onSealed,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tüm döngü hatasız döner', (tester) async {
    await pumpEnvelope(tester);
    expect(find.byType(BudgyMoneyEnvelope), findsOneWidget);

    const step = Duration(milliseconds: 50);
    for (var i = 0; i < BudgyMoneyEnvelope.loop.inMilliseconds ~/ 50 + 4; i++) {
      await tester.pump(step);
      expect(tester.takeException(), isNull);
    }

    // İkinci tura girdi: repeat çalışıyor, tek seferlik değil.
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isTrue);

    // Sökülünce controller dispose edilir; sızıntı olsaydı "disposed with an
    // active Ticker" hatası düşerdi.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('hareket azaltmada statik poz, kare istenmiyor', (tester) async {
    await pumpEnvelope(tester, reduceMotion: true);
    await tester.pump();
    expect(find.byType(BudgyMoneyEnvelope), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mühürleme: kapanır, onay verir, haber eder', (tester) async {
    await pumpEnvelope(tester);
    await tester.pump(const Duration(milliseconds: 1400)); // kapak açık

    var sealed = false;
    await pumpEnvelope(tester, sealed: true, onSealed: () => sealed = true);
    // Süre dolmadan haber yok.
    await tester.pump(const Duration(milliseconds: 300));
    expect(sealed, isFalse);

    await tester.pump(BudgyMoneyEnvelope.sealDuration);
    await tester.pump();
    expect(sealed, isTrue);
    expect(tester.takeException(), isNull);

    // Mühürlendikten sonra döngü yeniden başlamıyor.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ekran okuyucu etiketi', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpEnvelope(tester, reduceMotion: true);
    expect(find.bySemanticsLabel('Your book, safely stored'), findsOneWidget);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
