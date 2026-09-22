import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../envelopes/budget_repository.dart';
import '../onboarding/onboarding_flow.dart';
import '../root/root_screen.dart';
import 'biometric_gate.dart';

/// Поток состояния авторизации Firebase.
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// uid текущего пользователя. Доступен только под [AuthGate].
final uidProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw StateError('Пользователь не авторизован');
  return user.uid;
});

/// Onboarding'i veriye dokunmadan göstermek için (ekran görüntüsü):
/// `flutter run --dart-define=PREVIEW_ONBOARDING=true [--dart-define=PREVIEW_STEP=5]`.
/// Yalnız debug. (Ana ekran önizlemesi için bkz. home/preview_home.dart.)
const _previewOnboarding =
    kDebugMode && bool.fromEnvironment('PREVIEW_ONBOARDING');
const _previewStep = int.fromEnvironment('PREVIEW_STEP');

/// Прозрачная авторизация: если пользователя нет — входим анонимно.
/// Экранов логина в MVP нет, данные сразу привязаны к uid.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser == null) {
      FirebaseAuth.instance.signInAnonymously();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) =>
          user == null ? const _Splash() : const _OnboardingGate(),
      loading: () => const _Splash(),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Ошибка входа: $e')),
      ),
    );
  }
}

/// Новичкам (нет конвертов и онбординг не пройден) — 3 adımlı onboarding,
/// остальным — сразу главный экран.
class _OnboardingGate extends ConsumerWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_previewOnboarding) {
      return const OnboardingFlow(preview: true, initialStep: _previewStep);
    }

    final done = ref.watch(onboardingDoneProvider);
    final envelopes = ref.watch(envelopesProvider);
    // Cüzdan göçü ana ekrandan ÖNCE bitmeli — yoksa bakiye bir an yanlış
    // (0) görünüp sonra zıplar.
    final migration = ref.watch(walletMigrationProvider);
    if (done.isLoading || envelopes.isLoading || migration.isLoading) {
      return const _Splash();
    }
    final showOnboarding =
        done.value != true && (envelopes.value?.isEmpty ?? true);
    return showOnboarding
        ? const OnboardingFlow()
        : const BiometricGate(child: RootScreen());
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Budgy',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
