import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/category_catalog.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_bubbles.dart';
import 'package:kopilka_app/features/onboarding/onboarding_palette.dart';

import '../support/harness.dart';

/// Balon bulutu seçim sayfası: balonlar çizilir, dokununca seçilir, tekrar
/// dokununca bırakılır, `onNext` doğru kümeyi verir ve üç dilde 320dp'de
/// taşmaz. Sayfa akıştaki gibi kâğıt zeminli bir Scaffold içinde açılır.
Strings strFor(AppLanguage lang) => switch (lang) {
      AppLanguage.en => Strings.en,
      AppLanguage.tr => Strings.tr,
      AppLanguage.ru => Strings.ru,
    };

void main() {
  // Test fontu (Ahem) her harfi tam kare çizer ve etiketleri gerçeğin iki
  // katı genişlikte ölçer; yerleşim testleri anlamlı olsun diye gerçek
  // InterDisplay dosyaları yüklenir.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('InterDisplay');
    for (final f in ['InterDisplay-Black', 'InterDisplay-SemiBold']) {
      final bytes = await File('assets/fonts/$f.ttf').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Widget page({
    required List<BubbleItem> items,
    required void Function(Set<String>) onNext,
    Color accent = Ex.brand,
    Set<String> initialSelected = const {},
  }) {
    return Scaffold(
      backgroundColor: Poster.paper,
      body: SafeArea(
        child: BubblePickerPage(
          title: 'Giderlerinden bazılarını seç',
          items: items,
          accent: accent,
          onNext: onNext,
          initialSelected: initialSelected,
        ),
      ),
    );
  }

  test('hazır listeler katalogdan gelir ve üç dilde dolu', () {
    for (final str in [Strings.en, Strings.tr, Strings.ru]) {
      final exp = expenseBubbles(str);
      expect(exp.length, kExpenseBubbleKeys.length);
      expect(exp.length, inInclusiveRange(18, 24));
      for (final b in exp) {
        expect(catalogItem(b.id), isNotNull, reason: b.id);
        expect(b.label, catalogItem(b.id)!.name(str.localeCode));
        expect(isIncomeCatalogKey(b.id), isFalse, reason: b.id);
      }
      final inc = incomeBubbles(str);
      expect(inc, isNotEmpty);
      for (final b in inc) {
        expect(isIncomeCatalogKey(b.id), isTrue, reason: b.id);
        expect(b.id, isNot('otherIncome'));
      }
    }
  });

  testWidgets('balonlar çizilir; dokununca seçilir, tekrar dokununca bırakılır',
      (tester) async {
    final items = expenseBubbles(Strings.tr);
    Set<String>? result;
    await pumpBudgyScreen(
      tester,
      page(items: items, onNext: (s) => result = s),
      db: FakeFirebaseFirestore(),
    );
    expect(tester.takeException(), isNull);

    // Her balonun etiketi ekranda.
    for (final b in items) {
      expect(find.text(b.label), findsOneWidget, reason: b.label);
    }
    expect(find.text('Devam et'), findsOneWidget);

    // Seç: Market + Kira → düğme sayacı değişir.
    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kira'));
    await tester.pumpAndSettle();
    expect(find.text('2 tanesiyle devam et'), findsOneWidget);

    // Semantics: Market seçili işaretli.
    final marketSem = tester.getSemantics(find.text('Market'));
    expect(marketSem.flagsCollection.isSelected, ui.Tristate.isTrue);

    // Bırak: Kira'ya tekrar dokun → 1 kaldı.
    await tester.tap(find.text('Kira'));
    await tester.pumpAndSettle();
    expect(find.text('1 tanesiyle devam et'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Kira')).flagsCollection.isSelected,
      isNot(ui.Tristate.isTrue),
    );

    await tester.tap(find.text('1 tanesiyle devam et'));
    await tester.pumpAndSettle();
    expect(result, {'groceries'});
  });

  testWidgets('hiç seçmeden ilerlenebilir; başlangıç seçimi korunur',
      (tester) async {
    Set<String>? result;
    await pumpBudgyScreen(
      tester,
      page(
        items: incomeBubbles(Strings.en),
        onNext: (s) => result = s,
        initialSelected: const {'salary'},
      ),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    expect(find.text('Continue with 1'), findsOneWidget);
    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });

  // Balonlar üst üste binmez (seçimsiz hâl) — yerleşim algoritması gerçek
  // metin ölçüleriyle çakışmasız kalmalı.
  testWidgets('balonlar çakışmaz', (tester) async {
    final items = expenseBubbles(Strings.ru);
    await pumpBudgyScreen(
      tester,
      page(items: items, onNext: (_) {}),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.ru,
      logicalSize: const Size(320, 800),
    );
    final rects = [
      for (final b in items) tester.getRect(find.ancestor(
          of: find.text(b.label),
          matching: find.byType(AnimatedScale))),
    ];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        final a = rects[i], b = rects[j];
        final d = (a.center - b.center).distance;
        final minD = (a.width + b.width) / 2;
        expect(d, greaterThanOrEqualTo(minD - 0.5),
            reason: '${items[i].label} × ${items[j].label}');
      }
    }
  });

  for (final lang in AppLanguage.values) {
    for (final size in const [Size(320, 800), Size(320, 568), Size(360, 800)]) {
      testWidgets(
          'gider · ${size.width.toInt()}×${size.height.toInt()} · ${lang.code} taşmıyor',
          (tester) async {
        await pumpBudgyScreen(
          tester,
          page(items: expenseBubbles(strFor(lang)), onNext: (_) {}),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: size,
        );
        expect(tester.takeException(), isNull);
        // Tüm balonlar ekran içinde.
        final screen = Offset.zero & size;
        for (final r in tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => tester.getRect(find.byWidget(t)))) {
          expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight),
              isTrue, reason: 'balon ekran dışına taştı: $r');
        }
      });
      testWidgets(
          'gelir · ${size.width.toInt()}×${size.height.toInt()} · ${lang.code} taşmıyor',
          (tester) async {
        await pumpBudgyScreen(
          tester,
          page(
              items: incomeBubbles(strFor(lang)),
              onNext: (_) {},
              accent: const Color(0xFF1FA463)),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: size,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Gözle görme: BUBBLE_PNG_DIR verilirse gerçek fontlarla PNG döker.
  //   BUBBLE_PNG_DIR=/tmp/x flutter test test/widget/onboarding_bubbles_test.dart
  final pngDir = Platform.environment['BUBBLE_PNG_DIR'];
  testWidgets('önizleme PNG', (tester) async {
    for (final (lang, items, accent, sel) in [
      (AppLanguage.tr, expenseBubbles(Strings.tr), const Color(0xFFE5484D),
          {'groceries', 'rent', 'coffee'}),
      (AppLanguage.ru, expenseBubbles(Strings.ru), const Color(0xFFE5484D),
          <String>{}),
      (AppLanguage.en, incomeBubbles(Strings.en), Ex.brand, {'salary'}),
    ]) {
      final key = GlobalKey();
      await pumpBudgyScreen(
        tester,
        RepaintBoundary(
          key: key,
          child: page(
              items: items, onNext: (_) {}, accent: accent, initialSelected: sel),
        ),
        db: FakeFirebaseFirestore(),
        language: lang,
        logicalSize: const Size(360, 780),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$pngDir/bubbles_${lang.code}.png')
            .writeAsBytes(data!.buffer.asUint8List());
      });
    }
  }, skip: pngDir == null);
}
