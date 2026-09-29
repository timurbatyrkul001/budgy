import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/onboarding/onboarding_questions.dart';

import '../support/harness.dart';

/// Onboarding anket soruları: duygu (üç yüz + teselli baloncuğu) ve tek
/// seçimli liste. Metinler RS'ye taşınana kadar testte dışarıdan verilir.

// Üç dilde, en uzun/en dar hâli denemek için gerçekçi metinler.
const _moodTexts = {
  AppLanguage.tr: MoodQuestionTexts(
    title: 'Parayı takip etmek sana ne hissettiriyor?',
    labels: {
      MoodAnswer.stressed: 'Stresli',
      MoodAnswer.unsure: 'Kararsız',
      MoodAnswer.good: 'İyi',
    },
    comforts: {
      MoodAnswer.stressed:
          'Anlıyoruz. Budgy o yükü hafifletmek için var — küçük adımlarla.',
      MoodAnswer.unsure:
          'Gayet normal. Birkaç günde nereye gittiğini net göreceksin.',
      MoodAnswer.good: 'Harika. Bu hissi korumana yardım edeceğiz.',
    },
    next: 'İleri',
  ),
  AppLanguage.en: MoodQuestionTexts(
    title: 'How does tracking money make you feel?',
    labels: {
      MoodAnswer.stressed: 'Stressed',
      MoodAnswer.unsure: 'Unsure',
      MoodAnswer.good: 'Good',
    },
    comforts: {
      MoodAnswer.stressed:
          'We get it. Budgy is here to take that weight off — one small step at a time.',
      MoodAnswer.unsure:
          "Totally normal. In a few days you'll see clearly where it goes.",
      MoodAnswer.good: "That's great. We'll help you keep that feeling.",
    },
    next: 'Next',
  ),
  AppLanguage.ru: MoodQuestionTexts(
    title: 'Что ты чувствуешь, когда следишь за деньгами?',
    labels: {
      MoodAnswer.stressed: 'Стресс',
      MoodAnswer.unsure: 'Не знаю',
      MoodAnswer.good: 'Хорошо',
    },
    comforts: {
      MoodAnswer.stressed:
          'Понимаем. Budgy здесь, чтобы снять этот груз — маленькими шагами.',
      MoodAnswer.unsure:
          'Это нормально. Через пару дней ты ясно увидишь, куда всё уходит.',
      MoodAnswer.good: 'Отлично. Поможем сохранить это чувство.',
    },
    next: 'Далее',
  ),
};

const _hardTitles = {
  AppLanguage.tr: 'En zor gelen ne?',
  AppLanguage.en: "What's the hardest part?",
  AppLanguage.ru: 'Что даётся труднее всего?',
};

const _hardOptions = {
  AppLanguage.tr: [
    ChoiceOption(id: 'income', label: 'Ne zaman ne kazandığımı bilmemek'),
    ChoiceOption(id: 'where', label: 'Harcamaların nereye gittiğini görmemek'),
    ChoiceOption(id: 'monthEnd', label: 'Ay sonunu getirememek'),
    ChoiceOption(id: 'habit', label: 'Düzenli takip edememek'),
    ChoiceOption(id: 'other', label: 'Başka bir şey'),
  ],
  AppLanguage.en: [
    ChoiceOption(id: 'income', label: 'Not knowing when I earn what'),
    ChoiceOption(id: 'where', label: 'Not seeing where the money goes'),
    ChoiceOption(id: 'monthEnd', label: 'Running out before month end'),
    ChoiceOption(id: 'habit', label: 'Not keeping it up regularly'),
    ChoiceOption(id: 'other', label: 'Something else'),
  ],
  AppLanguage.ru: [
    ChoiceOption(id: 'income', label: 'Не знаю, когда и сколько заработал'),
    ChoiceOption(id: 'where', label: 'Не вижу, куда уходят деньги'),
    ChoiceOption(id: 'monthEnd', label: 'Не дотягиваю до конца месяца'),
    ChoiceOption(id: 'habit', label: 'Не получается вести регулярно'),
    ChoiceOption(id: 'other', label: 'Другое'),
  ],
};

const _nextLabels = {
  AppLanguage.tr: 'İleri',
  AppLanguage.en: 'Next',
  AppLanguage.ru: 'Далее',
};

void main() {
  // ── Duygu sorusu ──────────────────────────────────────────────────────

  testWidgets('duygu: seçim yokken teselli yok ve Devam sönük',
      (tester) async {
    MoodAnswer? got;
    final t = _moodTexts[AppLanguage.tr]!;
    await pumpBudgyScreen(
      tester,
      Scaffold(body: MoodQuestionPage(texts: t, onNext: (a) => got = a)),
      db: FakeFirebaseFirestore(),
    );
    expect(find.text(t.title), findsOneWidget);
    for (final c in t.comforts.values) {
      expect(find.text(c), findsNothing);
    }
    await tester.tap(find.text(t.next));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  for (final answer in MoodAnswer.values) {
    testWidgets('duygu: ${answer.name} seçilince doğru teselli çıkar, Devam '
        'doğru cevabı verir', (tester) async {
      MoodAnswer? got;
      final t = _moodTexts[AppLanguage.tr]!;
      await pumpBudgyScreen(
        tester,
        Scaffold(body: MoodQuestionPage(texts: t, onNext: (a) => got = a)),
        db: FakeFirebaseFirestore(),
      );
      await tester.tap(find.text(t.labels[answer]!));
      await tester.pumpAndSettle();
      expect(find.text(t.comforts[answer]!), findsOneWidget);
      for (final other in MoodAnswer.values.where((m) => m != answer)) {
        expect(find.text(t.comforts[other]!), findsNothing);
      }
      await tester.tap(find.text(t.next));
      await tester.pumpAndSettle();
      expect(got, answer);
    });
  }

  testWidgets('duygu: cevap değiştirilince teselli metni değişir',
      (tester) async {
    final t = _moodTexts[AppLanguage.en]!;
    await pumpBudgyScreen(
      tester,
      Scaffold(body: MoodQuestionPage(texts: t, onNext: (_) {})),
      db: FakeFirebaseFirestore(),
      language: AppLanguage.en,
    );
    await tester.tap(find.text(t.labels[MoodAnswer.stressed]!));
    await tester.pumpAndSettle();
    expect(find.text(t.comforts[MoodAnswer.stressed]!), findsOneWidget);
    await tester.tap(find.text(t.labels[MoodAnswer.good]!));
    await tester.pumpAndSettle();
    expect(find.text(t.comforts[MoodAnswer.good]!), findsOneWidget);
    expect(find.text(t.comforts[MoodAnswer.stressed]!), findsNothing);
  });

  // ── Liste sorusu ──────────────────────────────────────────────────────

  testWidgets('liste: seçim olmadan Devam çalışmaz, seçilince doğru id gelir',
      (tester) async {
    String? got;
    final lang = AppLanguage.tr;
    await pumpBudgyScreen(
      tester,
      Scaffold(
        body: ChoiceQuestionPage(
          title: _hardTitles[lang]!,
          options: _hardOptions[lang]!,
          nextLabel: _nextLabels[lang]!,
          onNext: (id) => got = id,
        ),
      ),
      db: FakeFirebaseFirestore(),
    );
    expect(find.text(_hardTitles[lang]!), findsOneWidget);
    await tester.tap(find.text(_nextLabels[lang]!));
    await tester.pumpAndSettle();
    expect(got, isNull);

    await tester.tap(find.text('Ay sonunu getirememek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_nextLabels[lang]!));
    await tester.pumpAndSettle();
    expect(got, 'monthEnd');
  });

  testWidgets('liste: tek seçim — ikinci dokunuş öncekini bırakır',
      (tester) async {
    String? got;
    final lang = AppLanguage.en;
    await pumpBudgyScreen(
      tester,
      Scaffold(
        body: ChoiceQuestionPage(
          title: _hardTitles[lang]!,
          options: _hardOptions[lang]!,
          nextLabel: _nextLabels[lang]!,
          onNext: (id) => got = id,
        ),
      ),
      db: FakeFirebaseFirestore(),
      language: lang,
    );
    await tester.tap(find.text('Not seeing where the money goes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_nextLabels[lang]!));
    await tester.pumpAndSettle();
    expect(got, 'other');
  });

  // ── Yerleşim: üç dil, 320 ve 360 dp, kısa ekran ───────────────────────

  for (final lang in AppLanguage.values) {
    for (final size in const [Size(320, 800), Size(360, 800), Size(320, 568)]) {
      final tag = '${size.width.toInt()}×${size.height.toInt()} · ${lang.code}';

      testWidgets('duygu sorusu · $tag taşmıyor (seçili + baloncuk)',
          (tester) async {
        final t = _moodTexts[lang]!;
        await pumpBudgyScreen(
          tester,
          Scaffold(body: MoodQuestionPage(texts: t, onNext: (_) {})),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: size,
        );
        expect(tester.takeException(), isNull);
        // En uzun teselli metniyle en dolu hâl.
        await tester.tap(find.text(t.labels[MoodAnswer.stressed]!));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(t.comforts[MoodAnswer.stressed]!), findsOneWidget);
      });

      testWidgets('liste sorusu · $tag taşmıyor', (tester) async {
        await pumpBudgyScreen(
          tester,
          Scaffold(
            body: ChoiceQuestionPage(
              title: _hardTitles[lang]!,
              options: _hardOptions[lang]!,
              nextLabel: _nextLabels[lang]!,
              onNext: (_) {},
            ),
          ),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: size,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(_hardOptions[lang]!.first.label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
