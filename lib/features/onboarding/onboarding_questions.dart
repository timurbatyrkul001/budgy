import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/motion.dart';
import 'onboarding_palette.dart';

// TODO(rs): Aşağıdaki metinler `lib/core/redesign_l10n.dart`'a (RS) taşınacak;
// bu dosya metni sabit tutmaz, [MoodQuestionTexts] / [ChoiceQuestionPage]
// parametreleriyle dışarıdan alır. Önerilen anahtarlar ve üç dil:
//
//   qMoodTitle
//     tr: 'Parayı takip etmek sana ne hissettiriyor?'
//     en: 'How does tracking money make you feel?'
//     ru: 'Что ты чувствуешь, когда следишь за деньгами?'
//   qMoodStressed        tr: 'Stresli'     en: 'Stressed'   ru: 'Стресс'
//   qMoodUnsure          tr: 'Kararsız'    en: 'Unsure'     ru: 'Не знаю'
//   qMoodGood            tr: 'İyi'         en: 'Good'       ru: 'Хорошо'
//   qMoodComfortStressed
//     tr: 'Anlıyoruz. Budgy o yükü hafifletmek için var — küçük adımlarla.'
//     en: 'We get it. Budgy is here to take that weight off — one small step at a time.'
//     ru: 'Понимаем. Budgy здесь, чтобы снять этот груз — маленькими шагами.'
//   qMoodComfortUnsure
//     tr: 'Gayet normal. Birkaç günde nereye gittiğini net göreceksin.'
//     en: 'Totally normal. In a few days you\'ll see clearly where it goes.'
//     ru: 'Это нормально. Через пару дней ты ясно увидишь, куда всё уходит.'
//   qMoodComfortGood
//     tr: 'Harika. Bu hissi korumana yardım edeceğiz.'
//     en: 'That\'s great. We\'ll help you keep that feeling.'
//     ru: 'Отлично. Поможем сохранить это чувство.'
//
//   qHardTitle
//     tr: 'En zor gelen ne?'
//     en: 'What\'s the hardest part?'
//     ru: 'Что даётся труднее всего?'
//   qHardIncome      tr: 'Ne zaman ne kazandığımı bilmemek'
//                    en: 'Not knowing when I earn what'
//                    ru: 'Не знаю, когда и сколько заработал'
//   qHardWhere       tr: 'Harcamaların nereye gittiğini görmemek'
//                    en: 'Not seeing where the money goes'
//                    ru: 'Не вижу, куда уходят деньги'
//   qHardMonthEnd    tr: 'Ay sonunu getirememek'
//                    en: 'Running out before month end'
//                    ru: 'Не дотягиваю до конца месяца'
//   qHardHabit       tr: 'Düzenli takip edememek'
//                    en: 'Not keeping it up regularly'
//                    ru: 'Не получается вести регулярно'
//   qHardOther       tr: 'Başka bir şey'   en: 'Something else'   ru: 'Другое'
//
//   qMethodTitle
//     tr: 'Şu an nasıl takip ediyorsun?'
//     en: 'How do you track it today?'
//     ru: 'Как ты ведёшь учёт сейчас?'
//   qMethodNone      tr: 'Hiç takip etmiyorum'   en: 'I don\'t track it'   ru: 'Никак'
//   qMethodPaper     tr: 'Kâğıt kalem'           en: 'Pen and paper'       ru: 'Ручка и бумага'
//   qMethodSheet     tr: 'Tablo (Excel, Sheets)' en: 'Spreadsheet'         ru: 'Таблица (Excel, Sheets)'
//   qMethodApp       tr: 'Başka bir uygulama'    en: 'Another app'         ru: 'Другое приложение'
//
//   Devam düğmesi için mevcut `RS.next` kullanılabilir.

/// Duygu sorusunun cevapları.
enum MoodAnswer { stressed, unsure, good }

/// Duygu sorusunun metinleri — koordinatör RS'den kurar.
class MoodQuestionTexts {
  const MoodQuestionTexts({
    required this.title,
    required this.labels,
    required this.comforts,
    required this.next,
  });

  final String title;

  /// Yüzlerin altındaki etiketler (üç cevap da olmalı).
  final Map<MoodAnswer, String> labels;

  /// Seçimden sonra baloncukta beliren teselli cümlesi (üç cevap da olmalı).
  final Map<MoodAnswer, String> comforts;

  /// Devam düğmesi.
  final String next;
}

/// Emoji yüzlü duygu sorusu — seçime göre teselli metni gösterir.
///
/// Üç yüz yan yana; dokununca seçilen büyür ve marka yeşiline döner,
/// diğerleri soluklaşır. Altında yeşil teselli baloncuğu yumuşak geçişle
/// belirir ve "Devam" etkinleşir. Yüzler görsel değil, [CustomPainter].
class MoodQuestionPage extends ConsumerStatefulWidget {
  const MoodQuestionPage({
    super.key,
    required this.onNext,
    required this.texts,
  });

  /// Seçilen cevapla çağrılır.
  final void Function(MoodAnswer answer) onNext;

  final MoodQuestionTexts texts;

  @override
  ConsumerState<MoodQuestionPage> createState() => _MoodQuestionPageState();
}

class _MoodQuestionPageState extends ConsumerState<MoodQuestionPage> {
  MoodAnswer? _answer;

  void _pick(MoodAnswer a) {
    if (_answer == a) return;
    setState(() => _answer = a);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.texts;
    final answer = _answer;
    final instant = reduceMotion(context);
    return _FillScroll(
      children: [
        const SizedBox(height: 8),
        _QuestionTitle(t.title).enterUp(context, index: 0),
        const SizedBox(height: 36),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, m) in MoodAnswer.values.indexed)
              Expanded(
                child: _MoodFaceButton(
                  mood: m,
                  label: t.labels[m] ?? '',
                  selected: answer == m,
                  dimmed: answer != null && answer != m,
                  onTap: () => _pick(m),
                ).enterUp(context, index: 1 + i),
              ),
          ],
        ),
        const SizedBox(height: 24),
        // Teselli baloncuğu: seçim yokken görünmez; cevap değişince metin
        // çapraz solarak yenilenir. Hareket azaltmada anında.
        AnimatedSwitcher(
          duration: instant ? Duration.zero : const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: answer == null
              ? const SizedBox.shrink()
              : _ComfortBubble(
                  key: ValueKey(answer),
                  text: t.comforts[answer] ?? '',
                  // Kuyruk seçili yüzün altında: üç eşit sütunun merkezleri
                  // -2/3, 0, +2/3 hizasında.
                  tailAlign: -2 / 3 + (2 / 3) * answer.index,
                ),
        ).reveal(context, visible: answer != null),
        const Spacer(),
        const SizedBox(height: 24),
        _InkPillButton(
          label: t.next,
          onTap: answer == null ? null : () => widget.onNext(answer),
        ).enterUp(context, index: 5),
      ],
    );
  }
}

/// Tek seçimli liste sorusunun bir satırı.
class ChoiceOption {
  const ChoiceOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Tek seçimli liste sorusu.
///
/// Satırlar beyaz kart; seçilen marka yeşiliyle dolar. Seçim yapılmadan
/// "Devam" sönük kalır.
class ChoiceQuestionPage extends ConsumerStatefulWidget {
  const ChoiceQuestionPage({
    super.key,
    required this.title,
    required this.options,
    required this.onNext,
    required this.nextLabel,
  });

  final String title;
  final List<ChoiceOption> options;

  /// Seçilen seçeneğin [ChoiceOption.id]'siyle çağrılır.
  final void Function(String selectedId) onNext;

  /// Devam düğmesi metni (RS'den).
  final String nextLabel;

  @override
  ConsumerState<ChoiceQuestionPage> createState() => _ChoiceQuestionPageState();
}

class _ChoiceQuestionPageState extends ConsumerState<ChoiceQuestionPage> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return _FillScroll(
      children: [
        const SizedBox(height: 8),
        _QuestionTitle(widget.title).enterUp(context, index: 0),
        const SizedBox(height: 28),
        for (final (i, o) in widget.options.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _ChoiceRow(
            label: o.label,
            selected: selected == o.id,
            onTap: () => setState(() => _selected = o.id),
          ).enterUp(context, index: 1 + i),
        ],
        const Spacer(),
        const SizedBox(height: 24),
        _InkPillButton(
          label: widget.nextLabel,
          onTap: selected == null ? null : () => widget.onNext(selected),
        ).enterUp(context, index: 2 + widget.options.length),
      ],
    );
  }
}

// ── Parçalar ─────────────────────────────────────────────────────────────

/// Soru başlığı: sola yaslı display başlık, 36 px (dar ekranda 32).
class _QuestionTitle extends StatelessWidget {
  const _QuestionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width - 40 < 310;
    final size = narrow ? 32.0 : 36.0;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'InterDisplay',
        fontWeight: FontWeight.w900,
        fontSize: size,
        height: 1.0,
        letterSpacing: -1.5 * size / 36,
        color: Poster.ink,
      ),
    );
  }
}

/// İçerik ekrana sığmazsa kayar; sığarsa [Spacer] düğmeyi alta iter.
class _FillScroll extends StatelessWidget {
  const _FillScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bir yüz + altındaki etiket. Seçilince 1.12'ye büyür ve yeşile döner,
/// başka seçim varken solar. Ölçek/renk geçişleri hareket azaltmada anında.
class _MoodFaceButton extends StatelessWidget {
  const _MoodFaceButton({
    required this.mood,
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final MoodAnswer mood;
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  static const _d = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final d = reduceMotion(context) ? Duration.zero : _d;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          duration: d,
          opacity: dimmed ? 0.4 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: d,
                curve: Curves.easeOutBack,
                scale: selected ? 1.12 : 1,
                child: TweenAnimationBuilder<double>(
                  duration: d,
                  curve: Curves.easeOut,
                  tween: Tween(end: selected ? 1 : 0),
                  builder: (context, t, _) => CustomPaint(
                    size: const Size.square(76),
                    painter: _FacePainter(mood: mood, t: t),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontFamily: 'InterDisplay',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.2,
                  color: selected ? Ex.brand : Poster.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yüz: dolu daire, iki göz, ruh hâline göre ağız. [t] 0 = pasif (açık gri
/// zemin, mürekkep çizgi), 1 = seçili (marka yeşili zemin, koyu çizgi).
class _FacePainter extends CustomPainter {
  const _FacePainter({required this.mood, required this.t});

  final MoodAnswer mood;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final fill = Color.lerp(const Color(0xFFEDECE8), Ex.brand, t)!;
    final ink = Color.lerp(Poster.ink, Ex.onBrand, t)!;
    canvas.drawCircle(c, r, Paint()..color = fill);

    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = ink;

    // Gözler.
    final eyeY = c.dy - r * 0.18;
    final eyeDx = r * 0.32;
    final eyeR = r * 0.085;
    canvas.drawCircle(Offset(c.dx - eyeDx, eyeY), eyeR, dot);
    canvas.drawCircle(Offset(c.dx + eyeDx, eyeY), eyeR, dot);

    // Ağız.
    final mouthW = r * 0.62;
    final mouthY = c.dy + r * 0.30;
    switch (mood) {
      case MoodAnswer.stressed:
        // Aşağı kavisli ağız + endişeli kaşlar (iç uçlar yukarıda).
        final rect = Rect.fromCenter(
            center: Offset(c.dx, mouthY + r * 0.30), width: mouthW, height: r * 0.5);
        canvas.drawArc(rect, math.pi + 0.35, math.pi - 0.7, false, stroke);
        final browY = eyeY - r * 0.28;
        canvas.drawLine(Offset(c.dx - eyeDx - r * 0.14, browY + r * 0.06),
            Offset(c.dx - eyeDx + r * 0.12, browY - r * 0.05), stroke);
        canvas.drawLine(Offset(c.dx + eyeDx + r * 0.14, browY + r * 0.06),
            Offset(c.dx + eyeDx - r * 0.12, browY - r * 0.05), stroke);
      case MoodAnswer.unsure:
        // Düz, hafif eğik ağız.
        canvas.drawLine(Offset(c.dx - mouthW / 2, mouthY + r * 0.04),
            Offset(c.dx + mouthW / 2, mouthY - r * 0.04), stroke);
      case MoodAnswer.good:
        // Gülümseme.
        final rect = Rect.fromCenter(
            center: Offset(c.dx, mouthY - r * 0.22), width: mouthW, height: r * 0.6);
        canvas.drawArc(rect, 0.35, math.pi - 0.7, false, stroke);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.mood != mood || old.t != t;
}

/// Yeşil teselli baloncuğu: üstte küçük kuyruk, içinde koyu metin.
class _ComfortBubble extends StatelessWidget {
  const _ComfortBubble({
    super.key,
    required this.text,
    this.tailAlign = -1,
  });

  final String text;

  /// Kuyruğun yatay konumu (-1 sol, 0 orta, 1 sağ).
  final double tailAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment(tailAlign, 0),
          child: CustomPaint(
            size: const Size(18, 9),
            painter: _BubbleTailPainter(),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Ex.brand,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15.5,
                height: 1.4,
                color: Ex.onBrand,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Baloncuğun yukarı bakan üçgen kuyruğu.
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Ex.brand);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => false;
}

/// Liste satırı: beyaz kart, seçilince marka yeşili dolgu ve sağda onay.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 180);
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: d,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? Ex.brand : Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: selected ? Ex.brand : Poster.ink.withValues(alpha: 0.10),
          ),
          boxShadow: selected
              ? const []
              : [
                  BoxShadow(
                    color: Poster.ink.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: d,
                      style: TextStyle(
                        fontFamily: 'InterDisplay',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.25,
                        color: selected ? Ex.onBrand : Poster.ink,
                      ),
                      child: Text(label),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CheckDot(selected: selected, duration: d),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satır sonundaki onay: pasifken ince halka, seçilince koyu dolgu + tik.
class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.selected, required this.duration});

  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Ex.onBrand : Colors.transparent,
        border: Border.all(
          color: selected ? Ex.onBrand : Poster.ink.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: selected
          ? const CustomPaint(painter: _TickPainter(color: Ex.brand))
          : null,
    );
  }
}

/// Onay tiki — ikon fontuna bağlı kalmadan çizilir, her ölçekte keskin.
class _TickPainter extends CustomPainter {
  const _TickPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.72, h * 0.36);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}

/// Siyah hap düğme (akıştaki `_InkPillButton`'ın eşdeğeri; koordinatör
/// birleştirir). null onTap = sönük, dokunulamaz.
class _InkPillButton extends StatelessWidget {
  const _InkPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 180);
    return AnimatedContainer(
      duration: d,
      decoration: ShapeDecoration(
        color: onTap == null ? Poster.ink.withValues(alpha: 0.35) : Poster.ink,
        shape: const StadiumBorder(),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 15, 30, 15),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: Poster.paper,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
