import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'auth_service.dart';
import 'forget_password_screen.dart';
import 'sign_up_screen.dart';

/// Экран входа: email + пароль, соц-входы, ошибка.
/// [onSignedIn] вызывается при успешном входе (или соц-входе).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _error = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Sosyal giriş (Google/Apple) — başarılıysa içeri al, hata olursa göster.
  Future<void> _social(Future<dynamic> Function() signIn) async {
    try {
      await signIn();
      if (mounted) widget.onSignedIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      widget.onSignedIn();
    } on FirebaseAuthException {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
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
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 32),
          children: [
            // Logo mark: accent kare + zarf ikonu.
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.36),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.mail_outline_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              str.signInTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: c.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              str.signInSubtitle,
              style: TextStyle(fontSize: 15, height: 1.4, color: c.textMuted),
            ),
            const SizedBox(height: 20),
            AuthField(
              label: str.emailLabel,
              hint: str.emailHint,
              controller: _email,
              error: _error,
              leading: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            AuthField(
              label: str.passwordLabel,
              hint: str.passwordHint,
              controller: _password,
              error: _error,
              obscure: _obscure,
              leading: Icons.lock_outline_rounded,
              trailing: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: c.textMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            if (_error) ...[
              const SizedBox(height: 12),
              Text(
                str.signInError,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: Colors.red),
              ),
            ],
            const SizedBox(height: 14),
            // Firebase oturumu zaten cihazda kalıcı — ayrı bir "beni hatırla"
            // kutusu hiçbir şey yapmıyordu, kaldırıldı.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ForgetPasswordScreen(
                        onDone: widget.onSignedIn,
                      ),
                    ),
                  ),
                  child: Text(
                    str.forgotPassword,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(str.signInButton),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Container(height: 1, color: c.borderStrong)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(str.orSignUpWith,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textFaint)),
                ),
                Expanded(child: Container(height: 1, color: c.borderStrong)),
              ],
            ),
            const SizedBox(height: 20),
            _SocialButton(
              label: str.continueGoogle,
              leading: Image.asset('assets/brand/google.png', height: 22),
              onTap: () => _social(AuthService.signInWithGoogle),
            ),
            const SizedBox(height: 11),
            _SocialButton(
              label: str.continueApple,
              leading: Image.asset('assets/brand/apple.png',
                  height: 22, color: Colors.white),
              fill: Colors.black,
              foreground: Colors.white,
              onTap: () => _social(AuthService.signInWithApple),
            ),
            const SizedBox(height: 20),
            // Hesabın yok mu? Kaydol
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(str.dontHaveAccount,
                      style: TextStyle(fontSize: 14, color: c.textMuted)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SignUpScreen(onSignedUp: widget.onSignedIn),
                    ),
                  ),
                  child: Text(
                    str.navSignUp,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: c.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              str.termsNote,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, height: 1.4, color: c.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Поле с подписью сверху: surface-заливка + рамка, опциональная иконка слева.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.error = false,
    this.obscure = false,
    this.leading,
    this.trailing,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool error;
  final bool obscure;
  final IconData? leading;
  final Widget? trailing;
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
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 15, color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, color: c.textFaint),
            filled: true,
            fillColor: c.surface,
            prefixIcon:
                leading != null ? Icon(leading, size: 20, color: c.textFaint) : null,
            suffixIcon: trailing,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: error ? Colors.red : c.borderStrong,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: error ? Colors.red : c.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onTap,
    this.fill,
    this.foreground,
  });

  final String label;
  final Widget leading;
  final VoidCallback onTap;

  /// Dolgu rengi (Apple = siyah); null → surface.
  final Color? fill;

  /// Metin rengi; null → c.text.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground ?? c.text,
          backgroundColor: fill ?? c.surface,
          side: BorderSide(color: c.borderStrong),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
