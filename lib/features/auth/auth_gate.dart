import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
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

/// [AuthGate]'in Firebase Auth'a dokunan iki eylemi. Varsayılanlar gerçek
/// Firebase; widget testinde (Firebase kurulu değil) sahteleriyle
/// değiştiriliyor.
class AuthGateActions {
  const AuthGateActions({
    this.hasCurrentUser = _defaultHasCurrentUser,
    this.signInAnonymously = _defaultSignInAnonymously,
  });

  /// Şu an oturum var mı (`currentUser != null`).
  final bool Function() hasCurrentUser;

  /// Anonim oturum aç. Ağ yoksa fırlatır.
  final Future<void> Function() signInAnonymously;

  static bool _defaultHasCurrentUser() =>
      FirebaseAuth.instance.currentUser != null;

  static Future<void> _defaultSignInAnonymously() =>
      FirebaseAuth.instance.signInAnonymously();
}

/// Прозрачная авторизация: если пользователя нет — входим анонимно.
/// Экранов логина в MVP нет, данные сразу привязаны к uid.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, this.actions = const AuthGateActions()});

  final AuthGateActions actions;

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
    if (widget.actions.hasCurrentUser() || _signingIn) return;
    setState(() {
      _signingIn = true;
      _failed = false;
    });
    try {
      await widget.actions.signInAnonymously();
      if (mounted) setState(() => _signingIn = false);
    } catch (error, stack) {
      // Açılışı engelleyen hata sessiz kalmamalı: kullanıcıya gösteriyoruz,
      // rapora da düşüyor.
      _report(error, stack);
      if (mounted) {
        setState(() {
          _signingIn = false;
          _failed = true;
        });
      }
    }
  }

  /// Crashlytics'e yaz; Firebase kurulu değilse (widget testi) `instance`
  /// kendisi fırlatır — rapor düşmesin diye açılışı bozmayalım.
  static void _report(Object error, StackTrace stack) {
    try {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'anonymousSignIn',
          fatal: false,
        ),
      );
    } catch (_) {
      // Rapor kanalı yok; hata zaten ekranda.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Oturum SONRADAN düşerse de (çıkış, hesap silme, sunucuda iptal edilen
    // jeton) kapı kendini toparlar: null görünce yeniden anonim oturum
    // açmayı dener. Eskiden `_ensureSignedIn` yalnız initState'te
    // çağrılıyordu; hesap silindikten sonra anonim giriş ağ yüzünden
    // düşerse kullanıcı düğmesiz "Budgy" ekranında kalıyor, tek çıkış
    // uygulamayı öldürmek oluyordu. Başarısızlık `_failed`'e düşer ve
    // aşağıda Tekrar dene düğmesiyle çıkar.
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      if (next is AsyncData<User?> && next.value == null) {
        _ensureSignedIn();
      }
    });

    final auth = ref.watch(authStateProvider);
    final rs = ref.watch(rsProvider);
    return auth.when(
      data: (user) => user == null
          ? (_failed
                ? _StartupError(
                    message: rs.startupFailed,
                    onRetry: _ensureSignedIn,
                  )
                : const _Splash())
          // Kısayollar/Siri kanalı oturumla birlikte açılır: depo uid ister,
          // "hazırız" demek ancak kullanıcı varken doğru (bkz. intents/).
          : const IntentChannelHost(child: _OnboardingGate()),
      loading: () => const _Splash(),
      error: (e, _) => _StartupError(
        message: rs.startupFailed,
        onRetry: _ensureSignedIn,
      ),
    );
  }
}

/// Açılış başarısız: ne olduğunu söyleyen bir mesaj ve tekrar deneme düğmesi.
/// Eskiden burada ham hata metni vardı ("Ошибка входа: [firebase_auth/...]")
/// — kullanıcıya hiçbir şey anlatmıyordu ve yapabileceği bir şey de yoktu.
///
/// İki yerden çağrılır: anonim oturum açılamadı ([AuthGate]) ve açılış
/// akışları okunamadı ([_OnboardingGate]); metin çağırana göre değişir.
class _StartupError extends ConsumerWidget {
  const _StartupError({required this.message, required this.onRetry});

  final String message;
  final void Function() onRetry;

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
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Ex.textSoft,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onRetry,
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

/// Açılışta ne gösterilecek — [decideStart]'ın cevabı.
enum StartDecision {
  /// Akışlardan en az biri hâlâ yüklüyor: açılış ekranı.
  loading,

  /// Akışlardan en az biri HATA verdi: mesaj + Tekrar dene. Onboarding
  /// değil.
  error,

  /// Gerçekten yeni kullanıcı: onboarding geçilmemiş ve hiç zarf yok.
  onboarding,

  /// Eski kullanıcı: ana ekran.
  home,
}

/// "Yükleniyor", "hata" ve "gerçekten boş" üç ayrı şeydir.
///
/// Eski kod `done.value != true && (envelopes.value?.isEmpty ?? true)`
/// diyordu. `value` hem yüklenirken hem HATADA null — Firestore kuralı,
/// App Check ya da eksik dizin akışları düşürdüğünde yıllık kullanıcı iki
/// null görüp ONBOARDING'E düşüyordu; onu geçince kategoriler ikinci kez
/// yazılıyor, kullanıcı da "verim gitti" sanıyordu. Hata artık hata olarak
/// çıkar; onboarding yalnız veri gerçekten okunup boş geldiyse.
///
/// Saf fonksiyon: widget'tan ayrı ki tüm bileşimler birim testte denensin.
StartDecision decideStart({
  required AsyncValue<bool> done,
  required AsyncValue<List<Envelope>> envelopes,
  required AsyncValue<void> migration,
}) {
  if (done.isLoading || envelopes.isLoading || migration.isLoading) {
    return StartDecision.loading;
  }
  if (done.hasError || envelopes.hasError || migration.hasError) {
    return StartDecision.error;
  }
  final isNew = done.requireValue != true && envelopes.requireValue.isEmpty;
  return isNew ? StartDecision.onboarding : StartDecision.home;
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
    return switch (decideStart(
      done: done,
      envelopes: envelopes,
      migration: migration,
    )) {
      StartDecision.loading => const _Splash(),
      StartDecision.error => _StartupError(
          message: ref.watch(strProvider).dataLoadFailed,
          // Üç akışı da baştan kur: StreamProvider yeniden abone olur,
          // FutureProvider göçü yeniden dener.
          onRetry: () {
            ref.invalidate(onboardingDoneProvider);
            ref.invalidate(envelopesProvider);
            ref.invalidate(walletMigrationProvider);
          },
        ),
      StartDecision.onboarding => const OnboardingFlow(),
      StartDecision.home => const RootScreen(),
    };
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
