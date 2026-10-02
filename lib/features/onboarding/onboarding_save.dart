import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/redesign_l10n.dart';
import '../auth/auth_service.dart';
import '../auth/sign_in_guard.dart';
import '../../core/formatters.dart';
import 'onboarding_palette.dart';
import 'widgets/budgy_money_envelope.dart';

/// Onboarding'in son sayfası: anonim hesabı Apple/Google'a bağlama daveti.
///
/// Uygulama anonim oturumla açılıyor; kullanıcı buraya gelene kadar zaten
/// kategorilerini, para birimini, ilk gününü yazdı. O veri cihazdaki anonim
/// kimliğe bağlı — telefon kaybolursa gider. [AuthService] anonim hesabı
/// sağlayıcıya BAĞLADIĞI için (`linkWithProvider`) buradaki giriş hiçbir şeyi
/// silmez, aynı kullanıcıya kimlik ekler. Kimlik zaten başka bir hesabınsa
/// [signInGuardingData] devreye girer: başlangıç bakiyesi gibi kaybedilecek
/// bir şey varsa önce sorar.
///
/// Üç çıkış da aynı yere gider: [onDone]. Bağlanamasa bile onboarding biter —
/// kullanıcıyı kapıda tutmuyoruz, uyarıyı gösterip içeri alıyoruz.
class SaveBookPage extends ConsumerStatefulWidget {
  const SaveBookPage({
    super.key,
    required this.onDone,
    this.currencyCode = 'TRY',
    this.connectGoogle,
    this.connectApple,
    this.hasData,
  });

  /// Bağlandı, atlandı ya da başarısız oldu — her hâlde onboarding biter.
  final VoidCallback onDone;

  /// Katlanmadan önceki düz sayfanın üstünde duran simge.
  final String currencyCode;

  /// Test kancaları: sağlayıcı akışı ve "veri var mı" cevabı. null →
  /// gerçek [AuthService] / Firestore.
  final Future<void> Function()? connectGoogle;
  final Future<void> Function()? connectApple;
  final Future<bool> Function()? hasData;

  @override
  ConsumerState<SaveBookPage> createState() => _SaveBookPageState();
}

class _SaveBookPageState extends ConsumerState<SaveBookPage> {
  bool _busy = false;

  /// Bağlantı başarılı: zarf mühürlenirken ekran bir an duruyor, sonra
  /// onboarding kapanıyor.
  bool _sealed = false;
  String? _error;

  /// Apple ile giriş yalnız Apple platformlarında görünür; Android'de o düğme
  /// hiç çizilmez (App Store şartı iOS için, tersi yok).
  bool get _showApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<void> _connect(Future<void> Function() run) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await signInGuardingData(context, ref, run,
          hasData: widget.hasData);
      if (!mounted) return;
      if (!ok) {
        // Diyalogda vazgeçti: sayfa olduğu gibi, düğmeler yeniden açık.
        setState(() => _busy = false);
        return;
      }
      // Zarf kapanıp onay işaretini gösterene kadar bekle; kullanıcı neyin
      // olduğunu görmeden ekran değişmesin.
      setState(() => _sealed = true);
      await Future<void>.delayed(BudgyMoneyEnvelope.sealDuration);
      if (mounted) widget.onDone();
    } catch (e) {
      if (!mounted) return;
      final rs = ref.read(rsProvider);
      final failure = classifySocialAuthError(e);
      setState(() {
        _busy = false;
        // İptal hata değil: kullanıcı sağlayıcı sayfasını kapattı, ekran
        // sessizce eski hâline dönüyor. Kırmızı uyarı göstermek yanlış olur.
        _error = switch (failure) {
          SocialAuthFailure.canceled => null,
          SocialAuthFailure.differentMethod => rs.saveErrDifferent,
          SocialAuthFailure.network => rs.saveErrOffline,
          SocialAuthFailure.notEnabled || SocialAuthFailure.unknown =>
            rs.saveFailed,
        };
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
                // Sayfanın ortası: Budgy'nin zarfı, içinde para. Kapak
                // sakin sakin aralanıp kapanıyor; hesap bağlanınca sıkıca
                // mühürlenip onay işareti veriyor.
                Center(
                  child: BudgyMoneyEnvelope(
                    size: (width * 0.42).clamp(120.0, 180.0),
                    semanticsLabel: rs.saveMarkLabel,
                    currencySymbol:
                        kCurrencies[widget.currencyCode] ?? widget.currencyCode,
                    sealed: _sealed,
                  ),
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
                    onTap: () => _connect(
                        widget.connectApple ?? AuthService.signInWithApple),
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
                  onTap: () => _connect(
                      widget.connectGoogle ?? AuthService.signInWithGoogle),
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
