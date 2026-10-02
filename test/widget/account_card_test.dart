import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/account_card.dart';
import 'package:kopilka_app/features/accounts/bank_catalog.dart';

/// Hesap kartı: markanın stiliyle çizilir, yazı rengi zeminden türer, kart
/// bilgisi (last4 dahil) hiçbir stilde görünmez, nakit kâğıt görünümünde,
/// semantics etiketi doğru, dar ekranda taşmaz, override markayı ezer.
void main() {
  const enpara = Account(
    id: 'a1',
    name: 'Enpara Maaş',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 1000,
    last4: '1234',
  );

  const garanti = Account(
    id: 'a6',
    name: 'Garanti Bonus',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 0,
  );

  const azCard = Account(
    id: 'a2',
    name: 'Kapital Bank',
    currency: 'AZN',
    kind: AccountKind.card,
    balance: 50,
  );

  const cash = Account(
    id: Account.cashId,
    name: 'Nakit',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 200,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double screenWidth = 390,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Ex.bg,
          body: Center(
            child: SizedBox(width: screenWidth, child: Center(child: child)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Kartın altındaki tüm BoxDecoration'lar.
  List<BoxDecoration> decorations(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.descendant(
        of: find.byType(AccountCard),
        matching: find.byType(DecoratedBox),
      ))
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .toList();

  /// Karttaki painter'lar (ContactlessPainter dahil).
  Iterable<CustomPainter> painters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.descendant(
        of: find.byType(AccountCard),
        matching: find.byType(CustomPaint),
      ))
      .map((w) => w.painter)
      .whereType<CustomPainter>();

  ContactlessPainter? contactless(WidgetTester tester) =>
      painters(tester).whereType<ContactlessPainter>().firstOrNull;

  bool hasContactless(WidgetTester tester) => contactless(tester) != null;

  /// Markanın stiline göre beklenen yüz: flat → gradyanlı BoxDecoration,
  /// diğerleri → kendi painter'ı.
  void expectFace(WidgetTester tester, CardStyle style) {
    final ps = painters(tester);
    final grads = decorations(tester)
        .map((d) => d.gradient)
        .whereType<LinearGradient>();
    switch (style) {
      case CardStyle.flat:
        expect(grads, hasLength(1), reason: 'flat: tek gradyan');
        expect(ps.whereType<MetalFacePainter>(), isEmpty);
        expect(ps.whereType<RibbonFacePainter>(), isEmpty);
        expect(ps.whereType<SplitFacePainter>(), isEmpty);
      case CardStyle.metal:
        expect(ps.whereType<MetalFacePainter>(), hasLength(1));
        expect(grads, isEmpty);
      case CardStyle.ribbon:
        expect(ps.whereType<RibbonFacePainter>(), hasLength(1));
        expect(grads, isEmpty);
      case CardStyle.split:
        expect(ps.whereType<SplitFacePainter>(), hasLength(1));
        expect(grads, isEmpty);
    }
  }

  testWidgets('kart render olur: banka adı, para birimi, temassız, oran',
      (tester) async {
    await pump(tester, const AccountCard(account: garanti, width: 300));

    expect(find.text('Garanti BBVA'), findsOneWidget);
    // Kullanıcının verdiği ad bankadan farklı → küçük alt satır.
    expect(find.text('Garanti Bonus'), findsOneWidget);
    expect(find.text('TRY'), findsOneWidget);
    expect(hasContactless(tester), isTrue);

    // Garanti flat: zemin marka laciverti gradyanı.
    expectFace(tester, CardStyle.flat);
    final grad = decorations(tester)
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .single;
    final brand = bankByKey('garanti')!.color;
    for (final c in grad.colors) {
      // Gradyan uçları marka rengine yakın (hafif açık/koyu).
      expect((c.r - brand.r).abs(), lessThan(0.12), reason: '$c');
      expect((c.b - brand.b).abs(), lessThan(0.12), reason: '$c');
    }

    // Gerçek kart oranı (halka hariç).
    final card = tester.widget<AccountCard>(find.byType(AccountCard));
    final size = tester.getSize(find.byType(AccountCard));
    expect(size.width, 300);
    expect(size.height, moreOrLessEquals(card.height, epsilon: 0.5));
    expect(card.cardWidth / (card.height - 2 * (AccountCard.ringWidth +
            AccountCard.ringGap)),
        moreOrLessEquals(85.6 / 54, epsilon: 0.001));
  });

  testWidgets('her stil render olur ve doğru yüzü çizer', (tester) async {
    for (final b in kBankCatalog.where((b) => b.key != 'cash')) {
      final acc = Account(
        id: 'k-${b.key}',
        name: '',
        currency: b.currency,
        kind: AccountKind.card,
        balance: 0,
      );
      await pump(tester, AccountCard(account: acc, brand: b, width: 300));
      expect(tester.takeException(), isNull, reason: b.key);
      expect(find.text(b.name), findsOneWidget, reason: b.key);
      expectFace(tester, b.style);
    }
  });

  testWidgets('açık zeminli kartta yazı, temassız ve rozet mürekkep; '
      'koyu zeminlide beyaz', (tester) async {
    // Kaspi (metal, açık) ve Enpara (ribbon, açık).
    for (final key in ['kaspi', 'enpara']) {
      final b = bankByKey(key)!;
      final acc = Account(
        id: key,
        name: '${b.name} Maaş',
        currency: b.currency,
        kind: AccountKind.card,
        balance: 0,
      );
      await pump(tester, AccountCard(account: acc, width: 300));
      final title = tester.widget<Text>(find.text(b.name));
      expect(title.style?.color, Ex.text, reason: '$key başlık mürekkep');
      final sub = tester.widget<Text>(find.text('${b.name} Maaş'));
      expect(sub.style?.color, Ex.textSoft, reason: '$key alt satır');
      expect(contactless(tester)!.color, Ex.text, reason: '$key temassız');
      final badge = tester.widget<Text>(find.text(b.currency));
      expect(badge.style?.color, Ex.text, reason: '$key rozet');
    }

    // Garanti (flat, koyu), Papara (split, koyu), Birbank (split, koyu).
    for (final key in ['garanti', 'papara', 'birbank']) {
      final b = bankByKey(key)!;
      final acc = Account(
        id: key,
        name: b.name,
        currency: b.currency,
        kind: AccountKind.card,
        balance: 0,
      );
      await pump(tester, AccountCard(account: acc, width: 300));
      final title = tester.widget<Text>(find.text(b.name));
      expect(title.style?.color, Colors.white, reason: '$key başlık beyaz');
      expect(contactless(tester)!.color, Colors.white, reason: key);
      final badge = tester.widget<Text>(find.text(b.currency));
      expect(badge.style?.color, Colors.white, reason: '$key rozet');
    }
  });

  testWidgets('metal gradyanının en koyu durağı bile mürekkeple okunur',
      (tester) async {
    for (final b in kBankCatalog.where((b) => b.style == CardStyle.metal)) {
      for (final c in MetalFacePainter.stopsFor(b.color)) {
        expect(
          BankBrand.contrastBetween(c, b.ink),
          greaterThanOrEqualTo(4.5),
          reason: '${b.key} durak $c',
        );
      }
    }
  });

  testWidgets('ribbon: Enpara beyaz zemin + üç renkli şerit + ince kenarlık',
      (tester) async {
    await pump(tester, const AccountCard(account: enpara, width: 300));
    final p = painters(tester).whereType<RibbonFacePainter>().single;
    expect(p.ground, Ex.surface);
    expect(p.colors, bankByKey('enpara')!.accents);
    expect(p.hairline, Ex.border, reason: 'beyaz kart krem kâğıtta kaybolmasın');
    expect(find.text('Enpara'), findsOneWidget);
    expect(find.text('Enpara Maaş'), findsOneWidget);
    // Yüz antiAlias kırpılıyor: şerit kart dışına taşıyor.
    final clip = tester.widget<ClipRRect>(find.descendant(
      of: find.byType(AccountCard),
      matching: find.byType(ClipRRect),
    ));
    expect(clip.clipBehavior, Clip.antiAlias);
  });

  testWidgets('split: Birbank siyah zemin, kırmızı ikinci ton', (tester) async {
    const acc = Account(
      id: 'bb',
      name: 'Birbank',
      currency: 'AZN',
      kind: AccountKind.card,
      balance: 0,
    );
    await pump(tester, const AccountCard(account: acc, width: 300));
    final p = painters(tester).whereType<SplitFacePainter>().single;
    final b = bankByKey('birbank')!;
    expect(p.color, b.color);
    expect(p.second, b.accents.single);
  });

  testWidgets('styleOverride markanın varsayılanı yerine o stili çizer',
      (tester) async {
    // Ziraat varsayılan flat; kullanıcı "metal" seçti.
    const ziraat = Account(
      id: 'z',
      name: 'Ziraat Bankkart',
      currency: 'TRY',
      kind: AccountKind.card,
      balance: 0,
    );
    expect(bankByKey('ziraat')!.style, CardStyle.flat);
    await pump(tester, const AccountCard(account: ziraat, width: 300));
    expectFace(tester, CardStyle.flat);

    for (final s in CardStyle.values) {
      await pump(tester,
          AccountCard(account: ziraat, width: 300, styleOverride: s));
      expect(tester.takeException(), isNull, reason: s.name);
      expectFace(tester, s);
      // Zemin (ve yazı rengi) markanın: override yalnız motifi değiştirir.
      final title = tester.widget<Text>(find.text('Ziraat'));
      expect(title.style?.color, Colors.white, reason: s.name);
    }

    // Override split + accentOverride: ikinci ton kullanıcının rengi.
    await pump(
      tester,
      const AccountCard(
        account: ziraat,
        width: 300,
        styleOverride: CardStyle.split,
        accentOverride: Color(0xFF123456),
      ),
    );
    final split = painters(tester).whereType<SplitFacePainter>().single;
    expect(split.color, bankByKey('ziraat')!.color);
    expect(split.second, const Color(0xFF123456));

    // Override ribbon, vurgu yok: tonal şerit (markanın paleti boş).
    await pump(tester,
        const AccountCard(account: ziraat, width: 300,
            styleOverride: CardStyle.ribbon));
    final ribbon = painters(tester).whereType<RibbonFacePainter>().single;
    expect(ribbon.ground, bankByKey('ziraat')!.color, reason: 'koyu zemin');
    expect(ribbon.hairline, isNull, reason: 'koyu kartta kenarlık gereksiz');

    // Enpara ribbon → kullanıcı flat'e döndürdü: şerit gider, gradyan gelir.
    await pump(tester,
        const AccountCard(account: enpara, width: 300,
            styleOverride: CardStyle.flat));
    expectFace(tester, CardStyle.flat);

    // Override, dışarı verilen effectiveBrand'de de görünür.
    const card = AccountCard(account: ziraat, styleOverride: CardStyle.metal);
    expect(card.effectiveBrand.style, CardStyle.metal);
    expect(card.effectiveBrand.key, 'ziraat');
    const plain = AccountCard(account: ziraat);
    expect(identical(plain.effectiveBrand, bankByKey('ziraat')), isTrue,
        reason: 'override yoksa kopya üretme');
  });

  testWidgets('last4 DOLU olsa bile hiçbir stilde kart yüzünde görünmez',
      (tester) async {
    for (final s in CardStyle.values) {
      await pump(tester,
          AccountCard(account: enpara, width: 300, styleOverride: s));
      expect(enpara.last4, '1234', reason: 'modelde var');
      expect(find.textContaining('1234'), findsNothing, reason: s.name);
      expect(find.textContaining('••••'), findsNothing, reason: s.name);
      expect(find.textContaining('****'), findsNothing, reason: s.name);
      expect(find.textContaining('/'), findsNothing,
          reason: '${s.name}: son kullanma yok');
    }
  });

  testWidgets('marka verilmezse addan tahmin, tutmazsa nötr "Diğer banka"',
      (tester) async {
    await pump(tester, const AccountCard(account: azCard, width: 300));
    expect(find.text('Kapital Bank'), findsOneWidget);
    expect(find.text('AZN'), findsOneWidget);

    const unknown = Account(
      id: 'a3',
      name: 'Harçlık kartı',
      currency: 'TRY',
      kind: AccountKind.card,
      balance: 0,
    );
    await pump(tester, const AccountCard(account: unknown, width: 300));
    expect(find.text('Diğer banka'), findsOneWidget);
    expect(find.text('Harçlık kartı'), findsOneWidget);
    expectFace(tester, CardStyle.flat);
    final grad = decorations(tester)
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .single;
    final neutral = bankByKey('other')!.color;
    for (final c in grad.colors) {
      // Nötr gri: kanallar birbirine yakın (doygunluk yok).
      expect((c.r - c.g).abs(), lessThan(0.03), reason: '$c');
      expect((c.r - neutral.r).abs(), lessThan(0.12));
    }
  });

  testWidgets('nakit hesabı kâğıt görünümünde, marka rengi/motifi kullanmaz',
      (tester) async {
    await pump(tester, const AccountCard(account: cash, width: 300));

    final decs = decorations(tester);
    expect(decs.any((d) => d.gradient != null), isFalse,
        reason: 'kâğıtta gradyan yok');
    expect(decs.any((d) => d.color == Ex.surface), isTrue,
        reason: 'zemin Ex.surface');
    expect(
      decs.any((d) => d.border is Border &&
          (d.border as Border).top.color == Ex.border),
      isTrue,
      reason: 'kenarlık Ex.border',
    );
    final brandColors = kBankCatalog.map((b) => b.color).toSet();
    for (final d in decs) {
      expect(brandColors.contains(d.color), isFalse, reason: '${d.color}');
    }
    // Stil painter'ı yok: nakit kart değil.
    expect(painters(tester).whereType<MetalFacePainter>(), isEmpty);
    expect(painters(tester).whereType<RibbonFacePainter>(), isEmpty);
    expect(painters(tester).whereType<SplitFacePainter>(), isEmpty);
    // Temassız simgesi yok.
    expect(hasContactless(tester), isFalse);
    expect(find.text('TRY'), findsOneWidget);
    // Başlık mürekkep rengi.
    final title = tester.widget<Text>(find.text('Nakit').first);
    expect(title.style?.color, Ex.text);

    // Override nakdi plastiğe çeviremez.
    await pump(tester,
        const AccountCard(account: cash, width: 300,
            styleOverride: CardStyle.metal));
    expect(painters(tester).whereType<MetalFacePainter>(), isEmpty);
    expect(decorations(tester).any((d) => d.color == Ex.surface), isTrue);
  });

  testWidgets('banka hesabında (IBAN) temassız simgesi yok', (tester) async {
    const iban = Account(
      id: 'a4',
      name: 'İş Bankası Vadesiz',
      currency: 'TRY',
      kind: AccountKind.bank,
      balance: 0,
    );
    await pump(tester, const AccountCard(account: iban, width: 300));
    expect(find.text('İş Bankası'), findsOneWidget);
    expect(hasContactless(tester), isFalse);

    // Açık zeminli banka hesabında da yok (Kaspi).
    const kz = Account(
      id: 'a7',
      name: 'Kaspi Depozit',
      currency: 'KZT',
      kind: AccountKind.bank,
      balance: 0,
    );
    await pump(tester, const AccountCard(account: kz, width: 300));
    expect(hasContactless(tester), isFalse);
    expectFace(tester, CardStyle.metal);
  });

  testWidgets('semantics: buton, seçili durumu ve "<ad>, <para birimi>"',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AccountCard(account: enpara, width: 300, selected: true, onTap: () {}),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('Enpara Maaş, TRY'));
    expect(
      node,
      matchesSemantics(
        label: 'Enpara Maaş, TRY',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    // İç metinler ayrıca okunmaz.
    expect(find.bySemanticsLabel('Enpara'), findsNothing);

    // Stil override etiketi değiştirmez.
    await pump(
      tester,
      AccountCard(
        account: enpara,
        width: 300,
        styleOverride: CardStyle.split,
        onTap: () {},
      ),
    );
    expect(find.bySemanticsLabel('Enpara Maaş, TRY'), findsOneWidget);

    await pump(tester, const AccountCard(account: cash, width: 300));
    expect(find.bySemanticsLabel('Nakit, TRY'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('seçiliyken Ex.text halka çizilir, değilken saydam',
      (tester) async {
    await pump(tester, const AccountCard(account: enpara, width: 300));
    Border ring() => decorations(tester)
        .map((d) => d.border)
        .whereType<Border>()
        .firstWhere((b) => b.top.width == AccountCard.ringWidth);
    expect(ring().top.color, Colors.transparent);

    await pump(tester,
        const AccountCard(account: enpara, width: 300, selected: true));
    expect(ring().top.color, Ex.text);
  });

  testWidgets('onTap tetiklenir', (tester) async {
    var taps = 0;
    await pump(tester,
        AccountCard(account: enpara, width: 300, onTap: () => taps++));
    await tester.tap(find.byType(AccountCard));
    expect(taps, 1);
  });

  testWidgets('320dp ekranda uzun adla hiçbir stil taşmaz', (tester) async {
    const long = Account(
      id: 'a5',
      name: 'Garanti BBVA Bonus Platinum Çok Uzun Bir Hesap Adı',
      currency: 'TRY',
      kind: AccountKind.card,
      balance: 0,
      last4: '9876',
    );
    for (final s in CardStyle.values) {
      await pump(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AccountCard(
            account: long,
            width: 288,
            selected: true,
            styleOverride: s,
          ),
        ),
        screenWidth: 320,
      );
      expect(tester.takeException(), isNull, reason: s.name);
      expect(find.text('Garanti BBVA'), findsOneWidget);
      expect(find.textContaining('9876'), findsNothing);

      // Küçük kart (grid hücresi) da sığar.
      await pump(tester,
          AccountCard(account: long, width: 140, styleOverride: s),
          screenWidth: 320);
      expect(tester.takeException(), isNull, reason: '${s.name} @140');
    }
  });
}
