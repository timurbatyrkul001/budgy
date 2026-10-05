import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'auth_service.dart';

/// Doğrulama postasını yollayan fonksiyon.
///
/// Ekran varsayılan olarak Firebase'i çağırır; widget testinde Firebase
/// başlatılamadığı için bu nokta dışarıdan sahte bir fonksiyonla
/// değiştirilir (şifre sıfırlama ekranındaki `SendResetEmail` ile aynı
/// kalıp). Böylece "ağ yok", "çok fazla deneme" gibi yollar gerçek
/// Firebase'e dokunmadan sınanabiliyor.
typedef SendVerification = Future<void> Function();

/// Kullanıcıyı yeniden yükleyip e-postanın doğrulanmış olup olmadığını
/// söyleyen fonksiyon. Null → `currentUser.reload()` + `emailVerified`.
typedef CheckVerified = Future<bool> Function();

/// GERÇEK e-posta doğrulama: Firebase doğrulama linkini gönderir, kullanıcı
/// mailindeki linke tıklar. Bu ekran periyodik reload ile emailVerified'i
/// kontrol eder; doğrulanınca [onVerified].
class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({
    super.key,
    required this.email,
    required this.onVerified,
    this.sendVerification,
    this.checkVerified,
  });

  final String email;
  final VoidCallback onVerified;

  /// Null ise `FirebaseAuth.instance.currentUser.sendEmailVerification()`.
  final SendVerification? sendVerification;

  /// Null ise `currentUser.reload()` sonrası `emailVerified` okunur.
  final CheckVerified? checkVerified;

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  Timer? _poll;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  /// Herhangi bir reload sürüyor (arka plan yoklaması dâhil) — iki reload
  /// üst üste binmesin.
  bool _checking = false;

  /// Kullanıcı "Doğruladım"a bastı, sonuç bekleniyor — düğme kapalı.
  /// [_checking]'den ayrı: arka plan yoklaması düğmeyi titretmemeli.
  bool _manualCheck = false;

  /// Posta gönderimi sürüyor — "Tekrar gönder" kapalı. Çift dokunuş iki
  /// posta yollar ve too-many-requests'e yaklaştırır.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // İlk kadrodan sonra: `_send` düğmeyi kilitlemek için setState çağırır,
    // initState içinde bunu yapmak doğru değil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _send(initial: true);
    });
    // Arka planda her 4 sn'de bir doğrulanmış mı diye bak — link tıklanınca
    // ekran kendiliğinden geçsin.
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _check(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _dispatchSend() {
    final send = widget.sendVerification;
    if (send != null) return send();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Oturum yoksa gönderilecek adres de yok. Eskiden `user?.send…` null'a
      // düşüp sessizce geçiyor ve ekran yine "gönderildi" diyordu;
      // sınıflandırılabilir bir hata fırlatıp aşağıda genel metne düşürüyoruz.
      throw FirebaseAuthException(code: 'user-not-found');
    }
    return user.sendEmailVerification();
  }

  Future<bool> _dispatchCheck() async {
    final check = widget.checkVerified;
    if (check != null) return check();
    final auth = FirebaseAuth.instance;
    await auth.currentUser?.reload();
    return auth.currentUser?.emailVerified ?? false;
  }

  /// Gönderim hatasının kullanıcıya söylenecek hâli.
  ///
  /// Giriş ekranındaki sınıflandırıcı yeniden kullanılıyor: ağ, deneme
  /// sınırı ve kapatılmış hesap kodları aynı. `credentials` burada "hesap bu
  /// arada silinmiş" (user-not-found) demek; kullanıcıya söylenecek tek şey
  /// postanın gitmediği, o yüzden geri kalan her şeyle aynı metne düşüyor.
  static String _sendErrorText(Strings str, EmailSignInFailure failure) =>
      switch (failure) {
        EmailSignInFailure.network => str.signInErrorNetwork,
        EmailSignInFailure.tooManyRequests => str.signInErrorTooMany,
        EmailSignInFailure.disabled => str.signInErrorDisabled,
        EmailSignInFailure.credentials ||
        EmailSignInFailure.invalidEmail ||
        EmailSignInFailure.unknown =>
          str.verifySendFailed,
      };

  /// Elle kontrolde reload düşerse kullanıcıya söylenecek hâli.
  static String _checkErrorText(Strings str, EmailSignInFailure failure) =>
      switch (failure) {
        EmailSignInFailure.network => str.signInErrorNetwork,
        EmailSignInFailure.tooManyRequests => str.signInErrorTooMany,
        EmailSignInFailure.disabled => str.signInErrorDisabled,
        EmailSignInFailure.credentials ||
        EmailSignInFailure.invalidEmail ||
        EmailSignInFailure.unknown =>
          str.errorGeneric,
      };

  Future<void> _send({bool initial = false}) async {
    if (_sending) return;
    setState(() => _sending = true);

    EmailSignInFailure? failure;
    try {
      await _dispatchSend();
    } on FirebaseAuthException catch (e) {
      // Ham `e.message` basılmıyor: İngilizce geliyor ve kullanıcıya bir
      // şey anlatmıyor.
      failure = classifyEmailSignInError(e.code);
    } catch (_) {
      failure = EmailSignInFailure.unknown;
    }

    if (!mounted) return;
    setState(() => _sending = false);
    // Metinler await'ten SONRA okunur: açılıştaki gönderim ilk kadroda
    // başlıyor ve o anda dil akışı henüz gelmemiş olabiliyor — önce
    // okunsa Türkçe arayüzde İngilizce şerit çıkıyor.
    final str = ref.read(strProvider);
    final error = failure == null ? null : _sendErrorText(str, failure);

    if (error != null) {
      // Posta GİTMEDİ. Eskiden hata boş `catch`te yutuluyor, "gönderildi"
      // her hâlde yazılıyor ve 45 sn'lik bekleme başlıyordu — kullanıcı hiç
      // gitmemiş bir postayı bekliyordu. Şimdi sebebi görür; bekleme de
      // başlamaz, hemen yeniden deneyebilir.
      showErrorSnack(context, error);
      return;
    }
    if (!initial) showInfoSnack(context, str.verifySent);
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _cooldown = 45);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown == 0) {
        t.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) setState(() => _manualCheck = true);
    try {
      final verified = await _dispatchCheck();
      if (!mounted) return;
      if (verified) {
        _poll?.cancel();
        widget.onVerified();
        return;
      }
      if (!silent) showInfoSnack(context, ref.read(strProvider).verifyNotYet);
    } on FirebaseAuthException catch (e) {
      // Arka plan yoklaması sessiz kalır: ağ gidip gelirken her 4 sn'de bir
      // şerit çıkmasın. Kullanıcı kendi bastıysa neden olmadığını görmeli —
      // eskiden burası da boş `catch`ti ve düğme hiçbir şey yapmıyormuş gibi
      // duruyordu.
      if (!silent && mounted) {
        showErrorSnack(
          context,
          _checkErrorText(
            ref.read(strProvider),
            classifyEmailSignInError(e.code),
          ),
        );
      }
    } catch (_) {
      if (!silent && mounted) {
        showErrorSnack(context, ref.read(strProvider).errorGeneric);
      }
    } finally {
      _checking = false;
      if (!silent && mounted) setState(() => _manualCheck = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: _BackButton()),
            const SizedBox(height: 20),
            // İkon rozeti — posta zarfı, 60×60 kare.
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.envMarket,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.mail_outline_rounded,
                size: 30,
                color: c.accentStrong,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              str.verifyEmailTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: c.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              str.verifyEmailBody,
              style: TextStyle(fontSize: 15, height: 1.45, color: c.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              widget.email,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Ex.onBrand,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                // Kontrol sürerken düğme kapalı: çift dokunuş iki reload
                // yollamasın, kullanıcı da bir şey olduğunu görsün.
                onPressed: _manualCheck ? null : () => _check(),
                child: _manualCheck
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Ex.onBrand,
                        ),
                      )
                    : Text(str.verifyDone),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: c.accent,
                  disabledForegroundColor: c.textFaint,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _cooldown == 0 && !_sending ? () => _send() : null,
                child: Text(
                  _cooldown == 0
                      ? str.verifyResend
                      : '${str.verifyResend} (${_cooldown}s)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dairesel geri butonu — surface zemin + ince border (tasarımdaki 40px).
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: c.text,
          ),
        ),
      ),
    );
  }
}
