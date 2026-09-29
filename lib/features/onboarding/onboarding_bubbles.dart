import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_catalog.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import 'onboarding_palette.dart';

/// Onboarding'in "balon bulutu" seçim sayfası.
///
/// Referans (Subbie): ekranı dolduran yuvarlak balonlar, dokununca büyüyüp
/// vurgu rengine dönüyor. Süs değil — seçilen balonlar kullanıcının
/// kategorileri oluyor; 42 hazır kategoriyi önüne dökmek yerine "hangileri
/// sende var?" diye sorup listeyi ona kurduruyoruz. Balon kimlikleri
/// [kCategoryCatalog] anahtarlarıdır; koordinatör `onNext`'ten gelen kümeyi
/// zarfa çevirir.
///
/// Beyaz afiş akışının parçası: [Poster] zemini + mürekkep, vurgu rengi
/// dışarıdan gelir (gider sayfası kırmızımsı, gelir sayfası yeşil).
class BubblePickerPage extends ConsumerStatefulWidget {
  const BubblePickerPage({
    super.key,
    required this.title,
    required this.items,
    required this.accent,
    required this.onNext,
    this.initialSelected = const <String>{},
  });

  /// "Giderlerinden bazılarını seç" gibi yönerge başlığı.
  final String title;

  /// Gösterilecek balonlar; sıra önem sırasıdır (baştakiler merkeze yakın
  /// ve büyük çizilir).
  final List<BubbleItem> items;

  /// Seçili balonun dolgu rengi.
  final Color accent;

  /// Seçili balon kimlikleriyle ilerle (boş küme = atladı).
  final void Function(Set<String> selectedIds) onNext;

  /// Geri gelindiğinde önceki seçimi korumak için.
  final Set<String> initialSelected;

  @override
  ConsumerState<BubblePickerPage> createState() => _BubblePickerPageState();
}

/// Balon verisi: kimlik (katalog anahtarı) + ekranda görünen etiket.
class BubbleItem {
  const BubbleItem({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is BubbleItem && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Gider balonları için katalog anahtarları — önem sırasıyla (ilk olanlar
/// merkeze yakın ve büyük). Yaygın harcamalar; nadir olanlar (vergi, banka
/// ücreti, bulut, oyun…) hızlı girişteki tam katalogda kalır.
const kExpenseBubbleKeys = <String>[
  'groceries',
  'rent',
  'restaurants',
  'utilities',
  'publicTransport',
  'clothes',
  'coffee',
  'internet',
  'taxi',
  'entertainment',
  'pharmacy',
  'fuel',
  'streaming',
  'personalCare',
  'sport',
  'travel',
  'gifts',
  'education',
  'loans',
  'insurance',
  'music',
  'pets',
];

/// Gider balonları — [kCategoryCatalog]'dan, [str]'nin dilinde.
List<BubbleItem> expenseBubbles(Strings str) => [
      for (final key in kExpenseBubbleKeys)
        if (catalogItem(key) case final item?)
          BubbleItem(id: key, label: item.name(str.localeCode)),
    ];

/// Gelir balonları — kataloğun gelir bölümünün tamamı, "Diğer gelir" hariç
/// (o seçilecek bir kaynak değil, çöp kutusu). Kataloğa yeni gelir maddesi
/// eklendiğinde (ikramiye, bahşiş, temettü, kira geliri…) burada kendiliğinden
/// belirir.
List<BubbleItem> incomeBubbles(Strings str) => [
      for (final item in kCategoryCatalog.last.items)
        if (item.key != 'otherIncome')
          BubbleItem(id: item.key, label: item.name(str.localeCode)),
    ];

class _BubblePickerPageState extends ConsumerState<BubblePickerPage> {
  late final Set<String> _selected = {...widget.initialSelected};

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(strProvider).localeCode;
    final width = MediaQuery.sizeOf(context).width - 40;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _BubbleTitle(widget.title, maxWidth: width),
        ),
        const SizedBox(height: 8),
        // Balon bulutu kalan tüm yüksekliği alır; kaydırma yok — sığmazsa
        // yerleşim kendini küçültür.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: _BubbleCloud(
              items: widget.items,
              selected: _selected,
              accent: widget.accent,
              onTap: _toggle,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Center(
            child: _InkPill(
              label: _nextLabel(locale, _selected.length),
              onTap: () => widget.onNext(Set.unmodifiable(_selected)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Düğme metni seçim sayısına göre.
///
/// GEÇİCİ: bu metinler `RS`'ye taşınacak (koordinatör ekleyecek); o zamana
/// kadar burada, üç dilde. Sıfır seçimde de basılabilir — kullanıcı
/// atlayabilmeli.
String _nextLabel(String locale, int count) {
  if (count == 0) {
    return switch (locale) {
      'tr' => 'Devam et',
      'ru' => 'Продолжить',
      _ => 'Continue',
    };
  }
  return switch (locale) {
    'tr' => '$count tanesiyle devam et',
    'ru' => 'Выбрано $count · Продолжить',
    _ => 'Continue with $count',
  };
}

/// Akıştaki `_Title` ölçüsünün eşi: InterDisplay w900, 36 px (dar ekranda
/// 32), en uzun kelime sığmazsa punto düşer. Kaynak `onboarding_flow.dart`'ta
/// yerel; koordinatör birleştirdiğinde bu kopya kalkabilir.
class _BubbleTitle extends StatelessWidget {
  const _BubbleTitle(this.text, {required this.maxWidth});

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
    return Text(text, style: styleAt(fitted))
        .dropIn(context, Duration.zero, dy: -8);
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
// Balon bulutu
// ---------------------------------------------------------------------------

/// Balon etiketinin temel puntosu; yerleşim sığmazsa [_PlacedBubble.scale]
/// ile birlikte küçülür (metin genişliği puntoyla doğrusal, balon her
/// ölçekte etiketi sarar).
const _kLabelSize = 14.0;

/// Balon çevresindeki metin payı ve iki balon arasındaki boşluk.
const _kPad = 9.0;
const _kGap = 5.0;

/// Balonlar sığarsa en fazla bu kadar büyütülür (koca ekranda cüce balon
/// olmasın). Alt sınır yok: sığdırma her zaman kazanır — kaydırma olmadığı
/// için taşan balon dokunulamaz balondur.
const _kMaxScale = 1.25;

/// Bağlayıcı olmayan eksende konumların en fazla ne kadar açılacağı.
const _kMaxStretch = 1.4;

/// Seçili balonun büyüme oranı.
const _kSelectedScale = 1.14;

/// Yerleşmiş balon: merkez, yarıçap ve yerleşimin ortak ölçeği.
class _PlacedBubble {
  const _PlacedBubble(this.index, this.item, this.center, this.radius, this.scale);

  /// Listedeki sıra — giriş animasyonunun gecikme adımı.
  final int index;
  final BubbleItem item;
  final Offset center;
  final double radius;
  final double scale;
}

/// Balonları dağınık ama çakışmadan yerleştirir ve dokunmayı iletir.
///
/// Fizik motoru yok: deterministik yerleşim — altın açı sarmalıyla ilk
/// konumlar, sonra çakışmaları iten kısa bir gevşetme döngüsü, sonunda
/// kutuya sığdırma ölçeği. Aynı liste + aynı kutu → aynı görüntü.
class _BubbleCloud extends StatelessWidget {
  const _BubbleCloud({
    required this.items,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final List<BubbleItem> items;
  final Set<String> selected;
  final Color accent;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedHeight || !box.hasBoundedWidth || items.isEmpty) {
          return const SizedBox.shrink();
        }
        final placed = _layoutBubbles(items, box.biggest, textScaler);
        // Seçili balonlar büyüdüğü için komşularının üstüne biner; üstte
        // çizilsinler diye Stack'te sona alınır (ölçek animasyonu Positioned
        // anahtarıyla korunur).
        final ordered = [
          for (final p in placed)
            if (!selected.contains(p.item.id)) p,
          for (final p in placed)
            if (selected.contains(p.item.id)) p,
        ];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final p in ordered)
              Positioned(
                key: ValueKey(p.item.id),
                left: p.center.dx - p.radius,
                top: p.center.dy - p.radius,
                width: p.radius * 2,
                height: p.radius * 2,
                child: _stagger(
                  context,
                  _Bubble(
                    label: p.item.label,
                    fontSize: _kLabelSize * p.scale,
                    selected: selected.contains(p.item.id),
                    accent: accent,
                    onTap: () => onTap(p.item.id),
                  ),
                  p.index,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Kademeli giriş: merkezden dışa doğru 12 ms adımla belirir; toplam
  /// gecikme ~250 ms'i aşmaz. Hareket azaltmada tümü anında görünür.
  static Widget _stagger(BuildContext context, Widget child, int index) {
    if (reduceMotion(context)) return child;
    const d = Duration(milliseconds: 260);
    return child
        .animate(delay: Duration(milliseconds: 12 * math.min(index, 20)))
        .fadeIn(duration: d, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
          duration: d,
          curve: Curves.easeOutBack,
        );
  }
}

/// Yerleşim önbelleği: aynı liste, kutu ve metin ölçeği için aynı sonuç —
/// her setState'te (dokunma) yeniden hesap yapılmaz.
final _layoutCache = <_LayoutKey, List<_PlacedBubble>>{};

class _LayoutKey {
  const _LayoutKey(this.items, this.size, this.textScale);

  final List<BubbleItem> items;
  final Size size;
  final double textScale;

  @override
  bool operator ==(Object other) =>
      other is _LayoutKey &&
      other.size == size &&
      other.textScale == textScale &&
      other.items.length == items.length &&
      _sameItems(other.items, items);

  static bool _sameItems(List<BubbleItem> a, List<BubbleItem> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(size, textScale, Object.hashAll(items));
}

List<_PlacedBubble> _layoutBubbles(
    List<BubbleItem> items, Size box, TextScaler textScaler) {
  final key = _LayoutKey(items, box, textScaler.scale(10));
  final cached = _layoutCache[key];
  if (cached != null) return cached;
  if (_layoutCache.length > 12) _layoutCache.clear();

  final n = items.length;

  // 1) Ölçüm: etiket 1.0 ölçekte kaç piksel? Uzun etiketler iki satıra
  //    kırılır (en uzun kelimenin altına inmeden), balon yarıçapı bu
  //    dikdörtgeni çevreleyen çemberden gelir.
  final radii = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final size = _measureLabel(items[i].label, _kLabelSize, textScaler);
    final r = math.sqrt(size.width * size.width / 4 + size.height * size.height / 4) + _kPad;
    // Önem sırası: baştakiler biraz daha iri (merkezde büyük, kenarda ufak).
    final weight = 1.0 + 0.22 * (1 - i / math.max(1, n - 1));
    radii[i] = math.max(28, r) * weight;
  }

  // 2) İlk konumlar: altın açı sarmalı. Kutunun en-boy oranına göre
  //    basıklaştırılmış ki bulut dikey telefona uysun.
  final aspect = box.width / box.height;
  final sx = math.sqrt(aspect);
  final sy = 1 / sx;
  final meanD = radii.fold(0.0, (a, r) => a + r * 2) / n;
  final pos = List<Offset>.filled(n, Offset.zero);
  const golden = 2.399963229728653;
  for (var i = 0; i < n; i++) {
    final ang = i * golden;
    final dist = meanD * 0.62 * math.sqrt(i.toDouble());
    pos[i] = Offset(math.cos(ang) * dist * sx, math.sin(ang) * dist * sy);
  }

  // 3) Gevşetme: çakışanlar birbirini iter, hepsi merkeze hafifçe çekilir
  //    (kutu oranıyla — dar kenar daha sıkı). Sonlara doğru çekim kalkar,
  //    böylece son kare çakışmasızdır.
  const iterations = 90;
  for (var it = 0; it < iterations; it++) {
    final pull = it < iterations * 0.7 ? 0.015 : 0.0;
    for (var i = 0; i < n; i++) {
      pos[i] = Offset(pos[i].dx * (1 - pull * sy), pos[i].dy * (1 - pull * sx));
    }
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final d = pos[j] - pos[i];
        var dist = d.distance;
        final minD = radii[i] + radii[j] + _kGap;
        if (dist >= minD) continue;
        Offset dir;
        if (dist < 0.001) {
          // Üst üste: deterministik bir yönde ayır.
          final a = (i * 7 + j * 13) * 0.61803;
          dir = Offset(math.cos(a), math.sin(a));
          dist = 0.001;
        } else {
          dir = d / dist;
        }
        final push = (minD - dist) / 2;
        pos[i] -= dir * push;
        pos[j] += dir * push;
      }
    }
  }

  // 4) Sığdırma: sınır kutusunu hesapla, kutuya oranla ölçekle, ortala.
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (var i = 0; i < n; i++) {
    minX = math.min(minX, pos[i].dx - radii[i]);
    maxX = math.max(maxX, pos[i].dx + radii[i]);
    minY = math.min(minY, pos[i].dy - radii[i]);
    maxY = math.max(maxY, pos[i].dy + radii[i]);
  }
  // Seçili balon %14 büyüyor; kenardaki balon kutudan taşmasın diye pay.
  final grow = radii.reduce(math.max) * (_kSelectedScale - 1);
  final bw = maxX - minX + grow * 2;
  final bh = maxY - minY + grow * 2;
  final scale = math.min(math.min(box.width / bw, box.height / bh), _kMaxScale);
  // Bulut yuvarlağa yakın çıkar, telefon kutusu ise dik: bağlayıcı olmayan
  // eksende konumlar (yarıçaplar değil) en fazla [_kMaxStretch] kadar
  // esnetilir. Mesafeler yalnız büyür — yeni çakışma doğmaz, bulut
  // "dağınık" görünüp boş alanı doldurur.
  final kx = math.min(box.width / (bw * scale), _kMaxStretch);
  final ky = math.min(box.height / (bh * scale), _kMaxStretch);
  final cx = (minX + maxX) / 2;
  final cy = (minY + maxY) / 2;
  final origin = Offset(box.width / 2, box.height / 2);

  final result = List<_PlacedBubble>.generate(n, (i) {
    final c = origin +
        Offset((pos[i].dx - cx) * scale * kx, (pos[i].dy - cy) * scale * ky);
    return _PlacedBubble(i, items[i], c, radii[i] * scale, scale);
  }, growable: false);
  _layoutCache[key] = result;
  return result;
}

/// Etiketin çizim boyutu: tek satıra sığmıyorsa en uzun kelimeden dar
/// olmayacak şekilde iki satıra kırılır.
Size _measureLabel(String label, double fontSize, TextScaler textScaler) {
  final style = _labelStyle(fontSize, Poster.ink);
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    textScaler: textScaler,
    maxLines: 2,
  )..layout();
  final full = painter.width;
  // Tek satır 84 px'i (1.0 ölçekte) geçmiyorsa olduğu gibi kalır.
  if (full <= 84) {
    final s = painter.size;
    painter.dispose();
    return s;
  }
  var longest = 0.0;
  for (final word in label.split(RegExp(r'\s+'))) {
    final wp = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    longest = math.max(longest, wp.width);
    wp.dispose();
  }
  painter.layout(maxWidth: math.max(longest, full / 2 + 6));
  final s = painter.size;
  painter.dispose();
  return s;
}

TextStyle _labelStyle(double fontSize, Color color) => TextStyle(
      fontFamily: 'InterDisplay',
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
      height: 1.12,
      letterSpacing: -0.2,
      color: color,
    );

/// Tek balon: dokununca ölçekle büyür ve vurgu rengine döner; tekrar
/// dokununca eski hâline döner.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.label,
    required this.fontSize,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final double fontSize;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final instant = reduceMotion(context);
    final d = instant ? Duration.zero : const Duration(milliseconds: 220);
    // Koyu vurgu → açık yazı; açık bir vurgu verilirse mürekkep kalır.
    final fg = selected
        ? (accent.computeLuminance() < 0.5 ? Poster.paper : Poster.ink)
        : Poster.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? _kSelectedScale : 1,
          duration: d,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: d,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : Poster.ink.withValues(alpha: 0.05),
              border: Border.all(
                color: selected
                    ? accent
                    : Poster.ink.withValues(alpha: 0.10),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(3),
            child: AnimatedDefaultTextStyle(
              duration: d,
              style: _labelStyle(fontSize, fg),
              textAlign: TextAlign.center,
              child: Text(label, maxLines: 2, overflow: TextOverflow.clip),
            ),
          ),
        ),
      ),
    );
  }
}
