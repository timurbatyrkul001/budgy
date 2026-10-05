import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../intents/intent_channel.dart';
import '../onboarding/onboarding_flow.dart';
import '../root/root_screen.dart';

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
/// `flutter run --dart-define=PREVIEW_ONBOARDING=true [--dart-define=PREVIEW_STEP=12]`.
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
  /// Anonim oturum kurulamadı mı? Kurulamazsa `currentUser` null kalır ve
  /// `authStateProvider` hata değil, sadece null yayar — yani açılış ekranı
  /// sonsuza kadar durur. Bu bayrak o sessiz takılmayı görünür kılıyor.
  bool _failed = false;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  /// Uygulama anonim oturumla açılır: kayıt olmadan kullanılabilsin diye.
  ///
  /// `await` ve `catch` ŞART: ağ yokken bu çağrı sessizce başarısız oluyordu,
  /// `currentUser` null kalıyordu ve kullanıcı "Budgy" yazısına sonsuza kadar
  /// bakıyordu — ne mesaj ne düğme. Artık hata yakalanıp ekrana çıkıyor.
  Future<void> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser != null || _signingIn) return;
    setState(() {
      _signingIn = true;
      _failed = false;
    });
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) setState(() => _signingIn = false);
    } catch (error, stack) {
      // Açılışı engelleyen hata sessiz kalmamalı: kullanıcıya gösteriyoruz,
      // rapora da düşüyor.
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'anonymousSignIn',
          fatal: false,
        ),
      );
      if (mounted) {
        setState(() {
          _signingIn = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) => user == null
          ? (_failed
                ? _StartupError(onRetry: _ensureSignedIn)
                : const _Splash())
          // Kısayollar/Siri kanalı oturumla birlikte açılır: depo uid ister,
          // "hazırız" demek ancak kullanıcı varken doğru (bkz. intents/).
          : const IntentChannelHost(child: _OnboardingGate()),
      loading: () => const _Splash(),
      error: (e, _) => _StartupError(onRetry: _ensureSignedIn),
    );
  }
}

/// Açılış başarısız: ne olduğunu söyleyen bir mesaj ve tekrar deneme düğmesi.
/// Eskiden burada ham hata metni vardı ("Ошибка входа: [firebase_auth/...]")
/// — kullanıcıya hiçbir şey anlatmıyordu ve yapabileceği bir şey de yoktu.
class _StartupError extends ConsumerWidget {
  const _StartupError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    return Scaffold(
      backgroundColor: Ex.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: Ex.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                rs.startupFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Ex.textSoft,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => onRetry(),
                style: FilledButton.styleFrom(
                  backgroundColor: Ex.brand,
                  foregroundColor: Ex.onBrand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Ex.buttonRadius),
                  ),
                ),
                child: Text(rs.retry),
              ),
            ],
          ),
        ),
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
    return showOnboarding ? const OnboardingFlow() : const RootScreen();
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
