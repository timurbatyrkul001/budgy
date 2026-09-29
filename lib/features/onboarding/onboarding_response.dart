import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/motion.dart';
import 'onboarding_palette.dart';

/// "En zor gelen ne?" cevabına karşılık gelen metinler; koordinatör RS'den
/// kurar. Anahtarlar `ChoiceOption.id` değerleridir.
class AnswerResponseTexts {
  const AnswerResponseTexts({
    required this.titles,
    required this.bodies,
    required this.next,
    this.fallbackId = 'other',
  });

  /// Cevap kimliği → afiş başlığı.
  final Map<String, String> titles;

  /// Cevap kimliği → iki-üç satırlık gövde.
  final Map<String, String> bodies;

  /// Devam düğmesi.
  final String next;

  /// Bilinmeyen kimlik gelirse bu kimliğin metnine düşülür ("başka" genel
  /// karşılaması). O da yoksa haritadaki ilk metin kullanılır — ekran asla
  /// boş kalmaz, hiç çökmez.
  final String fallbackId;

  String titleFor(String id) => _pick(titles, id);
  String bodyFor(String id) => _pick(bodies, id);

  String _pick(Map<String, String> m, String id) =>
      m[id] ?? m[fallbackId] ?? (m.isEmpty ? '' : m.values.first);
}

/// Cevaba karşılık sayfası.
///
/// Kullanıcı derdini seçti; burada Budgy'nin o derde hangi özelliğiyle cevap
/// verdiğini söylüyoruz. Referansın (Subbie) uydurma istatistik ekranlarının
/// yerine geçer: aynı psikolojik iş — "yalnız değilsin, yöntem bozuktu" —
/// kullanıcının kendi cevabıyla yapılır. Sade afiş: küçük marka işareti, dev
/// başlık, gövde, siyah hap.
class AnswerResponsePage extends ConsumerStatefulWidget {
  const AnswerResponsePage({
    super.key,
    required this.answerId,
    required this.texts,
    required this.onNext,
  });

  /// [ChoiceQuestionPage]'den gelen seçenek kimliği.
  final String answerId;

  final AnswerResponseTexts texts;

  final VoidCallback onNext;

  @override
  ConsumerState<AnswerResponsePage> createState() => _AnswerResponsePageState();
}

class _AnswerResponsePageState extends ConsumerState<AnswerResponsePage> {
  @override
  Widget build(BuildContext context) {
    final t = widget.texts;
    final id = widget.answerId;
    final width = MediaQuery.sizeOf(context).width - 40;
    return _FillScroll(
      children: [
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: _ReplyMark(),
        ).enterUp(context, index: 0),
        const SizedBox(height: 22),
        _PosterTitle(t.titleFor(id), maxWidth: width).enterUp(context, index: 1),
        const SizedBox(height: 18),
        _BodyText(t.bodyFor(id)).enterUp(context, index: 2),
        const Spacer(),
        const SizedBox(height: 24),
        _InkPillButton(label: t.next, onTap: widget.onNext)
            .enterUp(context, index: 3),
      ],
    );
  }
}

/// "Hazır" özetinin metinleri; koordinatör RS'den kurar. Sayı satırlarında
/// `{n}` yer tutucusu sayının yerini belirler (dil sırası serbest).
class SetupSummaryTexts {
  const SetupSummaryTexts({
    required this.title,
    required this.expenseLine,
    required this.incomeLine,
    required this.body,
    required this.empty,
    required this.next,
  });

  /// Afiş başlığı ("Hazır.").
  final String title;

  /// Gider satırı, `{n}` içerir ("{n} gider kategorisi").
  final String expenseLine;

  /// Gelir satırı, `{n}` içerir ("{n} gelir kaynağı").
  final String incomeLine;

  /// Sonraki adım cümlesi.
  final String body;

  /// İki sayı da sıfırsa (kullanıcı balonları atladı) sayılar yerine bu.
  final String empty;

  /// Devam düğmesi.
  final String next;
}

/// "Hazır" özeti sayfası.
///
/// Balon ekranlarından sonra gelir; kullanıcının seçtiklerini sayı olarak
/// geri gösterir ("7 gider kategorisi / 3 gelir kaynağı"). Sayılar 0'dan
/// hedefe kısa bir sayaçla (400 ms) yükselir; hareket azaltmada anında.
/// Sıfır olan satır gizlenir; ikisi de sıfırsa [SetupSummaryTexts.empty]
/// gösterilir.
class SetupSummaryPage extends ConsumerStatefulWidget {
  const SetupSummaryPage({
    super.key,
    required this.expenseCount,
    required this.incomeCount,
    required this.texts,
    required this.onNext,
  });

  final int expenseCount;
  final int incomeCount;
  final SetupSummaryTexts texts;
  final VoidCallback onNext;

  @override
  ConsumerState<SetupSummaryPage> createState() => _SetupSummaryPageState();
}

class _SetupSummaryPageState extends ConsumerState<SetupSummaryPage> {
  @override
  Widget build(BuildContext context) {
    final t = widget.texts;
    final width = MediaQuery.sizeOf(context).width - 40;
    final expenses = widget.expenseCount;
    final incomes = widget.incomeCount;
    final nothing = expenses <= 0 && incomes <= 0;
    var index = 0;
    return _FillScroll(
      children: [
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: _ReplyMark(),
        ).enterUp(context, index: index++),
        const SizedBox(height: 22),
        _PosterTitle(t.title, maxWidth: width).enterUp(context, index: index++),
        const SizedBox(height: 22),
        if (nothing)
          _BodyText(t.empty).enterUp(context, index: index++)
        else ...[
          if (expenses > 0)
            _CountLine(template: t.expenseLine, value: expenses)
                .enterUp(context, index: index++),
          if (expenses > 0 && incomes > 0) const SizedBox(height: 14),
          if (incomes > 0)
            _CountLine(template: t.incomeLine, value: incomes)
                .enterUp(context, index: index++),
          const SizedBox(height: 22),
          _BodyText(t.body).enterUp(context, index: index++),
        ],
        const Spacer(),
        const SizedBox(height: 24),
        _InkPillButton(label: t.next, onTap: widget.onNext)
            .enterUp(context, index: index++),
      ],
    );
  }
}

// ── Parçalar ─────────────────────────────────────────────────────────────

/// Sayı satırı: `{n}` yerine büyük display rakam, kalanı gövde puntosunda.
/// Rakam 0'dan hedefe 400 ms'de sayar; hareket azaltmada doğrudan hedef.
class _CountLine extends StatelessWidget {
  const _CountLine({required this.template, required this.value});

  final String template;
  final int value;

  static const _placeholder = '{n}';

  @override
  Widget build(BuildContext context) {
    final i = template.indexOf(_placeholder);
    final prefix = i < 0 ? '' : template.substring(0, i);
    final suffix = i < 0 ? template : template.substring(i + _placeholder.length);
    final instant = reduceMotion(context);
    const labelStyle = TextStyle(
      fontFamily: 'InterDisplay',
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.2,
      color: Poster.ink,
    );
    const numberStyle = TextStyle(
      fontFamily: 'InterDisplay',
      fontWeight: FontWeight.w900,
      fontSize: 44,
      height: 1.0,
      letterSpacing: -1.5,
      color: Ex.brand,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: instant ? value.toDouble() : 0, end: value.toDouble()),
      duration: instant ? Duration.zero : const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, n, _) {
        // Semantik değeri hedef sayı; ara değerler yalnız görsel.
        return Semantics(
          label: template.replaceAll(_placeholder, '$value'),
          excludeSemantics: true,
          // Rakam WidgetSpan ile dikey ortalanır: sayı sonda gelen dilde
          // (RU "Категорий расходов: 7") taban hizası tepeden sarkıyordu.
          child: Text.rich(
            TextSpan(
              children: [
                if (prefix.isNotEmpty) TextSpan(text: prefix, style: labelStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Text('${n.round()}', style: numberStyle),
                ),
                if (suffix.isNotEmpty) TextSpan(text: suffix, style: labelStyle),
              ],
            ),
            style: labelStyle,
          ),
        );
      },
    );
  }
}

/// Afiş başlığı: display w900, 36 px (dar ekranda 32). En uzun sözcük satıra
/// sığmıyorsa punto o sözcük sığana kadar küçülür (RU sözcükleri uzun).
class _PosterTitle extends StatelessWidget {
  const _PosterTitle(this.text, {required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final base = maxWidth < 310 ? 32.0 : 36.0;
    TextStyle styleAt(double s) => TextStyle(
          fontFamily: 'InterDisplay',
          fontWeight: FontWeight.w900,
          fontSize: s,
          height: 1.0,
          letterSpacing: -1.5 * (s / 36),
          color: Poster.ink,
        );
    var size = base;
    if (text.trim().isNotEmpty) {
      final longest = text
          .split(RegExp(r'\s+'))
          .reduce((a, b) => a.length >= b.length ? a : b);
      final painter = TextPainter(
        text: TextSpan(text: longest, style: styleAt(base)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > maxWidth) {
        size = (base * maxWidth / painter.width).floorToDouble();
      }
      painter.dispose();
    }
    return Text(text, style: styleAt(size));
  }
}

/// Gövde metni: Inter, yumuşak mürekkep.
class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        height: 1.45,
        color: Poster.inkSoft,
      ),
    );
  }
}

/// Küçük marka işareti: yanıt baloncuğu siluetinde marka yeşili leke.
/// Görsel değil, [CustomPainter] — "Budgy cevap veriyor" hissi için, süs
/// olmaktan öteye gitmez.
class _ReplyMark extends StatelessWidget {
  const _ReplyMark();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(44, 40),
      painter: _ReplyMarkPainter(),
    );
  }
}

class _ReplyMarkPainter extends CustomPainter {
  const _ReplyMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyH = h * 0.78;
    final fill = Paint()..color = Ex.brand;
    // Baloncuk gövdesi.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, bodyH),
      Radius.circular(bodyH * 0.5),
    );
    canvas.drawRRect(body, fill);
    // Sol altta kısa kuyruk.
    final tail = Path()
      ..moveTo(w * 0.18, bodyH - 2)
      ..lineTo(w * 0.12, h)
      ..lineTo(w * 0.40, bodyH - 2)
      ..close();
    canvas.drawPath(tail, fill);
    // İçeride üç mürekkep nokta — "yazıyor" izi.
    final dot = Paint()..color = Ex.onBrand;
    final r = bodyH * 0.09;
    final cy = bodyH / 2;
    for (final f in [0.30, 0.50, 0.70]) {
      canvas.drawCircle(Offset(w * f, cy), r, dot);
    }
  }

  @override
  bool shouldRepaint(_ReplyMarkPainter old) => false;
}

/// İçerik ekrana sığmazsa kayar; sığarsa [Spacer] düğmeyi alta iter
/// (`onboarding_questions.dart`'taki kopyanın eşi; koordinatör birleştirir).
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

/// Siyah hap düğme (akıştaki `_InkPillButton`'ın eşdeğeri; koordinatör
/// birleştirir).
class _InkPillButton extends StatelessWidget {
  const _InkPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Poster.ink,
        shape: StadiumBorder(),
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
