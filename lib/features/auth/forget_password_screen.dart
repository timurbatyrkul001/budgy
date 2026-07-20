import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'new_password_screen.dart';

/// Восстановление пароля: ввод email → код подтверждения.
class ForgetPasswordScreen extends ConsumerStatefulWidget {
  const ForgetPasswordScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<ForgetPasswordScreen> createState() =>
      _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState
    extends ConsumerState<ForgetPasswordScreen> {
  final _email = TextEditingController();

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
            const Align(
              alignment: Alignment.centerLeft,
              child: _BackButton(),
            ),
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
              child: Icon(Icons.lock_outline_rounded,
                  size: 28, color: c.accentStrong),
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
              style:
                  TextStyle(fontSize: 15, height: 1.45, color: c.textMuted),
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
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _valid
                    ? () => showCheckEmailDialog(
                          context,
                          email: _email.text.trim(),
                          // «Resend» → переход к экрану нового пароля.
                          onResend: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NewPasswordScreen(
                                // Şifre güncellendi → Sign in'e dön
                                // (NewPassword + Forget kapanır).
                                onDone: () {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                  messenger.showSnackBar(SnackBar(
                                      content:
                                          Text(str.passwordUpdated)));
                                },
                              ),
                            ),
                          ),
                        )
                    : null,
                child: Text(str.continueButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMuted)),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.text),
        ),
      ),
    );
  }
}
