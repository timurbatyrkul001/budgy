import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';

/// Экран ввода OTP-кода (после регистрации). 6 ячеек, таймер повтора.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.email, required this.onVerified});

  final String email;
  final VoidCallback onVerified;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _seconds = 66; // 01:06

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds == 0) return;
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _filled => _code.text.length == 6;

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _BackButton(),
            ),
            const SizedBox(height: 20),
            // İkon rozeti — posta zarfı (tasarımdaki 60×60 kare).
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
              str.otpTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: c.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              str.otpSubtitle,
              style:
                  TextStyle(fontSize: 15, height: 1.45, color: c.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              widget.email,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 28),
            _OtpBoxes(
              code: _code,
              focus: _focus,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  str.resendIn.split('{time}').first,
                  style: TextStyle(fontSize: 14, color: c.textMuted),
                ),
                Text(
                  _timeLabel,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.accent),
                ),
              ],
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
                onPressed: _filled ? widget.onVerified : null,
                child: Text(str.continueButton),
              ),
            ),
            const SizedBox(height: 20),
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

/// 6 ячеек OTP: видимые боксы + скрытое поле ввода (цифровая клавиатура).
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.code,
    required this.focus,
    required this.onChanged,
  });

  final TextEditingController code;
  final FocusNode focus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < 6; i++) ...[
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color:
                            code.text.length == i ? c.accent : c.border,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      i < code.text.length ? code.text[i] : '',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: c.text),
                    ),
                  ),
                ),
              ),
              if (i != 5) const SizedBox(width: 9),
            ],
          ],
        ),
        // Прозрачное поле поверх — фокус открывает цифровую клавиатуру.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: code,
              focusNode: focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(counterText: ''),
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
