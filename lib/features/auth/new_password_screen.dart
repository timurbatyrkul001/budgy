import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';

/// «Check your email» — диалог после ввода email в Forget password.
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
                  fontSize: 18, fontWeight: FontWeight.w800, color: c.text),
            ),
            const SizedBox(height: 8),
            Text(
              tpl(str.checkEmailBody, {'email': email}),
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, height: 1.4, color: c.textMuted),
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
                      foregroundColor: Colors.white,
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

/// Экран нового пароля: пароль + повтор + чек-лист правил.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _repeat.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  bool get _ruleLen => _password.text.length >= 8;
  bool get _ruleNoName => _password.text.isNotEmpty;
  bool get _ruleSymbol =>
      RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(_password.text);
  bool get _canContinue =>
      _ruleLen &&
      _ruleSymbol &&
      _repeat.text.isNotEmpty &&
      _repeat.text == _password.text;

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
              str.newPasswordTitle,
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
            const SizedBox(height: 20),
            _AuthField(
              label: str.passwordLabel,
              hint: str.passwordHint,
              controller: _password,
              leading: Icons.lock_outline_rounded,
              obscure: _obscure1,
              trailing: _EyeButton(
                obscure: _obscure1,
                onTap: () => setState(() => _obscure1 = !_obscure1),
              ),
            ),
            const SizedBox(height: 16),
            _AuthField(
              label: str.repeatPasswordLabel,
              hint: str.repeatPasswordHint,
              controller: _repeat,
              leading: Icons.lock_outline_rounded,
              obscure: _obscure2,
              trailing: _EyeButton(
                obscure: _obscure2,
                onTap: () => setState(() => _obscure2 = !_obscure2),
              ),
            ),
            const SizedBox(height: 20),
            // Kural kartı — surface2 zemin (tasarımdaki checklist).
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _Rule(text: str.reqMin8, met: _ruleLen),
                  const SizedBox(height: 10),
                  _Rule(text: str.reqNoName, met: _ruleNoName),
                  const SizedBox(height: 10),
                  _Rule(text: str.reqSymbol, met: _ruleSymbol),
                ],
              ),
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
                onPressed: _canContinue ? widget.onDone : null,
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
    this.obscure = false,
    this.trailing,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? leading;
  final bool obscure;
  final Widget? trailing;

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
          style: TextStyle(fontSize: 15, color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, color: c.textFaint),
            filled: true,
            fillColor: c.surface,
            prefixIcon: leading != null
                ? Icon(leading, size: 20, color: c.textFaint)
                : null,
            suffixIcon: trailing,
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

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.obscure, required this.onTap});
  final bool obscure;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: c.textMuted,
      ),
      onPressed: onTap,
    );
  }
}

/// Kural satırı — met: accent dolgulu daire + beyaz tik; değilse boş daire.
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
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: met
              ? BoxDecoration(color: c.accent, shape: BoxShape.circle)
              : BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.textFaint, width: 2),
                ),
          child: met
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13.5, color: met ? c.text : c.textMuted)),
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
