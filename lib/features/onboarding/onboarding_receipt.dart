import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_catalog.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/redesign_l10n.dart';
import 'onboarding_bubbles.dart' show BubbleItem;
import 'onboarding_palette.dart';

// Fişin toplam satırı `rs.categories` etiketini sağa dayalı tabular sayıyla
// kullanıyor ("Kategoriler ........ 3"); ayrı bir şablon metnine gerek yok.

/// Onboarding'in "fiş yazdırma" seçim sayfası — balon bulutunun alternatifi.
///
/// Budgy'nin dili defter/fiş/kayıt üzerine: "İlk günün defterde", "Defterin
/// seni bekliyor". Bu ekran da oradan besleniyor: üstte sıkışık bir kategori
/// ızgarası, altta bir yazarkasa fişi. Dokunulan her kategori fişe bir satır
/// olarak "basılır", fiş aşağı doğru uzar; tekrar dokununca satır silinir.
///
/// Dışa açık imza [BubblePickerPage] ile birebir aynı: akışta tek satır
/// değiştirilerek takas edilir, beğenilmezse geri dönülür. Balon verisi
/// ([BubbleItem], `expenseBubbles`, `incomeBubbles`) o dosyadan gelir.
class ReceiptPickerPage extends ConsumerStatefulWidget {
  const ReceiptPickerPage({
    super.key,
    required this.title,
    required this.items,
    required this.accent,
    required this.onNext,
    this.initialSelected = const <String>{},
  });

  /// "Nelere para harcıyorsun?" gibi yönerge başlığı.
  final String title;

  /// Izgaradaki kategoriler; sıra ızgara sırasıdır.
  final List<BubbleItem> items;

  /// Seçili hücrenin dolgusu ve fişteki vurgu (onay işareti, toplam).
  final Color accent;

  /// Seçili kimliklerle ilerle (boş küme = atladı).
  final void Function(Set<String> selectedIds) onNext;

  /// Geri gelindiğinde önceki seçimi korumak için.
  final Set<String> initialSelected;

  @override
  ConsumerState<ReceiptPickerPage> createState() => _ReceiptPickerPageState();
}

class _ReceiptPickerPageState extends ConsumerState<ReceiptPickerPage> {
  /// Seçim SIRASI önemli: fişe basıldığı sırayla listelenir, Set yetmez.
  /// Başlangıç seçimi ızgara sırasına göre dizilir.
  late final List<String> _lines = [
    for (final item in widget.items)
      if (widget.initialSelected.contains(item.id)) item.id,
  ];

  /// Dokunarak eklenen satırlar — yalnız bunlar kayarak girer; geri
  /// gelindiğinde korunan başlangıç satırları animasyonsuz durur.
  final _fresh = <String>{};

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_lines.remove(id)) {
        _lines.add(id);
        _fresh.add(id);
      } else {
        _fresh.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final size = MediaQuery.sizeOf(context);
    final width = size.width - 40;
    // Fiş yuvasının yüksekliği: ekranın ~%28'i, 150–200 arası. Küçük
    // telefonda (568) ızgaraya yer kalsın, büyük ekranda fiş şerit gibi
    // uzayıp gitmesin.
    final slotHeight = (size.height * 0.28).clamp(150.0, 200.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _ReceiptTitle(widget.title, maxWidth: width),
        ),
        const SizedBox(height: 12),
        // Izgara kalan yüksekliği alır; küçük ekranda sığmazsa kendi içinde
        // kaydırılır — hücre asla ekran dışına taşmaz.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _CategoryGrid(
              items: widget.items,
              selected: _lines,
              accent: widget.accent,
              onTap: _toggle,
            ),
          ),
        ),
        // Fiş yuvası: sabit yükseklikte bir alan. Fiş, yuvanın ÜSTÜNDEN
        // çıkar ve satır eklendikçe aşağı uzar; yuva dolunca daha fazla
        // uzamaz, içi kaydırılır. Kaydırma alta çapalıdır (reverse), yani
        // yeni basılan satır her zaman görünür, eski satırlar ve "BUDGY"
        // başlığı yazıcıdan çıkan kâğıt gibi yukarı akar. Böylece fiş ne
        // ızgarayı sıkıştırır ne de düğmeyi iter.
        SizedBox(
          height: slotHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: _Receipt(
                items: widget.items,
                lines: _lines,
                fresh: _fresh,
                accent: widget.accent,
                totalLabel: rs.categories,
                emptyLabel: rs.receiptEmpty,
                maxHeight: slotHeight,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Center(
            child: _InkPill(
              label: _nextLabel(rs, _lines.length),
              onTap: () => widget.onNext(Set.unmodifiable(_lines.toSet())),
            ),
          ),
        ),
      ],
    );
  }
}

/// Düğme metni seçim sayısına göre. Sıfır seçimde de basılabilir —
/// kullanıcı atlayabilmeli.
String _nextLabel(RS rs, int count) => count == 0
    ? rs.bubblesContinue
    : tpl(rs.bubblesContinueTpl, {'n': '$count'});

/// Akıştaki `_Title` ölçüsünün eşi: InterDisplay w900, 36 px (dar ekranda
/// 32), en uzun kelime sığmazsa punto düşer. Kaynak `onboarding_flow.dart`'ta
/// yerel; koordinatör birleştirdiğinde bu kopya kalkabilir.
class _ReceiptTitle extends StatelessWidget {
  const _ReceiptTitle(this.text, {required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final narrow = maxWidth < 310;
    final base = narrow ? 32.0 : 36.0;
    TextStyle styleAt(double s) => TextStyle(
      fontFamily: 'InterDisplay',
      fontWeight: FontWeight.w900,
      fontSize: s,
      height: 0.98,
      letterSpacing: -1.5 * (s / 36),
      color: Poster.ink,
    );
    var fitted = base;
    final longest = text
        .split(RegExp(r'\s+'))
        .reduce((a, b) => a.length >= b.length ? a : b);
    final painter = TextPainter(
      text: TextSpan(text: longest, style: styleAt(fitted)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    if (painter.width > maxWidth) {
      fitted = (fitted * maxWidth / painter.width).floorToDouble();
    }
    painter.dispose();
    return Text(
      text,
      style: styleAt(fitted),
    ).dropIn(context, Duration.zero, dy: -8);
  }
}

/// Akıştaki `_InkPillButton`'ın eşi: içeriğe göre daralan siyah hap.
class _InkPill extends StatelessWidget {
  const _InkPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Poster.ink,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 15, 30, 15),
          child: Text(
            label,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Kategori ızgarası
// ---------------------------------------------------------------------------

/// Sıkışık ızgara: emoji + kısa ad hücreleri. Etiket uzunlukları dile göre
/// çok değişiyor (RU'da "Общественный транспорт"), sabit sütunlu GridView
/// kısa hücrede metni keserdi; Wrap her hücreyi içeriğine göre boyutlar ve
/// satırı doldurur.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.items,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final List<BubbleItem> items;
  final List<String> selected;
  final Color accent;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, item) in items.indexed)
          _Cell(
            key: ValueKey('cell-${item.id}'),
            item: item,
            selected: selected.contains(item.id),
            accent: accent,
            onTap: () => onTap(item.id),
          ).enterPop(context, index: i ~/ 4),
      ],
    );
  }
}

/// Tek hücre: dokununca vurgu rengine döner. Renk geçişi kısa — ekrandaki
/// tek anlamlı hareket fişe giren satırdır, hücre yalnız durum bildirir.
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final BubbleItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    // Koyu vurgu → açık yazı; açık bir vurgu verilirse mürekkep kalır.
    final fg = selected
        ? (accent.computeLuminance() < 0.5 ? Poster.paper : Poster.ink)
        : Poster.ink;
    final emoji = catalogItem(item.id)?.emoji ?? '';
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: d,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(9, 7, 11, 7),
          decoration: BoxDecoration(
            color: selected ? accent : Poster.ink.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent : Poster.ink.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji sabit boy: seçimde yazı rengi değişir, emoji değişmez.
              // Emoji için ayrı Text — Semantics'te etiketle karışmasın diye
              // ExcludeSemantics.
              ExcludeSemantics(
                child: Text(emoji, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 6),
              // En uzun etiket (ru "Общественный транспорт") 320 dp'de
              // hücreyi ekrandan taşırıyordu. Flexible + scaleDown:
              // yalnızca sığmayan etiket bir tık küçülür, kırpılmaz;
              // diğerleri aynı puntoda kalır.
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: TextStyle(
                    fontFamily: 'InterDisplay',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.15,
                    letterSpacing: -0.2,
                    color: fg,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(item.label, maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fiş
// ---------------------------------------------------------------------------

/// Fiş yazısı: projede tek aralıklı font yok; Inter'e harf aralığı ve
/// tabular rakamlarla yazarkasa hissi veriliyor.
TextStyle _receiptStyle({
  double size = 13,
  Color color = Poster.ink,
  double spacing = 0.8,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  height: 1.2,
  letterSpacing: spacing,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Tırtıklı alt kenarın diş yüksekliği.
const _kTeeth = 6.0;

/// Yazarkasa fişi: "BUDGY" başlığı, satırlar, toplam, tırtıklı alt kenar.
///
/// Yükseklik içeriğe göre büyür, [maxHeight]'i geçince başlık + satırlar
/// kaydırılır; toplam ve tırtık hep görünür kalır.
class _Receipt extends StatelessWidget {
  const _Receipt({
    required this.items,
    required this.lines,
    required this.fresh,
    required this.accent,
    required this.totalLabel,
    required this.emptyLabel,
    required this.maxHeight,
  });

  final List<BubbleItem> items;
  final List<String> lines;
  final Set<String> fresh;
  final Color accent;
  final String totalLabel;

  /// Fiş boşken kâğıdın ortasında duran yönerge.
  final String emptyLabel;
  final double maxHeight;

  BubbleItem _item(String id) => items.firstWhere((i) => i.id == id);

  @override
  Widget build(BuildContext context) {
    final rule = Poster.ink.withValues(alpha: 0.18);
    return Semantics(
      container: true,
      label: '$totalLabel ${lines.length}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: CustomPaint(
          painter: _ReceiptPaperPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, _kTeeth + 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Başlık + satırlar: alta çapalı kaydırma — yeni satır hep
                // görünür, taşan başlık yukarıdan çıkar.
                Flexible(
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'BUDGY',
                            style: _receiptStyle(size: 12, spacing: 3),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _DashedRule(color: rule),
                        const SizedBox(height: 4),
                        if (lines.isEmpty)
                          // Boş fiş: ne yapılacağını söyleyen soluk yönerge.
                          // Nokta dizisi hoş duruyordu ama hiçbir şey
                          // anlatmıyordu.
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Text(
                              emptyLabel,
                              textAlign: TextAlign.center,
                              style: _receiptStyle(color: Poster.inkFaint),
                            ),
                          ),
                        for (final (i, id) in lines.indexed)
                          _ReceiptLine(
                            key: ValueKey('line-$id'),
                            index: i + 1,
                            item: _item(id),
                            accent: accent,
                            animate: fresh.contains(id),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _DashedRule(color: rule),
                Padding(
                  key: const Key('receipt-total'),
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                  child: Row(
                    children: [
                      // Büyük harfe çevrilmiyor: Dart'ın toUpperCase'i
                      // Türkçe "i"yi noktasız yapar (KATEGORILER).
                      Expanded(
                        child: Text(
                          totalLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _receiptStyle(size: 12, spacing: 1.2),
                        ),
                      ),
                      Text(
                        '${lines.length}',
                        style: _receiptStyle(
                          size: 15,
                          color: lines.isEmpty ? Poster.inkFaint : accent,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fişteki tek satır: sıra numarası, emoji, ad, noktalı dolgu, onay.
/// [animate] true ise 220 ms'de açılarak (yükseklik + solma + hafif yukarı
/// kayma) girer — "yazıcıdan çıkma". Hareket azaltmada anında.
class _ReceiptLine extends StatefulWidget {
  const _ReceiptLine({
    super.key,
    required this.index,
    required this.item,
    required this.accent,
    required this.animate,
  });

  final int index;
  final BubbleItem item;
  final Color accent;
  final bool animate;

  @override
  State<_ReceiptLine> createState() => _ReceiptLineState();
}

class _ReceiptLineState extends State<_ReceiptLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.animate ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // İlk kurulumda bir kez: hareket azaltma açıksa son kareye atla.
    if (_c.value == 0 && !_c.isAnimating) {
      if (reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = catalogItem(widget.item.id)?.emoji ?? '';
    // Satır: "01  🛒 Market ........ ✓". Ad ihtiyacı kadar yer alır, noktalı
    // dolgu artanı doldurur; Row'da iki esnek çocuk yeri paylaşacağı için
    // (ad yarıya kırpılırdı) adın üst sınırı LayoutBuilder ile verilir —
    // satır genişliği eksi sabit parçalar ve en az 18 px dolgu.
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, box) {
          const fixed = 22 + 8 + 20 + 6 + 6 + 18 + 6 + 14;
          final labelMax = (box.maxWidth - fixed).clamp(40.0, double.infinity);
          return Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  widget.index.toString().padLeft(2, '0'),
                  style: _receiptStyle(color: Poster.inkFaint),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 20,
                child: ExcludeSemantics(
                  child: Text(
                    emoji,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: labelMax),
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _receiptStyle(),
                ),
              ),
              const SizedBox(width: 6),
              // Noktalı dolgu: yazarkasa fişindeki ad ........ tutar çizgisi.
              Expanded(
                child: _DashedRule(color: Poster.ink.withValues(alpha: 0.18)),
              ),
              const SizedBox(width: 6),
              Text('✓', style: _receiptStyle(color: widget.accent, spacing: 0)),
            ],
          );
        },
      ),
    );
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return SizeTransition(
      sizeFactor: curve,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(curve),
          child: row,
        ),
      ),
    );
  }
}

/// Kesik çizgi (fişteki ayırıcı ve noktalı dolgu).
class _DashedRule extends StatelessWidget {
  const _DashedRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashPainter(color)),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 3.0, gap = 3.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + dash, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Fiş kâğıdı: düz üst kenar, testere dişli alt kenar, hafif gölge.
/// Kâğıt zeminin üstünde beyaz — termal fiş kâğıdı çevresinden daha beyazdır;
/// [Colors.white] Flutter'ın sabiti, yeni bir marka rengi değil.
class _ReceiptPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tooth = 8.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - _kTeeth);
    // Sağdan sola testere dişi: her diş [tooth] geniş, [_kTeeth] derin.
    var x = size.width;
    var up = true;
    while (x > 0) {
      x -= tooth / 2;
      path.lineTo(
        x.clamp(0, size.width),
        up ? size.height : size.height - _kTeeth,
      );
      up = !up;
    }
    path
      ..lineTo(0, size.height - _kTeeth)
      ..close();
    canvas.drawShadow(path, Poster.ink.withValues(alpha: 0.35), 6, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Poster.ink.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_ReceiptPaperPainter old) => false;
}
