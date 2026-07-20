import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';

/// GERÇEK e-posta doğrulama: Firebase doğrulama linkini gönderir, kullanıcı
/// mailindeki linke tıklar. Bu ekran periyodik reload ile emailVerified'i
/// kontrol eder; doğrulanınca [onVerified].
class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  final String email;
  final VoidCallback onVerified;

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  Timer? _poll;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _send(initial: true);
    // Arka planda her 4 sn'de bir doğrulanmış mı diye bak — link tıklanınca
    // ekran kendiliğinden geçsin.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _send({bool initial = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      await user?.sendEmailVerification();
    } catch (_) {}
    if (!mounted) return;
    if (!initial) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(strProvider).verifySent)),
      );
    }
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
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (verified) {
        _poll?.cancel();
        if (mounted) widget.onVerified();
        return;
      }
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(strProvider).verifyNotYet)),
        );
      }
    } catch (_) {
    } finally {
      _checking = false;
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
            const Align(
              alignment: Alignment.centerLeft,
              child: _BackButton(),
            ),
            const SizedBox(height: 20),
            // İkon rozeti — posta zarfı (OtpScreen tasarımındaki 60×60 kare).
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.envMarket,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.mail_outline_rounded,
                  size: 30, color: c.accentStrong),
            ),
            const SizedBox(height: 24),
            Text(
              str.verifyEmailTitle,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              str.verifyEmailBody,
              style:
                  TextStyle(fontSize: 15, height: 1.45, color: c.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              widget.email,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => _check(),
                child: Text(str.verifyDone),
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
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                onPressed: _cooldown == 0 ? () => _send() : null,
                child: Text(_cooldown == 0
                    ? str.verifyResend
                    : '${str.verifyResend} (${_cooldown}s)'),
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
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.text),
        ),
      ),
    );
  }
}
