import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'complete_profile_screen.dart';
import 'email_verify_screen.dart';
import 'sign_in_screen.dart';

/// Экран регистрации: имя + email + пароль + повтор + чек-лист правил.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, required this.onSignedUp});

  final VoidCallback onSignedUp;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    // Yazı değişince kurallar/Continue güncellensin.
    for (final c in [_name, _email, _password, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  // Проверки пароля (живые, по мере ввода).
  bool get _ruleLen => _password.text.length >= 8;
  bool get _ruleNoName {
    final pwd = _password.text.toLowerCase();
    final name = _name.text.trim().toLowerCase();
    if (pwd.isEmpty) return false;
    return name.isEmpty || !pwd.contains(name);
  }

  bool get _ruleSymbol =>
      RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(_password.text);


  /// Buton her zaman basılır; eksik varsa onu söyler (kullanıcı neden
  /// ilerlemediğini görsün).
  void _tryContinue() {
    final str = ref.read(strProvider);
    String? problem;
    if (!_emailValid) {
      problem = str.invalidEmail;
    } else if (!_ruleLen) {
      problem = str.reqMin8;
    } else if (!_ruleSymbol) {
      problem = str.reqSymbol;
    } else if (!_ruleNoName) {
      problem = str.reqNoName;
    } else if (_confirm.text != _password.text || _confirm.text.isEmpty) {
      problem = str.passwordsDontMatch;
    }
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(problem)),
      );
      return;
    }
    _continue();
  }

  /// Kayıt: anonim hesabı email/şifreye BAĞLA (link) — böylece veri kalıcı
  /// olur ve her cihazdan geri gelir. Sonra doğrulama → profil akışına geç.
  Future<void> _continue() async {
    final user = FirebaseAuth.instance.currentUser;
    final str = ref.read(strProvider);
    if (user != null && user.isAnonymous) {
      try {
        final cred = EmailAuthProvider.credential(
          email: _email.text.trim(),
          password: _password.text,
        );
        await user.linkWithCredential(cred);
      } on FirebaseAuthException catch (e) {
        // operation-not-allowed → konsolda Email/Password kapalı.
        // email-already-in-use → bu email zaten var.
        // Gerçek akış: hatayı göster, devam etme.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${str.errorPrefix}: ${e.message ?? e.code}')),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailVerifyScreen(
          email: _email.text.trim(),
          onVerified: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CompleteProfileScreen(
                onComplete: widget.onSignedUp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst nav: geri butonu (surface daire).
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
              child: _CircleButton(
                icon: Icons.chevron_left,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 14, 26, 24),
                children: [
                  Text(
                    str.signUpTitle,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    str.signUpSubtitle,
                    style: TextStyle(
                        fontSize: 15, height: 1.4, color: c.textMuted),
                  ),
                  const SizedBox(height: 18),
                  AuthField(
                    label: str.fullNameLabel,
                    hint: str.fullNameHint,
                    controller: _name,
                    leading: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),
                  AuthField(
                    label: str.emailLabel,
                    hint: str.emailHint,
                    controller: _email,
                    leading: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  AuthField(
                    label: str.passwordLabel,
                    hint: str.passwordHint,
                    controller: _password,
                    obscure: _obscure1,
                    leading: Icons.lock_outline_rounded,
                    trailing: _EyeButton(
                      obscure: _obscure1,
                      onTap: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthField(
                    label: str.confirmPasswordLabel,
                    hint: str.passwordHint,
                    controller: _confirm,
                    obscure: _obscure2,
                    leading: Icons.lock_outline_rounded,
                    trailing: _EyeButton(
                      obscure: _obscure2,
                      onTap: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Kurallar bloğu (canlı checklist).
                  _Rule(text: str.reqMin8, met: _ruleLen),
                  const SizedBox(height: 12),
                  _Rule(text: str.reqNoName, met: _ruleNoName),
                  const SizedBox(height: 12),
                  _Rule(text: str.reqSymbol, met: _ruleSymbol),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            c.accent.withValues(alpha: 0.4),
                        minimumSize: const Size.fromHeight(56),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _tryContinue,
                      child: Text(str.continueButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Круглая кнопка в шапке (surface + рамка).
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
          boxShadow: c.cardShadow,
        ),
        child: Icon(icon, color: c.text),
      ),
    );
  }
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.obscure, required this.onTap});

  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: context.budgy.textMuted,
      ),
      onPressed: onTap,
    );
  }
}

/// Правило пароля: квадратная галочка (accent при выполнении) + текст.
class _Rule extends StatelessWidget {
  const _Rule({required this.text, required this.met});

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: met ? c.accent : c.track,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(Icons.check,
              size: 14, color: met ? Colors.white : c.textFaint),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: met ? c.text : c.textMuted),
          ),
        ),
      ],
    );
  }
}
