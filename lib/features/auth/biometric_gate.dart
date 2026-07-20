import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';

/// Face ID / parmak izi kilidi. Kilit açıksa uygulama açılışında ve arka
/// plandan dönüşte kimlik doğrulaması ister.
class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAuth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Arka plana gidince yeniden kilitle.
      if (ref.read(biometricEnabledProvider) && mounted) {
        setState(() => _unlocked = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      _maybeAuth();
    }
  }

  Future<void> _maybeAuth() async {
    if (!mounted) return;
    if (!ref.read(biometricEnabledProvider)) {
      if (!_unlocked) setState(() => _unlocked = true);
      return;
    }
    if (_unlocked || _authing) return;
    _authing = true;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: ref.read(strProvider).lockTitle,
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (mounted && ok) setState(() => _unlocked = true);
    } catch (_) {
      // Doğrulama başarısız/iptal → kilitli kalır, kullanıcı "Aç"a basar.
    } finally {
      _authing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricEnabledProvider);
    if (!enabled || _unlocked) return widget.child;

    final str = ref.watch(strProvider);
    final c = context.budgy;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
          child: Column(
            children: [
              // Ortada: büyük Face ID plakası + başlık.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.4),
                              blurRadius: 44,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.face_rounded,
                            size: 70, color: Colors.white),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        str.lockTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Altta: tam genişlik "kilidi aç" butonu.
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _maybeAuth,
                  icon: const Icon(Icons.face_rounded, size: 20),
                  label: Text(str.unlockButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
