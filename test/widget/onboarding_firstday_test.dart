import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_firstday.dart';
import 'package:kopilka_app/features/onboarding/onboarding_palette.dart';

import '../support/harness.dart';

/// Onboarding'in son iki ekranı: bildirim izni (sahte izin çağrısıyla) ve
/// ilk günü işaretleme (takvim + tutar). Metinler RS'ye taşınana kadar
/// testte dışarıdan verilir.

const _notifTexts = {
  AppLanguage.tr: NotificationAskTexts(
    title: 'Günü işaretlemeyi unutma',
    body:
        'Akşam tek bir dokunuş: "Bugün ne kazandın?" Bir kez unutursan '
        'ay sonu hesabı tutmaz — hatırlatalım.',
    allow: 'İzin ver',
    later: 'Şimdi değil',
  ),
  AppLanguage.en: NotificationAskTexts(
    title: "Don't forget to mark the day",
    body:
        'One tap in the evening: "What did you earn today?" Miss a day '
        "and the month won't add up — let us remind you.",
    allow: 'Allow',
    later: 'Not now',
  ),
  AppLanguage.ru: NotificationAskTexts(
    title: 'Не забывай отмечать день',
    body:
        'Одно касание вечером: «Сколько заработал сегодня?» Пропустишь '
        'день — месяц не сойдётся. Мы напомним.',
    allow: 'Разрешить',
    later: 'Не сейчас',
  ),
};

const _dayTexts = {
  AppLanguage.tr: FirstDayTexts(
    title: 'İlk gününü işaretle',
    body: 'Bugüne dokun, kazancını yaz. Uygulamaya böyle başlanır — hepsi bu.',
    tapHint: 'Bugüne dokun',
    amountHint: 'Bugün ne kazandın?',
    confirm: 'Kaydet',
    done: 'İlk günün defterde. Böyle devam.',
    next: 'Devam',
    skip: 'Şimdilik atla',
  ),
  AppLanguage.en: FirstDayTexts(
    title: 'Mark your first day',
    body:
        "Tap today and type what you earned. That's how Budgy works — "
        "that's all.",
    tapHint: 'Tap today',
    amountHint: 'What did you earn today?',
    confirm: 'Save',
    done: 'First day is in the book. Keep going.',
    next: 'Next',
    skip: 'Skip for now',
  ),
  AppLanguage.ru: FirstDayTexts(
    title: 'Отметь первый день',
    body:
        'Коснись сегодняшнего дня и впиши заработок. Так и работает '
        'Budgy — вот и всё.',
    tapHint: 'Коснись сегодня',
    amountHint: 'Сколько заработал сегодня?',
    confirm: 'Сохранить',
    done: 'Первый день в блокноте. Так держать.',
    next: 'Далее',
    skip: 'Пока пропустить',
  ),
};

/// Sabit "bugün": 17 Eylül 2026 (Perşembe) — ay 5 satırlık, testler
/// takvimden bağımsız.
final _today = DateTime(2026, 9, 17);

Widget _paper(Widget child) => Scaffold(
  backgroundColor: Poster.paper,
  body: SafeArea(child: child),
);

/// Etiketi verilen hap/metin düğmesinin InkWell'i (pasiflik kontrolü için).
InkWell _inkWellOf(WidgetTester tester, String label) => tester.widget<InkWell>(
  find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
);

void main() {
  // Test fontu (Ahem) her harfi tam kare çizer ve gerçeğin iki katı
  // genişlikte ölçer; yerleşim testleri anlamlı olsun diye gerçek fontlar
  // yüklenir.
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

  // ── Bildirim izni ─────────────────────────────────────────────────────

  testWidgets('izin: "İzin ver" sahte izni çağırır ve sonucu onNext\'e verir', (
    tester,
  ) async {
    bool? got;
    var asked = 0;
    final t = _notifTexts[AppLanguage.tr]!;
    await pumpBudgyScreen(
      tester,
      _paper(
        NotificationAskPage(
          texts: t,
          requestPermission: () async {
            asked++;
            return true;
          },
          onNext: (g) => got = g,
        ),
      ),
      db: FakeFirebaseFirestore(),
    );
    expect(find.text(t.title), findsOneWidget);
    expect(find.text(t.body), findsOneWidget);
    await tester.tap(find.text(t.allow));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(got, isTrue);
  });

  testWidgets('izin: ret gelince de akış devam eder (onNext(false))', (
    tester,
  ) async {
    bool? got;
    final t = _notifTexts[AppLanguage.en]!;
    await pumpBudgyScreen(
      tester,
      _paper(
        NotificationAskPage(
          texts: t,
          requestPermission: () async => false,
          onNext: (g) => got = g,
        ),
      ),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    await tester.tap(find.text(t.allow));
    await tester.pumpAndSettle();
    expect(got, isFalse);
  });

  testWidgets('izin: izin çağrısı fırlatsa bile onNext(false) gelir', (
    tester,
  ) async {
    bool? got;
    final t = _notifTexts[AppLanguage.tr]!;
    await pumpBudgyScreen(
      tester,
      _paper(
        NotificationAskPage(
          texts: t,
          requestPermission: () async => throw StateError('no platform'),
          onNext: (g) => got = g,
        ),
      ),
      db: FakeFirebaseFirestore(),
    );
    await tester.tap(find.text(t.allow));
    await tester.pumpAndSettle();
    expect(got, isFalse);
  });

  testWidgets('izin: "Şimdi değil" izin sormadan onNext(false) der', (
    tester,
  ) async {
    bool? got;
    var asked = 0;
    final t = _notifTexts[AppLanguage.tr]!;
    await pumpBudgyScreen(
      tester,
      _paper(
        NotificationAskPage(
          texts: t,
          requestPermission: () async {
            asked++;
            return true;
          },
          onNext: (g) => got = g,
        ),
      ),
      db: FakeFirebaseFirestore(),
    );
    await tester.tap(find.text(t.later));
    await tester.pumpAndSettle();
    expect(asked, 0);
    expect(got, isFalse);
  });

  // ── İlk gün ───────────────────────────────────────────────────────────

  testWidgets('ilk gün: bugüne dokun, tutar gir, Kaydet, Devam → doğru sayı', (
    tester,
  ) async {
    double? got;
    var calls = 0;
    final t = _dayTexts[AppLanguage.tr]!;
    await pumpBudgyScreen(
      tester,
      _paper(
        FirstDayPage(
          texts: t,
          today: _today,
          onNext: (a) {
            calls++;
            got = a;
          },
        ),
      ),
      db: FakeFirebaseFirestore(),
    );
    expect(find.text(t.title), findsOneWidget);
    expect(find.text(t.tapHint), findsOneWidget);
    expect(find.text('Eylül 2026'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // Bugün (17) dokunulur, tutar alanı açılır.
    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(t.tapHint), findsNothing);

    // Virgüllü tutar: parseAmount 1.250,50 → 1250.5
    await tester.enterText(find.byType(TextField), '1.250,50');
    await tester.pumpAndSettle();
    expect(_inkWellOf(tester, t.confirm).onTap, isNotNull);
    await tester.tap(find.text(t.confirm));
    await tester.pumpAndSettle();

    // Hücre tik oldu (sayı gitti), kutlama satırı ve tutar göründü.
    expect(find.byType(TextField), findsNothing);
    expect(find.text(t.done), findsOneWidget);
    expect(find.textContaining('1'), findsWidgets);
    expect(find.text(t.skip), findsNothing);
    expect(calls, 0);

    await tester.tap(find.text(t.next));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(got, 1250.5);
  });

  testWidgets('ilk gün: "Şimdilik atla" onNext(null) verir', (tester) async {
    var calls = 0;
    double? got = -1;
    final t = _dayTexts[AppLanguage.en]!;
    await pumpBudgyScreen(
      tester,
      _paper(
        FirstDayPage(
          texts: t,
          today: _today,
          onNext: (a) {
            calls++;
            got = a;
          },
        ),
      ),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    await tester.tap(find.text(t.skip));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(got, isNull);
  });

  testWidgets('ilk gün: geçersiz/boş/sıfır tutarda Kaydet pasif', (
    tester,
  ) async {
    var calls = 0;
    final t = _dayTexts[AppLanguage.tr]!;
    await pumpBudgyScreen(
      tester,
      _paper(FirstDayPage(texts: t, today: _today, onNext: (_) => calls++)),
      db: FakeFirebaseFirestore(),
    );
    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();

    // Boş.
    expect(_inkWellOf(tester, t.confirm).onTap, isNull);
    // Sıfır.
    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();
    expect(_inkWellOf(tester, t.confirm).onTap, isNull);
    // Sadece ayraç.
    await tester.enterText(find.byType(TextField), ',');
    await tester.pumpAndSettle();
    expect(_inkWellOf(tester, t.confirm).onTap, isNull);
    await tester.tap(find.text(t.confirm));
    await tester.pumpAndSettle();
    expect(find.text(t.done), findsNothing);
    expect(calls, 0);

    // Geçerli olunca açılır.
    await tester.enterText(find.byType(TextField), '800');
    await tester.pumpAndSettle();
    expect(_inkWellOf(tester, t.confirm).onTap, isNotNull);
  });

  testWidgets('ilk gün: yalnız bugün dokunulabilir', (tester) async {
    final t = _dayTexts[AppLanguage.tr]!;
    await pumpBudgyScreen(
      tester,
      _paper(FirstDayPage(texts: t, today: _today, onNext: (_) {})),
      db: FakeFirebaseFirestore(),
    );
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('ilk gün: klavyeden onay (submit) da kaydeder', (tester) async {
    double? got;
    final t = _dayTexts[AppLanguage.ru]!;
    await pumpBudgyScreen(
      tester,
      _paper(FirstDayPage(texts: t, today: _today, onNext: (a) => got = a)),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.ru,
    );
    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(t.done), findsOneWidget);
    await tester.tap(find.text(t.next));
    await tester.pumpAndSettle();
    expect(got, 2500);
  });

  // ── Yerleşim: üç dil, 320×568 / 320×800 / 360×800 ─────────────────────

  for (final lang in AppLanguage.values) {
    for (final size in const [Size(320, 568), Size(320, 800), Size(360, 800)]) {
      final tag = '${size.width.toInt()}×${size.height.toInt()} · ${lang.code}';

      testWidgets('izin · $tag taşmıyor', (tester) async {
        final t = _notifTexts[lang]!;
        await pumpBudgyScreen(
          tester,
          _paper(
            NotificationAskPage(
              texts: t,
              requestPermission: () async => true,
              onNext: (_) {},
            ),
          ),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: size,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(t.allow), findsOneWidget);
        expect(find.text(t.later), findsOneWidget);
      });

      testWidgets('ilk gün · $tag taşmıyor (üç aşama)', (tester) async {
        final t = _dayTexts[lang]!;
        await pumpBudgyScreen(
          tester,
          _paper(FirstDayPage(texts: t, today: _today, onNext: (_) {})),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: size,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('17'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), '12345678');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(t.confirm));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(t.done), findsOneWidget);
      });
    }
  }
}
