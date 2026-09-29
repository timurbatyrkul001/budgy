import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_bubbles.dart';
import 'package:kopilka_app/features/onboarding/onboarding_palette.dart';
import 'package:kopilka_app/features/onboarding/onboarding_receipt.dart';

import '../support/harness.dart';

/// Fiş yazdırma seçim sayfası (balon bulutunun alternatifi): hücreye
/// dokununca fişe satır eklenir, tekrar dokununca çıkar, `onNext` doğru
/// kümeyi verir, başlangıç seçimi korunur, toplam sayı doğru ve üç dilde
/// küçük ekranlarda taşmaz. Sayfa akıştaki gibi kâğıt zeminli Scaffold'da.
Strings strFor(AppLanguage lang) => switch (lang) {
  AppLanguage.en => Strings.en,
  AppLanguage.tr => Strings.tr,
  AppLanguage.ru => Strings.ru,
};

Finder cell(String id) => find.byKey(ValueKey('cell-$id'));
Finder line(String id) => find.byKey(ValueKey('line-$id'));
Finder total(int n) => find.descendant(
  of: find.byKey(const Key('receipt-total')),
  matching: find.text('$n'),
);

void main() {
  // Test fontu (Ahem) her harfi tam kare çizer ve etiketleri gerçeğin iki
  // katı genişlikte ölçer; yerleşim testleri anlamlı olsun diye gerçek
  // fontlar yüklenir.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final display = FontLoader('InterDisplay');
    for (final f in ['InterDisplay-Black', 'InterDisplay-SemiBold']) {
      final bytes = await File('assets/fonts/$f.ttf').readAsBytes();
      display.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await display.load();
    final body = FontLoader('Inter');
    final bytes = await File('assets/fonts/Inter-Regular.ttf').readAsBytes();
    body.addFont(Future.value(ByteData.sublistView(bytes)));
    await body.load();
  });

  Widget page({
    required List<BubbleItem> items,
    required void Function(Set<String>) onNext,
    Color accent = Ex.brand,
    Set<String> initialSelected = const {},
    String title = 'Nelere para harcıyorsun?',
  }) {
    return Scaffold(
      backgroundColor: Poster.paper,
      body: SafeArea(
        child: ReceiptPickerPage(
          title: title,
          items: items,
          accent: accent,
          onNext: onNext,
          initialSelected: initialSelected,
        ),
      ),
    );
  }

  testWidgets('hücreye dokununca fişe satır eklenir; tekrar dokununca çıkar', (
    tester,
  ) async {
    final items = expenseBubbles(Strings.tr);
    Set<String>? result;
    await pumpBudgyScreen(
      tester,
      page(items: items, onNext: (s) => result = s),
      db: FakeFirebaseFirestore(),
    );
    expect(tester.takeException(), isNull);

    // Her hücre ekranda (ızgara kaydırılabilir; widget ağacında var).
    for (final b in items) {
      expect(cell(b.id), findsOneWidget, reason: b.id);
      expect(line(b.id), findsNothing, reason: b.id);
    }
    expect(find.text('Devam et'), findsOneWidget);
    expect(total(0), findsOneWidget);
    expect(find.text('Kategoriler'), findsOneWidget);
    expect(find.text('BUDGY'), findsOneWidget);

    // Seç: Market + Kira → fişte iki satır, sayaç 2.
    await tester.tap(cell('groceries'));
    await tester.pumpAndSettle();
    expect(line('groceries'), findsOneWidget);
    expect(total(1), findsOneWidget);
    await tester.tap(cell('rent'));
    await tester.pumpAndSettle();
    expect(line('rent'), findsOneWidget);
    expect(total(2), findsOneWidget);
    expect(find.text('2 tanesiyle devam et'), findsOneWidget);
    // Fiş satırı sıra numarası ve adı taşır.
    expect(
      find.descendant(of: line('rent'), matching: find.text('02')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: line('rent'), matching: find.text('Kira')),
      findsOneWidget,
    );

    // Semantics: Market hücresi seçili işaretli.
    final marketSem = tester.getSemantics(
      find.descendant(of: cell('groceries'), matching: find.text('Market')),
    );
    expect(marketSem.flagsCollection.isSelected, ui.Tristate.isTrue);

    // Bırak: Kira'ya tekrar dokun → satır fişten çıkar, 1 kaldı.
    await tester.tap(cell('rent'));
    await tester.pumpAndSettle();
    expect(line('rent'), findsNothing);
    expect(line('groceries'), findsOneWidget);
    expect(total(1), findsOneWidget);
    expect(find.text('1 tanesiyle devam et'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.descendant(of: cell('rent'), matching: find.text('Kira')),
          )
          .flagsCollection
          .isSelected,
      isNot(ui.Tristate.isTrue),
    );

    await tester.tap(find.text('1 tanesiyle devam et'));
    await tester.pumpAndSettle();
    expect(result, {'groceries'});
  });

  testWidgets('hiç seçmeden ilerlenebilir; başlangıç seçimi korunur', (
    tester,
  ) async {
    Set<String>? result;
    await pumpBudgyScreen(
      tester,
      page(
        items: incomeBubbles(Strings.en),
        onNext: (s) => result = s,
        initialSelected: const {'salary'},
        title: 'Where does your money come from?',
      ),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    // Başlangıç seçimi fişte satır olarak duruyor.
    expect(line('salary'), findsOneWidget);
    expect(total(1), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Continue with 1'), findsOneWidget);
    await tester.tap(cell('salary'));
    await tester.pumpAndSettle();
    expect(line('salary'), findsNothing);
    expect(total(0), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });

  testWidgets('çok satırda fiş yuvayı aşmaz, son satır görünür kalır', (
    tester,
  ) async {
    final items = expenseBubbles(Strings.tr);
    final ten = items.take(10).map((b) => b.id).toSet();
    Set<String>? result;
    await pumpBudgyScreen(
      tester,
      page(items: items, onNext: (s) => result = s, initialSelected: ten),
      db: FakeFirebaseFirestore(),
      logicalSize: const Size(320, 568),
    );
    expect(tester.takeException(), isNull);
    expect(total(10), findsOneWidget);
    // Fiş yuvası ekranın %28'i (159) → fiş bundan uzun olamaz.
    final receipt = tester.getRect(find.byKey(const Key('receipt-total')));
    final button = tester.getRect(find.text('10 tanesiyle devam et'));
    expect(receipt.bottom, lessThan(button.top));
    // Son satır (10.) görünür, ilk satır yukarı akmış.
    final last = tester.getRect(line(items[9].id));
    expect(last.bottom, lessThanOrEqualTo(receipt.top + 1));
    expect(last.top, greaterThan(0));
    // Bir satır daha ekle → 11, düğme sayacı değişir.
    await tester.tap(cell(items[10].id));
    await tester.pumpAndSettle();
    expect(total(11), findsOneWidget);
    await tester.tap(find.text('11 tanesiyle devam et'));
    expect(result, {...ten, items[10].id});
  });

  for (final lang in AppLanguage.values) {
    for (final size in const [Size(320, 568), Size(360, 800)]) {
      final str = strFor(lang);
      testWidgets(
        'gider · ${size.width.toInt()}×${size.height.toInt()} · ${lang.code} taşmıyor',
        (tester) async {
          final items = expenseBubbles(str);
          await pumpBudgyScreen(
            tester,
            page(
              items: items,
              onNext: (_) {},
              title: str.localeCode == 'ru'
                  ? 'На что ты тратишь деньги?'
                  : 'Nelere para harcıyorsun?',
              initialSelected: {items[0].id, items[1].id, items[2].id},
            ),
            db: FakeFirebaseFirestore(),
            language: lang,
            logicalSize: size,
          );
          expect(tester.takeException(), isNull);
          // Hücreler ve fiş yatayda ekran içinde.
          final screen = Offset.zero & size;
          for (final b in items) {
            final r = tester.getRect(cell(b.id));
            expect(
              r.left >= 0 && r.right <= screen.right,
              isTrue,
              reason: 'hücre yatay taştı: ${b.label} $r',
            );
          }
          final receipt = tester.getRect(
            find.byKey(const Key('receipt-total')),
          );
          expect(screen.contains(receipt.bottomRight), isTrue);
        },
      );
      testWidgets(
        'gelir · ${size.width.toInt()}×${size.height.toInt()} · ${lang.code} taşmıyor',
        (tester) async {
          await pumpBudgyScreen(
            tester,
            page(
              items: incomeBubbles(str),
              onNext: (_) {},
              accent: Ex.brand,
              title: switch (str.localeCode) {
                'ru' => 'Откуда приходят твои деньги?',
                'en' => 'Where does your money come from?',
                _ => 'Paran nereden geliyor?',
              },
            ),
            db: FakeFirebaseFirestore(),
            language: lang,
            logicalSize: size,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // Gözle görme: RECEIPT_PNG_DIR verilirse gerçek fontlarla PNG döker.
  //   RECEIPT_PNG_DIR=/tmp/x flutter test test/widget/onboarding_receipt_test.dart
  // Her hâl ayrı testWidgets: aynı testte ikinci pumpWidget ProviderScope
  // override'larını yenilemiyor, dil ilk pump'ta takılı kalıyor.
  final pngDir = Platform.environment['RECEIPT_PNG_DIR'];
  final tr = expenseBubbles(Strings.tr);
  for (final (name, lang, items, accent, sel, size) in [
    ('tr_0', AppLanguage.tr, tr, Ex.red, <String>{}, const Size(360, 780)),
    (
      'tr_3',
      AppLanguage.tr,
      tr,
      Ex.red,
      {'groceries', 'rent', 'coffee'},
      const Size(360, 780),
    ),
    (
      'tr_10',
      AppLanguage.tr,
      tr,
      Ex.red,
      tr.take(10).map((b) => b.id).toSet(),
      const Size(360, 780),
    ),
    (
      'ru_3_small',
      AppLanguage.ru,
      expenseBubbles(Strings.ru),
      Ex.red,
      {'groceries', 'rent', 'publicTransport'},
      const Size(320, 568),
    ),
    (
      'en_income',
      AppLanguage.en,
      incomeBubbles(Strings.en),
      Ex.brand,
      {'salary', 'freelance'},
      const Size(360, 780),
    ),
  ]) {
    testWidgets('önizleme PNG · $name', (tester) async {
      final key = GlobalKey();
      await pumpBudgyScreen(
        tester,
        RepaintBoundary(
          key: key,
          child: page(
            items: items,
            onNext: (_) {},
            accent: accent,
            initialSelected: sel,
            title: switch (lang) {
              AppLanguage.ru => 'На что ты тратишь деньги?',
              AppLanguage.en => 'Where does your money come from?',
              AppLanguage.tr => 'Nelere para harcıyorsun?',
            },
          ),
        ),
        db: FakeFirebaseFirestore(),
        language: lang,
        logicalSize: size,
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$pngDir/receipt_$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
    }, skip: pngDir == null);
  }
}
