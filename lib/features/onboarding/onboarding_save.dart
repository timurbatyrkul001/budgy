import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/redesign_l10n.dart';
import '../auth/auth_service.dart';
import 'onboarding_palette.dart';

/// Onboarding'in son sayfası: anonim hesabı Apple/Google'a bağlama daveti.
///
/// Uygulama anonim oturumla açılıyor; kullanıcı buraya gelene kadar zaten
/// kategorilerini, para birimini, ilk gününü yazdı. O veri cihazdaki anonim
/// kimliğe bağlı — telefon kaybolursa gider. [AuthService] anonim hesabı
/// sağlayıcıya BAĞLADIĞI için (`linkWithProvider`) buradaki giriş hiçbir şeyi
/// silmez, aynı kullanıcıya kimlik ekler.
///
/// Üç çıkış da aynı yere gider: [onDone]. Bağlanamasa bile onboarding biter —
/// kullanıcıyı kapıda tutmuyoruz, uyarıyı gösterip içeri alıyoruz.
class SaveBookPage extends ConsumerStatefulWidget {
  const SaveBookPage({super.key, required this.onDone});

  /// Bağlandı, atlandı ya da başarısız oldu — her hâlde onboarding biter.
  final VoidCallback onDone;

  @override
  ConsumerState<SaveBookPage> createState() => _SaveBookPageState();
}

class _SaveBookPageState extends ConsumerState<SaveBookPage> {
  bool _busy = false;
  String? _error;

  /// Apple ile giriş yalnız Apple platformlarında görünür; Android'de o düğme
  /// hiç çizilmez (App Store şartı iOS için, tersi yok).
  bool get _showApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<void> _connect(Future<UserCredential> Function() run) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await run();
      if (mounted) widget.onDone();
    } catch (_) {
      // Hata metni sağlayıcıdan geliyor ve kullanıcıya bir şey anlatmıyor;
      // kendi cümlemizi gösterip yolu açık bırakıyoruz.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ref.read(rsProvider).saveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 340;

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        // Bu sayfada geri oku yok (yazma bitti, geri dönülmez); diğer
        // sayfalarda o okun açtığı üst boşluğu burada padding veriyor.
        padding: const EdgeInsets.fromLTRB(20, 34, 20, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 42),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SaveTitle(rs.saveTitle, maxWidth: width - 40, narrow: narrow),
                const SizedBox(height: 14),
                Text(
                  rs.saveBody,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    height: 1.4,
                    color: Poster.inkSoft,
                  ),
                ),
                const Spacer(),
                // Sayfanın ortası: Budgy'nin kendi işareti — uygulama
                // simgesindeki zarf, afişin mürekkebiyle büyütülmüş.
                Center(
                  child: _BudgyMark(size: (width * 0.42).clamp(120.0, 180.0)),
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.35,
                      color: Poster.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_showApple) ...[
                  _SaveButton(
                    label: rs.saveApple,
                    logo: 'assets/brand/apple.png',
                    logoColor: Poster.paper,
                    fill: Poster.ink,
                    foreground: Poster.paper,
                    busy: _busy,
                    onTap: () => _connect(AuthService.signInWithApple),
                  ),
                  const SizedBox(height: 10),
                ],
                _SaveButton(
                  label: rs.saveGoogle,
                  logo: 'assets/brand/google.png',
                  fill: Poster.paper,
                  foreground: Poster.ink,
                  border: true,
                  busy: _busy,
                  onTap: () => _connect(AuthService.signInWithGoogle),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : widget.onDone,
                    child: Text(
                      rs.saveSkip,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Poster.inkSoft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rs.saveNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.35,
                    color: Poster.inkFaint,
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

/// Sağlayıcı düğmesi: logo + metin, tam genişlik hap. [busy] iken tıklama
/// kapanır — sağlayıcının kendi tam ekran penceresi zaten açık, üstüne bir
/// de gösterge koymak gürültü olurdu.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.label,
    required this.logo,
    required this.fill,
    required this.foreground,
    required this.busy,
    required this.onTap,
    this.logoColor,
    this.border = false,
  });

  final String label;
  final String logo;
  final Color? logoColor;
  final Color fill;
  final Color foreground;
  final bool border;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: border
            ? BorderSide(color: Poster.ink.withValues(alpha: 0.16))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(logo, height: 20, color: logoColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'InterDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: foreground,
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

/// Akıştaki display başlığın bu sayfadaki eşi: uzun sözcük sığmazsa punto
/// düşer (ru "Сохрани").
class _SaveTitle extends StatelessWidget {
  const _SaveTitle(this.text, {required this.maxWidth, required this.narrow});

  final String text;
  final double maxWidth;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final base = narrow ? 32.0 : 36.0;
    var size = base;
    final longest = text
        .split(RegExp(r'\s+'))
        .fold<String>('', (a, b) => b.length > a.length ? b : a);
    while (size > 20) {
      final tp = TextPainter(
        text: TextSpan(text: longest, style: _titleStyle(size)),
        textDirection: Directionality.of(context),
      )..layout();
      if (tp.width <= maxWidth) break;
      size -= 1;
    }
    return Text(text, style: _titleStyle(size));
  }

  static TextStyle _titleStyle(double size) => TextStyle(
    fontFamily: 'InterDisplay',
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: 0.96,
    letterSpacing: size >= 34 ? -3 : -2.5,
    color: Poster.ink,
  );
}

/// Budgy işareti: uygulama simgesindeki zarf, afiş dilinde.
///
/// Asset değil çizim — `assets/icon/budgy_icon_fg.svg` ile aynı geometri
/// (592x384 gövde, r=72 köşe, 52 kalınlık, kapak 244,384 → 512,576 → 780,384),
/// 592 birimlik kutuya normalize edilmiş. Böylece her ölçekte keskin kalıyor
/// ve simge değişirse tek yerden güncelleniyor.
class _BudgyMark extends StatelessWidget {
  const _BudgyMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 384 / 592,
      child: CustomPaint(painter: _BudgyMarkPainter()),
    );
  }
}

class _BudgyMarkPainter extends CustomPainter {
  /// Simgedeki gövde genişliği — tüm koordinatlar buna göre oranlanıyor
  /// (yükseklik 384, oran widget tarafında uygulanıyor).
  static const _w = 592.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _w;
    final stroke = Paint()
      ..color = Poster.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 52 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Gövde: çizgi kalınlığının yarısı kadar içeri alınıyor ki kontur
    // kutunun dışına taşmasın.
    final inset = 26 * k;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset,
          inset,
          size.width - inset * 2,
          size.height - inset * 2,
        ),
        Radius.circular(72 * k - inset / 2),
      ),
      stroke,
    );

    // Kapak: simgedeki mutlak koordinatlar gövdenin sol üstüne taşınıyor
    // (rect x=216, y=336 → 0,0).
    Offset p(double x, double y) => Offset((x - 216) * k, (y - 336) * k);
    canvas.drawPath(
      Path()
        ..moveTo(p(244, 384).dx, p(244, 384).dy)
        ..lineTo(p(512, 576).dx, p(512, 576).dy)
        ..lineTo(p(780, 384).dx, p(780, 384).dy),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_BudgyMarkPainter old) => false;
}
