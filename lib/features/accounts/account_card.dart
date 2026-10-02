import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/redesign_l10n.dart';
import 'account.dart';
import 'bank_catalog.dart';

/// Hesap kartı: gerçek banka kartı oranında (85.6 × 54 mm ≈ 1.586),
/// bankanın marka renginde ve STİLİNDE, üstünde banka adı + temassız simge +
/// para birimi.
///
/// NEDEN LOGO YOK: bkz. `bank_catalog.dart` başı — logolar tescilli; kartı
/// renk + ad ile kendimiz çiziyoruz.
///
/// NEDEN DESEN VAR AMA KOPYA DEĞİL: Düz renkli kartlar birbirine benziyor;
/// kullanıcı kartının karakterini arıyor (Kaspi Gold'un altını, Enpara'nın
/// beyaz üstü şeridi). Her [CardStyle] için burada KENDİ çizdiğimiz sade bir
/// geometrik motif var: metalik çapraz gradyan, geniş çapraz şerit, köşegen
/// iki ton. Bankanın gerçek kart yüzü (şerit açısı, oranı, hologram, logo)
/// birebir alınmaz — tanınır olsun, taklit olmasın; ticari görünüm riski.
///
/// NEDEN KART BİLGİSİ YOK: Kart yüzünde numara, `•••• 1234`, sahibin adı,
/// son kullanma — hiçbir stilde çizilmez. Uygulamanın kart numarasına
/// ihtiyacı yok ve hiç saklamıyoruz; ekranda bir "•••• 1234" göstermek bile
/// kullanıcıyı "bu uygulama kart bilgimi tutuyor" diye yanıltır. Kartı
/// tanımaya banka kimliği (renk + motif + ad) yetiyor. `Account.last4`
/// alanı modelde dursa da bu widget onu okumaz.
///
/// YAZI RENGİ: [BankBrand.ink] — açık zeminde mürekkep (`Ex.text`), koyuda
/// beyaz. Temassız simgesi ve para birimi rozeti de aynı mürekkebi kullanır;
/// açık zeminli kartta beyaz simge kaybolurdu.
///
/// STİL VARSAYILAN, SEÇİM KULLANICININ: Katalogdaki stil bir tahmin;
/// Ziraat'in tek bir kartı yok. [styleOverride] / [accentOverride] verilirse
/// markanın varsayılanı yerine o çizilir. Modelde saklamak için
/// `CardStyle.name` ↔ `cardStyleFromName` (bank_catalog.dart).
///
/// NAKİT: `AccountKind.cash` kart değil, cüzdandaki kâğıt. Onu marka renkli
/// plastik gibi göstermek yanlış bilgi verir; bu yüzden beyaz kâğıt +
/// mürekkep görünümüne düşer (`Ex.surface` / `Ex.border` / `Ex.text`).
///
/// BANKA HESABI (`AccountKind.bank`, IBAN'lı kartsız hesap): marka renginde
/// çizilir ama temassız simgesi yok — temassız bir kart özelliğidir, hesabın
/// değil.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    this.brand,
    this.styleOverride,
    this.accentOverride,
    this.width = 280,
    this.selected = false,
    this.onTap,
  });

  final Account account;

  /// Marka; verilmezse hesap adından tahmin edilir (`bankByName`), o da
  /// tutmazsa nötr "Diğer banka".
  final BankBrand? brand;

  /// Kullanıcının seçtiği stil; null → markanın varsayılanı.
  final CardStyle? styleOverride;

  /// Kullanıcının seçtiği vurgu rengi; null → markanın `accents` listesi.
  /// `split`'te ikinci ton, `ribbon`'da şerit rengi olur; `flat`/`metal`
  /// okumaz.
  final Color? accentOverride;

  /// Dış genişlik — seçim halkası dahil. Yükseklik orandan türer.
  final double width;

  /// Seçiliyken `Ex.text` renginde 2.5px halka + hafif büyüme.
  final bool selected;

  final VoidCallback? onTap;

  /// Gerçek kart oranı: 85.6 / 54 mm.
  static const aspectRatio = 85.6 / 54;

  /// Halka kalınlığı ve halka ile kart arasındaki kâğıt boşluğu. Halka
  /// alanı seçilmemişken de ayrılır: seçim değişince komşu kartlar kaymasın.
  static const ringWidth = 2.5;
  static const ringGap = 3.0;

  /// Kartın kendisinin (halka hariç) genişliği.
  double get cardWidth => width - 2 * (ringWidth + ringGap);

  /// Toplam yükseklik (halka dahil) — satır/grid yerleşimi için.
  double get height => cardWidth / aspectRatio + 2 * (ringWidth + ringGap);

  /// Çizilecek marka: katalog varsayılanı + kullanıcı override'ları.
  BankBrand get effectiveBrand {
    final base = brand ?? bankByName(account.name) ?? bankByKey('other')!;
    if (styleOverride == null && accentOverride == null) return base;
    return base.copyWith(
      style: styleOverride,
      accents: accentOverride == null ? null : [accentOverride!],
    );
  }

  bool get _isCash => account.kind == AccountKind.cash;

  @override
  Widget build(BuildContext context) {
    final b = effectiveBrand;
    final name = account.name.trim().isEmpty ? b.name : account.name;
    final cw = cardWidth;
    final ch = cw / aspectRatio;
    // Gerçek kartta köşe ~3.2 mm / 85.6 mm ≈ %3.7; ekranda biraz daha
    // yumuşak duruyor, %5.5 kullandık.
    final radius = cw * 0.055;

    final face = _isCash
        ? _PaperFace(
            name: name, currency: account.currency, width: cw, radius: radius)
        : _PlasticFace(
            brand: b,
            // Kullanıcının verdiği ad bankadan farklıysa ("Maaş") küçük alt
            // satır; aynıysa tekrar etmesin.
            subtitle: name.toLowerCase() == b.name.toLowerCase() ? null : name,
            currency: account.currency,
            contactless: account.kind == AccountKind.card,
            width: cw,
            radius: radius,
          );

    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: '$name, ${account.currency}',
      // Tap eylemi burada: aşağıdaki ExcludeSemantics GestureDetector'ın
      // kendi semantiğini de siler, ekran okuyucu "çift dokun" diyemezdi.
      onTap: onTap,
      // İçerideki metinler etikete zaten girdi; ayrı ayrı okunmasın.
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: selected ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: width,
              height: ch + 2 * (ringWidth + ringGap),
              padding: const EdgeInsets.all(ringGap),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + ringGap + ringWidth),
                border: Border.all(
                  color: selected ? Ex.text : Colors.transparent,
                  width: ringWidth,
                ),
              ),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marka renkli "plastik" yüz. Zemin stile göre çizilir; yazı/simge/rozet
/// rengi [BankBrand.ink]'ten gelir.
class _PlasticFace extends StatelessWidget {
  const _PlasticFace({
    required this.brand,
    required this.subtitle,
    required this.currency,
    required this.contactless,
    required this.width,
    required this.radius,
  });

  final BankBrand brand;
  final String? subtitle;
  final String currency;
  final bool contactless;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final pad = width * 0.07;
    final titleSize = width * 0.085;
    final ink = brand.ink;
    final light = brand.isLight;

    final content = Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  brand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'InterDisplay',
                    fontWeight: FontWeight.w900,
                    fontSize: titleSize,
                    height: 1.05,
                    letterSpacing: -0.04 * titleSize,
                    color: ink,
                  ),
                ),
              ),
              if (contactless) ...[
                SizedBox(width: pad * 0.6),
                CustomPaint(
                  size: Size(width * 0.09, width * 0.09),
                  painter: ContactlessPainter(color: ink),
                ),
              ],
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: width * 0.012),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: width * 0.045,
                  // Açık zeminde yarı saydam siyah grileşip kirli duruyor;
                  // uygulamanın kendi ikincil metin rengi daha temiz.
                  color: light ? Ex.textSoft : ink.withValues(alpha: 0.78),
                ),
              ),
            ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: _CurrencyBadge(
              code: currency,
              width: width,
              // Rozet dolgusu mürekkebin saydamı: koyu kartta beyazımsı,
              // açık kartta grimsi kapsül; ikisinde de yazı mürekkep.
              fill: ink.withValues(alpha: light ? 0.08 : 0.22),
              ink: ink,
            ),
          ),
        ],
      ),
    );

    final Widget face = switch (brand.style) {
      // Hafif dikey gradyan: üst bir tık aydınlık, alt bir tık koyu. Düz
      // dolgu ekranda "çıkartma" gibi duruyor; abartılı gradyan ise
      // 2010'ların kart mockup'ı. İki uç da marka renginin kendisi.
      CardStyle.flat => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(brand.color, Colors.white, 0.06)!,
                Color.lerp(brand.color, Colors.black, 0.10)!,
              ],
            ),
          ),
          child: content,
        ),
      CardStyle.metal => CustomPaint(
          painter: MetalFacePainter(color: brand.color),
          child: content,
        ),
      CardStyle.ribbon => CustomPaint(
          painter: RibbonFacePainter(
            ground: brand.ground,
            colors: brand.accents.isEmpty
                // Palet yoksa (kullanıcı override'ı) tonal şerit: zemin
                // üstünde mürekkebin hafif saydamı, görünür ama bağırmaz.
                ? [ink.withValues(alpha: 0.12), ink.withValues(alpha: 0.06)]
                : brand.accents,
            hairline: light ? Ex.border : null,
            radius: radius,
          ),
          child: content,
        ),
      CardStyle.split => CustomPaint(
          painter: SplitFacePainter(
            color: brand.color,
            second: brand.accents.isEmpty
                ? Color.lerp(brand.color, Colors.black, 0.28)!
                : brand.accents.first,
          ),
          child: content,
        ),
    };

    // Motifler kart sınırını aşar (şerit ve köşegen kenardan dışarı
    // uzatılıp burada kırpılır); antiAlias olmadan köşe tırtıklı kalıyor.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: face,
    );
  }
}

/// Metalik yüz: çapraz, koyu → parlak → koyu gradyan + çok hafif parlama.
///
/// Altın/gümüş hissini düz renk veremez; ışığın metale çarpıp döndüğü
/// izlenimi için gradyanın ortasında parlak bir bant gerekir. Abartılı
/// (beyaza vuran) parlama krem kâğıt uygulamada ucuz durur; parlak durak
/// %30 beyaz, parlama bandı %10 saydamlıkta tutuldu.
class MetalFacePainter extends CustomPainter {
  const MetalFacePainter({required this.color});

  final Color color;

  /// Gradyan durakları (koyu → marka → parlak → koyu). Test, en koyu
  /// durağın bile mürekkeple ≥ 4.5:1 verdiğini bununla ölçer: yazı kartın
  /// koyu köşesine düşse de okunmalı.
  static List<Color> stopsFor(Color c) => [
        Color.lerp(c, Colors.black, 0.18)!,
        Color.lerp(c, Colors.white, 0.04)!,
        Color.lerp(c, Colors.white, 0.30)!,
        Color.lerp(c, Colors.black, 0.14)!,
      ];
  static const stopPositions = [0.0, 0.36, 0.56, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Sol üstten sağ alta: gerçek kartı eğince ışık böyle kayar.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          stopsFor(color),
          stopPositions,
        ),
    );
    // Parlama: ana gradyandan farklı açıda dar, saydam beyaz bant. Aynı
    // açıda olsaydı gradyana karışır, fark edilmezdi.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.15, 0),
          Offset(size.width * 0.85, size.height),
          [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
          const [0.30, 0.47, 0.64],
        ),
    );
  }

  @override
  bool shouldRepaint(MetalFacePainter old) => old.color != color;
}

/// Şeritli yüz: açık zemin, sağ orta kenardan sol alt köşeye geniş çapraz
/// şerit; şerit boyunca [colors] yumuşak geçişle.
///
/// GEOMETRİ NEDEN BÖYLE: Şerit, sağ kenara üst köşenin altından (0.46h)
/// girer ve alt kenardan (0.22w) çıkar. Böylece başlık (sol üst), temassız
/// simgesi (sağ üst) ve para birimi rozeti (sağ alt) şeridin ÜSTÜNE
/// düşmez — mürekkep yazı turuncu/mor şerit üstünde okunmazdı. Açı ve
/// genişlik bizim seçimimiz; bankanın şeridini kopyalamıyoruz.
class RibbonFacePainter extends CustomPainter {
  const RibbonFacePainter({
    required this.ground,
    required this.colors,
    required this.radius,
    this.hairline,
  });

  final Color ground;
  final List<Color> colors;
  final double radius;

  /// Beyaz kart krem kâğıtta kaybolmasın diye ince iç kenarlık; koyu
  /// zeminde gereksiz (null).
  final Color? hairline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Zemin: üst beyaz, alt bir tık sıcak — düz beyaz plastik "boş" durur.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          [ground, Color.lerp(ground, Colors.black, 0.035)!],
        ),
    );

    // Şerit ekseni ve kalınlığı.
    final p0 = Offset(w, h * 0.46);
    final p1 = Offset(w * 0.22, h);
    final half = h * 0.17;
    final dir = p1 - p0;
    final len = dir.distance;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    // Uçlar kartın dışına uzatılır; ClipRRect kırpar. Böylece şerit kenara
    // "yapışık" değil, kartın altından geçiyor gibi görünür.
    final a = p0 - u * len;
    final b = p1 + u * len;
    final band = Path()
      ..moveTo((a + n * half).dx, (a + n * half).dy)
      ..lineTo((b + n * half).dx, (b + n * half).dy)
      ..lineTo((b - n * half).dx, (b - n * half).dy)
      ..lineTo((a - n * half).dx, (a - n * half).dy)
      ..close();

    final cs = colors.length == 1 ? [colors.first, colors.first] : colors;
    final stops = [
      for (var i = 0; i < cs.length; i++) i / (cs.length - 1),
    ];
    canvas.drawPath(
      band,
      Paint()..shader = ui.Gradient.linear(p0, p1, cs, stops),
    );

    if (hairline != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = hairline!,
      );
    }
  }

  @override
  bool shouldRepaint(RibbonFacePainter old) =>
      old.ground != ground ||
      old.colors != colors ||
      old.radius != radius ||
      old.hairline != hairline;
}

/// Köşegen iki ton: sol/üst [color], sağ/alt [second]. Köşegen üst kenarda
/// 0.58w'dan alt kenarda 0.30w'a iner — dik, ama tam dikey değil.
///
/// Temassız simgesi ve para birimi rozeti ikinci tonun üstüne düşer; o
/// yüzden katalogda ikinci ton da mürekkeple ≥ 4.5:1 olmak zorunda
/// (bank_catalog_test). Kesişim çizgisine birkaç piksellik yumuşatma var:
/// iki doygun ton (siyah → kırmızı) sert kesildiğinde ekranda "yapıştırma"
/// gibi duruyordu.
class SplitFacePainter extends CustomPainter {
  const SplitFacePainter({required this.color, required this.second});

  final Color color;
  final Color second;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Ana ton: flat ile aynı hafif dikey gradyan — stil ailesi tutarlı.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          [
            Color.lerp(color, Colors.white, 0.06)!,
            Color.lerp(color, Colors.black, 0.10)!,
          ],
        ),
    );

    final top = Offset(w * 0.58, 0);
    final bottom = Offset(w * 0.30, h);
    final u = (bottom - top) / (bottom - top).distance;
    final n = Offset(-u.dy, u.dx); // sağa bakan normal
    final soft = w * 0.012; // ~3px @ 280: görünür yumuşama, bulanıklık değil
    final region = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(w * 2, 0)
      ..lineTo(w * 2, h)
      ..lineTo(bottom.dx, bottom.dy)
      ..close();
    canvas.drawPath(
      region,
      Paint()
        ..shader = ui.Gradient.linear(
          top,
          top + n * soft,
          [second.withValues(alpha: 0), second],
        ),
    );
  }

  @override
  bool shouldRepaint(SplitFacePainter old) =>
      old.color != color || old.second != second;
}

/// Nakit için kâğıt yüz: beyaz, ince kenarlık, mürekkep yazı.
/// Nakit kartının kâğıt yüzü.
///
/// [ConsumerWidget]: üstündeki "nakit" notu üç dilde yazılmalı. Eskiden
/// burada düz 'Nakit' sabiti vardı — İngilizce ve Rusça arayüzde de
/// Türkçe görünüyordu.
class _PaperFace extends ConsumerWidget {
  const _PaperFace({
    required this.name,
    required this.currency,
    required this.width,
    required this.radius,
  });

  final String name;
  final String currency;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final pad = width * 0.07;
    final titleSize = width * 0.085;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Ex.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Ex.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'InterDisplay',
                fontWeight: FontWeight.w900,
                fontSize: titleSize,
                height: 1.05,
                letterSpacing: -0.04 * titleSize,
                color: Ex.text,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Küçük "nakit" notu: kâğıdın neden kart olmadığını söyler.
                Expanded(
                  child: Text(
                    rs.cash,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: width * 0.045,
                      color: Ex.textMuted,
                    ),
                  ),
                ),
                _CurrencyBadge(
                  code: currency,
                  width: width,
                  fill: Ex.surfaceHi,
                  ink: Ex.textSoft,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sağ alttaki para birimi kapsülü (TRY / AZN...).
class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({
    required this.code,
    required this.width,
    required this.fill,
    required this.ink,
  });

  final String code;
  final double width;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.035,
        vertical: width * 0.014,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(width),
      ),
      child: Text(
        code.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: width * 0.042,
          letterSpacing: 0.04 * width * 0.042,
          color: ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Temassız ödeme simgesi: ortak merkezli üç yay, sağa açılır.
///
/// İkon paketi kullanmadık: Material'daki `contactless` ikonu daire içinde
/// ve kalın; kart yüzündeki gerçek sembol ince, çerçevesiz üç yay.
class ContactlessPainter extends CustomPainter {
  const ContactlessPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;
    // Merkez sol kenarın biraz içinde; yaylar sağa doğru büyür.
    final center = Offset(size.width * 0.18, size.height / 2);
    const sweep = 1.25; // radyan, ~72°: dar yay, geniş değil.
    for (var i = 1; i <= 3; i++) {
      final r = size.width * 0.22 * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -sweep / 2,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ContactlessPainter old) => old.color != color;
}
