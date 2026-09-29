import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_palette.dart';
import 'package:kopilka_app/features/onboarding/onboarding_response.dart';

import '../support/harness.dart';

/// Onboarding içerik ekranları: cevaba karşılık (AnswerResponsePage) ve
/// "Hazır" özeti (SetupSummaryPage). Metinler RS'ye taşınana kadar testte
/// dışarıdan verilir — üç dilde, en uzun hâlleriyle.

const _answerIds = ['income', 'where', 'monthEnd', 'habit', 'other'];

const _responseTexts = {
  AppLanguage.tr: AnswerResponseTexts(
    titles: {
      'income': 'Sorun sende değil, takvimde.',
      'where': 'Para uçmuyor. Sadece kayıt yok.',
      'monthEnd': "Ayın 20'si sürpriz olmamalı.",
      'habit': 'Bırakmadın. Yöntem çok uğraştırıyordu.',
      'other': 'Ne olursa olsun, ilk adım aynı.',
    },
    bodies: {
      'income':
          'Düzensiz gelir deftere sığmaz. Budgy çalıştığın günleri işaretler; ne zaman ne alacağını kendisi hesaplar.',
      'where':
          'Aklında tutmak bir yöntem değil. Budgy her harcamayı kategorisine koyar; nereye ne gitti, tek bakışta.',
      'monthEnd':
          'Sınırı bilmeden tutumlu olunmaz. Budgy her kategoriye bütçe koyar; tempon hızlıysa ay bitmeden söyler.',
      'habit':
          "Günde beş dakika isteyen alışkanlık tutmaz. Budgy'de bir harcama üç saniye: tuşla, sesle söyle ya da fişi çek.",
      'other':
          'Gördüğün parayı yönetirsin. Budgy önce göstermeye başlar; gerisi sana göre şekillenir.',
    },
    next: 'İleri',
  ),
  AppLanguage.en: AnswerResponseTexts(
    titles: {
      'income': "It's not you. It's the calendar.",
      'where': "Money doesn't vanish. It just goes unrecorded.",
      'monthEnd': "The 20th shouldn't be a surprise.",
      'habit': "You didn't quit. The method was too much work.",
      'other': 'Whatever it is, step one is the same.',
    },
    bodies: {
      'income':
          'Irregular income never fit a notebook. Budgy marks the days you work and tells you when the money lands — and how much.',
      'where':
          "Remembering isn't a system. Budgy files every expense under its category, so where it went is one glance away.",
      'monthEnd':
          "You can't pace yourself without a line. Budgy sets a budget per category and warns you when you're burning through it too fast.",
      'habit':
          'A habit that costs five minutes a day never sticks. In Budgy an expense takes three seconds: tap it in, say it, or snap the receipt.',
      'other':
          'You can only manage what you can see. Budgy starts by showing you — the rest shapes itself around you.',
    },
    next: 'Next',
  ),
  AppLanguage.ru: AnswerResponseTexts(
    titles: {
      'income': 'Дело не в тебе, а в календаре.',
      'where': 'Деньги не исчезают. Их просто никто не записал.',
      'monthEnd': 'Двадцатое число не должно быть сюрпризом.',
      'habit': 'Дело не в дисциплине. Дело в методе.',
      'other': 'С чего бы ни начать, первый шаг один.',
    },
    bodies: {
      'income':
          'Нерегулярный доход не помещается в тетрадь. Budgy отмечает рабочие дни и сам считает, когда и сколько придёт.',
      'where':
          'Держать всё в голове — не метод. Budgy раскладывает каждую трату по категориям: куда ушло — видно с одного взгляда.',
      'monthEnd':
          'Нельзя экономить, не зная границы. Budgy ставит бюджет на каждую категорию и предупреждает, если тратишь быстрее, чем нужно.',
      'habit':
          'Привычка, которая требует пять минут в день, не приживается. В Budgy трата занимает три секунды: набери, надиктуй или сфотографируй чек.',
      'other':
          'Управлять можно только тем, что видишь. Budgy начинает с того, что показывает, — остальное подстроится под тебя.',
    },
    next: 'Далее',
  ),
};

const _summaryTexts = {
  AppLanguage.tr: SetupSummaryTexts(
    title: 'Hazır.',
    expenseLine: '{n} gider kategorisi',
    incomeLine: '{n} gelir kaynağı',
    body:
        'Hepsi ana ekranda seni bekliyor. İlk harcamanı girdiğin an tablo dolmaya başlar.',
    empty: 'Şimdilik kategori seçmedin — sorun değil, ilk harcamada Budgy önerir.',
    next: 'İleri',
  ),
  AppLanguage.en: SetupSummaryTexts(
    title: 'All set.',
    expenseLine: '{n} expense categories',
    incomeLine: '{n} income sources',
    body:
        "They're waiting on your home screen. The picture starts filling in with your first expense.",
    empty:
        "No categories yet — that's fine, Budgy will suggest one with your first expense.",
    next: 'Next',
  ),
  AppLanguage.ru: SetupSummaryTexts(
    title: 'Готово.',
    expenseLine: 'Категорий расходов: {n}',
    incomeLine: 'Источников дохода: {n}',
    body:
        'Они уже ждут на главном экране. Картина начнёт складываться с первой записи.',
    empty: 'Категории пока не выбраны — ничего, Budgy предложит при первой трате.',
    next: 'Далее',
  ),
};

/// Sayfayı akıştaki gibi kâğıt zeminli, güvenli alanlı bir Scaffold'a koyar.
Widget _paper(Widget page) => Scaffold(
      backgroundColor: Poster.paper,
      body: SafeArea(child: page),
    );

/// Bir Text.rich'in düz metnini döndürür (sayaç satırını okumak için).
/// Rakam WidgetSpan içinde ayrı bir Text olduğundan onun da metni alınır;
/// `toPlainText` orada yer tutucu karakter bırakırdı.
String _plain(Text t) {
  if (t.data != null) return t.data!;
  final b = StringBuffer();
  t.textSpan!.visitChildren((span) {
    if (span is TextSpan) b.write(span.text ?? '');
    if (span is WidgetSpan) {
      final child = span.child;
      if (child is Text) b.write(child.data ?? '');
    }
    return true;
  });
  return b.toString();
}

void main() {
  // Test fontu (Ahem) her harfi tam kare çizer ve gerçeğin iki katı geniş
  // ölçer; yerleşim testleri anlamlı olsun diye gerçek InterDisplay ve
  // Inter dosyaları yüklenir.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final display = FontLoader('InterDisplay');
    for (final f in ['InterDisplay-Black', 'InterDisplay-SemiBold']) {
      final bytes = await File('assets/fonts/$f.ttf').readAsBytes();
      display.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await display.load();
    final inter = FontLoader('Inter');
    final bytes = await File('assets/fonts/Inter-Regular.ttf').readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
    await inter.load();
  });

  group('AnswerResponsePage', () {
    for (final id in _answerIds) {
      testWidgets('"$id" cevabı kendi karşılığını gösterir', (tester) async {
        final t = _responseTexts[AppLanguage.tr]!;
        var tapped = 0;
        await pumpBudgyScreen(
          tester,
          _paper(AnswerResponsePage(
            answerId: id,
            texts: t,
            onNext: () => tapped++,
          )),
          db: FakeFirebaseFirestore(),
        );
        expect(find.text(t.titles[id]!), findsOneWidget);
        expect(find.text(t.bodies[id]!), findsOneWidget);
        // Diğer cevapların metni ekranda yok.
        for (final other in _answerIds.where((o) => o != id)) {
          expect(find.text(t.titles[other]!), findsNothing);
        }
        await tester.tap(find.text(t.next));
        expect(tapped, 1);
      });
    }

    testWidgets('bilinmeyen kimlik çökmez, genel metne düşer', (tester) async {
      final t = _responseTexts[AppLanguage.tr]!;
      await pumpBudgyScreen(
        tester,
        _paper(AnswerResponsePage(
          answerId: 'something-new',
          texts: t,
          onNext: () {},
        )),
        db: FakeFirebaseFirestore(),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(t.titles['other']!), findsOneWidget);
      expect(find.text(t.bodies['other']!), findsOneWidget);
    });

    testWidgets('genel metin de yoksa boş kalmaz, ilk metne düşer',
        (tester) async {
      const t = AnswerResponseTexts(
        titles: {'income': 'Tek başlık'},
        bodies: {'income': 'Tek gövde'},
        next: 'İleri',
      );
      await pumpBudgyScreen(
        tester,
        _paper(const AnswerResponsePage(
          answerId: 'nope',
          texts: t,
          onNext: _noop,
        )),
        db: FakeFirebaseFirestore(),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tek başlık'), findsOneWidget);
    });

    for (final lang in AppLanguage.values) {
      for (final size in const [Size(320, 568), Size(320, 800)]) {
        testWidgets(
            '${lang.code} ${size.width.toInt()}x${size.height.toInt()} taşmaz',
            (tester) async {
          final t = _responseTexts[lang]!;
          for (final id in _answerIds) {
            await pumpBudgyScreen(
              tester,
              _paper(AnswerResponsePage(
                answerId: id,
                texts: t,
                onNext: () {},
              )),
              db: FakeFirebaseFirestore(),
              language: lang,
              logicalSize: size,
            );
            expect(tester.takeException(), isNull, reason: id);
          }
        });
      }
    }
  });

  group('SetupSummaryPage', () {
    testWidgets('sayıları doğru basar ve ileri çağırır', (tester) async {
      final t = _summaryTexts[AppLanguage.tr]!;
      var tapped = 0;
      await pumpBudgyScreen(
        tester,
        _paper(SetupSummaryPage(
          expenseCount: 7,
          incomeCount: 3,
          texts: t,
          onNext: () => tapped++,
        )),
        db: FakeFirebaseFirestore(),
      );
      expect(find.text(t.title), findsOneWidget);
      final lines = tester
          .widgetList<Text>(find.byType(Text))
          .map(_plain)
          .toList();
      expect(lines, contains('7 gider kategorisi'));
      expect(lines, contains('3 gelir kaynağı'));
      expect(find.text(t.body), findsOneWidget);
      expect(find.text(t.empty), findsNothing);
      await tester.tap(find.text(t.next));
      expect(tapped, 1);
    });

    testWidgets('sayı sonda gelen dilde (RU) de doğru yerleşir',
        (tester) async {
      final t = _summaryTexts[AppLanguage.ru]!;
      await pumpBudgyScreen(
        tester,
        _paper(SetupSummaryPage(
          expenseCount: 12,
          incomeCount: 1,
          texts: t,
          onNext: () {},
        )),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.ru,
      );
      final lines =
          tester.widgetList<Text>(find.byType(Text)).map(_plain).toList();
      expect(lines, contains('Категорий расходов: 12'));
      expect(lines, contains('Источников дохода: 1'));
    });

    testWidgets('sıfır olan satır gizlenir', (tester) async {
      final t = _summaryTexts[AppLanguage.tr]!;
      await pumpBudgyScreen(
        tester,
        _paper(SetupSummaryPage(
          expenseCount: 5,
          incomeCount: 0,
          texts: t,
          onNext: () {},
        )),
        db: FakeFirebaseFirestore(),
      );
      final lines =
          tester.widgetList<Text>(find.byType(Text)).map(_plain).toList();
      expect(lines, contains('5 gider kategorisi'));
      expect(lines.any((l) => l.contains('gelir kaynağı')), isFalse);
      expect(find.text(t.body), findsOneWidget);
    });

    testWidgets('ikisi de sıfırsa boş metni gösterir', (tester) async {
      final t = _summaryTexts[AppLanguage.tr]!;
      await pumpBudgyScreen(
        tester,
        _paper(SetupSummaryPage(
          expenseCount: 0,
          incomeCount: 0,
          texts: t,
          onNext: () {},
        )),
        db: FakeFirebaseFirestore(),
      );
      expect(find.text(t.empty), findsOneWidget);
      expect(find.text(t.body), findsNothing);
    });

    testWidgets('sayaç hareketle 0\'dan hedefe sayar', (tester) async {
      // Harness animasyonları kapatır; burada gerçek sayaç davranışı için
      // MediaQuery'yi açık bırakıp sayfayı doğrudan pompalıyoruz.
      final t = _summaryTexts[AppLanguage.tr]!;
      tester.view.physicalSize = const Size(360, 800) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _paper(SetupSummaryPage(
              expenseCount: 9,
              incomeCount: 0,
              texts: t,
              onNext: () {},
            )),
          ),
        ),
      );
      String line() => tester
          .widgetList<Text>(find.byType(Text))
          .map(_plain)
          .firstWhere((l) => l.endsWith('gider kategorisi'));
      // İlk kare: 0.
      expect(line(), '0 gider kategorisi');
      await tester.pump(const Duration(milliseconds: 500));
      expect(line(), '9 gider kategorisi');
    });

    for (final lang in AppLanguage.values) {
      for (final size in const [Size(320, 568), Size(320, 800)]) {
        testWidgets(
            '${lang.code} ${size.width.toInt()}x${size.height.toInt()} taşmaz',
            (tester) async {
          await pumpBudgyScreen(
            tester,
            _paper(SetupSummaryPage(
              expenseCount: 22,
              incomeCount: 11,
              texts: _summaryTexts[lang]!,
              onNext: () {},
            )),
            db: FakeFirebaseFirestore(),
            language: lang,
            logicalSize: size,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // Gözle görme: RESPONSE_PNG_DIR verilirse gerçek fontlarla PNG döker.
  //   RESPONSE_PNG_DIR=/tmp/x flutter test test/widget/onboarding_response_test.dart
  final pngDir = Platform.environment['RESPONSE_PNG_DIR'];
  testWidgets('önizleme PNG', (tester) async {
    Future<void> dump(String name, Widget page, AppLanguage lang, Size size) async {
      final key = GlobalKey();
      await pumpBudgyScreen(
        tester,
        RepaintBoundary(key: key, child: _paper(page)),
        db: FakeFirebaseFirestore(),
        language: lang,
        logicalSize: size,
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$pngDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
      });
    }

    for (final (lang, id) in [
      (AppLanguage.tr, 'habit'),
      (AppLanguage.en, 'monthEnd'),
      (AppLanguage.ru, 'where'),
    ]) {
      await dump(
        'response_${lang.code}_$id',
        AnswerResponsePage(
          answerId: id,
          texts: _responseTexts[lang]!,
          onNext: () {},
        ),
        lang,
        const Size(360, 780),
      );
    }
    await dump(
      'response_tr_income_320x568',
      AnswerResponsePage(
        answerId: 'income',
        texts: _responseTexts[AppLanguage.tr]!,
        onNext: () {},
      ),
      AppLanguage.tr,
      const Size(320, 568),
    );
    for (final lang in AppLanguage.values) {
      await dump(
        'summary_${lang.code}',
        SetupSummaryPage(
          expenseCount: 7,
          incomeCount: 3,
          texts: _summaryTexts[lang]!,
          onNext: () {},
        ),
        lang,
        const Size(360, 780),
      );
    }
  }, skip: pngDir == null);
}

void _noop() {}
