import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../../core/tokens.dart';

/// Şifre sıfırlama e-postasını gönderen fonksiyon.
///
/// Ekran varsayılan olarak Firebase'i çağırır; widget testinde Firebase
/// başlatılamadığı için bu nokta dışarıdan sahte bir fonksiyonla
/// değiştirilir. Bu sayede "ağ yok", "kullanıcı yok" gibi yollar gerçek
/// Firebase'e dokunmadan sınanabiliyor.
typedef SendResetEmail = Future<void> Function(String email);

/// Şifre sıfırlama: e-posta gir → Firebase bağlantı mailini yollar.
///
/// Yeni şifre uygulamada DEĞİL, maildeki bağlantının açtığı Firebase
/// sayfasında belirlenir. Bu yüzden burada "kod gir" ya da "yeni şifre"
/// ekranı yok; eskiden duran OTP/NewPassword ekranları hiçbir şey
/// göndermeyen sahte akışlardı ve kaldırıldı.
class ForgetPasswordScreen extends ConsumerStatefulWidget {
  const ForgetPasswordScreen({
    super.key,
    required this.onDone,
    this.sendResetEmail,
  });

  /// Çağıran ekranların verdiği geri çağrı. Yeni şifre uygulamada
  /// belirlenmediği için burada tetiklenecek bir "bitti" anı yok; parametre
  /// mevcut çağrıları bozmamak için korunuyor.
  final VoidCallback onDone;

  /// Null ise [FirebaseAuth.instance.sendPasswordResetEmail] kullanılır.
  final SendResetEmail? sendResetEmail;

  @override
  ConsumerState<ForgetPasswordScreen> createState() =>
      _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends ConsumerState<ForgetPasswordScreen> {
  final _email = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Yazı değişince butonu güncelle (geçerli email → aktif).
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _dispatch(String email) {
    final send = widget.sendResetEmail;
    if (send != null) return send(email);
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// E-postayı yollar. [resend] true ise dialogdaki "Tekrar gönder"den
  /// geliyoruz: aynı dialogu yeniden açmak yerine kısa bir onay gösteriyoruz,
  /// yoksa kullanıcı dialog → tekrar gönder → dialog döngüsüne giriyor.
  Future<void> _send({bool resend = false}) async {
    if (_sending) return;
    setState(() => _sending = true);
    final email = _email.text.trim();
    final str = ref.read(strProvider);
    final rs = ref.read(rsProvider);
    final messenger = ScaffoldMessenger.of(context);

    String? error;
    try {
      await _dispatch(email);
    } on FirebaseAuthException catch (e) {
      error = switch (e.code) {
        // Kayıtlı olmayan adres de BAŞARI sayılır. Aksi hâlde bu form bir
        // "bu e-posta kayıtlı mı?" sorgusuna dönüşür ve herkes deneme
        // yanılmayla kimin üye olduğunu öğrenebilir. Yeni Firebase projeleri
        // bunu zaten gizliyor (email enumeration protection) ama proje
        // ayarına güvenmek yerine burada da aynı davranışı sabitliyoruz.
        'user-not-found' => null,
        'invalid-email' => str.invalidEmail,
        'network-request-failed' => rs.saveErrOffline,
        'too-many-requests' => rs.resetTooMany,
        // Ham Firebase mesajını basmıyoruz: kullanıcıya bir şey anlatmıyor
        // ve İngilizce geliyor.
        _ => str.errorGeneric,
      };
    } catch (_) {
      error = str.errorGeneric;
    }

    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (resend) {
      messenger.showSnackBar(SnackBar(content: Text(rs.resetResent)));
      return;
    }
    await showCheckEmailDialog(
      context,
      email: email,
      onResend: () => _send(resend: true),
    );
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
            // İkon rozeti — kilit (ResetPasswordScreen tasarımındaki 60×60).
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.envFatura,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 28,
                color: c.accentStrong,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              str.forgetTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: c.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              str.forgetSubtitle,
              style: TextStyle(fontSize: 15, height: 1.45, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            _AuthField(
              label: str.emailLabel,
              hint: str.emailHint,
              controller: _email,
              leading: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Ex.onBrand,
                  disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
                  disabledForegroundColor: Ex.onBrand.withValues(alpha: 0.7),
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                // Gönderim sürerken buton kapalı: çift dokunuş iki mail
                // yollar ve too-many-requests'e yaklaştırır.
                onPressed: _valid && !_sending ? _send : null,
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Ex.onBrand,
                        ),
                      )
                    : Text(str.continueButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Check your email» — e-posta gönderildikten sonra açılan dialog.
Future<void> showCheckEmailDialog(
  BuildContext context, {
  required String email,
  required VoidCallback onResend,
}) {
  final str = ProviderScope.containerOf(context).read(strProvider);
  final c = context.budgy;
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Icon(Icons.close, color: c.textMuted),
              ),
            ),
            const Text('✉️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              str.checkEmailTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tpl(str.checkEmailBody, {'email': email}),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: c.textMuted),
            ),
            // body ↓ butonlar = 12
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.accent,
                      side: BorderSide(color: c.accent.withValues(alpha: 0.4)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(str.notNow),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Ex.onBrand,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onResend();
                    },
                    child: Text(str.resend),
                  ),
                ),
              ],
            ),
            // Butonlar ↓ spam notu = 12
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: c.textFaint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    str.spamNote,
                    style: TextStyle(fontSize: 12, color: c.textFaint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Etiket üstte, surface zeminli alan (ResetPasswordScreen tasarımı).
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.hint,
    required this.controller,
    this.leading,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? leading;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 15, color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, color: c.textFaint),
            filled: true,
            fillColor: c.surface,
            prefixIcon: leading != null
                ? Icon(leading, size: 20, color: c.textFaint)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
          ),
        ),
      ],
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
