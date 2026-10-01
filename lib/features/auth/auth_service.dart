import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

/// Sosyal giriş: Google + Apple. Her iki yolda da anonim hesap varsa ona
/// BAĞLANIR (uid değişmez, onboarding'de kurulan her şey yerinde kalır);
/// o kimlik başka bir hesaba aitse o hesaba giriş yapılır.
class AuthService {
  /// Google: cihazın kendi giriş akışı (`google_sign_in`).
  ///
  /// Firebase'in `signInWithProvider` federated akışı da çalışıyordu ama
  /// Safari'de `<proje>.firebaseapp.com` sayfasını açıyor ve Google o
  /// ekranda uygulama adı yerine o alan adını gösteriyordu — kullanıcıya
  /// "kopilka-b75f6.firebaseapp.com'a giriş yapıyorsun" diyordu. Yerel akışta
  /// iOS'un kendi hesap seçme sayfası çıkıyor ve başlıkta "Budgy" yazıyor.
  ///
  /// İstemci kimliği iOS'ta `Info.plist`'teki `GIDClientID`'den okunuyor
  /// (değeri `GoogleService-Info.plist`'teki `CLIENT_ID`).
  static Future<UserCredential> signInWithGoogle() async {
    await _initGoogle();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // Pratikte olmaz; olursa sessiz kalmaktansa sınıflandırılabilir bir
      // hata atalım.
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Google kimlik jetonu gelmedi.',
      );
    }
    return _runCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  /// `initialize` yalnız bir kez çağrılmalı; sonuç önbelleğe alınıyor.
  static Future<void>? _googleInit;
  static Future<void> _initGoogle() =>
      _googleInit ??= GoogleSignIn.instance.initialize();

  /// Apple hâlâ Firebase'in federated akışında: yerel Apple girişi ayrı bir
  /// paket ve Apple Developer tarafında Services ID + anahtar kurulumu
  /// istiyor. O kurulum yapıldığında burası da yerel akışa geçmeli.
  static Future<UserCredential> signInWithApple() {
    final provider = AppleAuthProvider()..addScope('email');
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user != null && user.isAnonymous) {
      return user.linkWithProvider(provider).catchError((Object e) {
        if (e is FirebaseAuthException &&
            (e.code == 'credential-already-in-use' ||
                e.code == 'email-already-in-use')) {
          return auth.signInWithProvider(provider);
        }
        throw e;
      });
    }
    return auth.signInWithProvider(provider);
  }

  /// Anonim hesabı varsa kimlik bilgisini BAĞLA (veri kalır); o kimlik başka
  /// bir hesaba aitse o hesaba giriş yap.
  static Future<UserCredential> _runCredential(AuthCredential cred) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        return await user.linkWithCredential(cred);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          return auth.signInWithCredential(cred);
        }
        rethrow;
      }
    }
    return auth.signInWithCredential(cred);
  }
}

/// Sosyal girişin başarısızlık sebebi — kullanıcıya gösterilebilir hâli.
///
/// Ham `FirebaseAuthException` kodu ekrana yazılacak bir şey değil; üstelik
/// bunların biri ("iptal") hata bile sayılmamalı: kullanıcı Safari sayfasını
/// kapattığında kırmızı bir uyarı görmesi yanlış.
enum SocialAuthFailure {
  /// Kullanıcı sağlayıcı sayfasını kapattı. Sessizce eski hâle dön.
  canceled,

  /// Bu e-posta Firebase'de başka bir yöntemle (şifre, başka sağlayıcı)
  /// kayıtlı. Kullanıcı o yöntemle girmeli.
  differentMethod,

  /// Sağlayıcı Firebase konsolunda açık değil — bizim yapılandırma hatamız,
  /// kullanıcının yapabileceği bir şey yok.
  notEnabled,

  /// Ağ yok ya da istek düştü.
  network,

  /// Geri kalan her şey.
  unknown,
}

/// Sağlayıcıdan gelen hatayı [SocialAuthFailure]'a çevirir.
SocialAuthFailure classifySocialAuthError(Object error) {
  // Yerel Google akışı kendi hata tipini atıyor; Firebase koduna çevirmek
  // yerine doğrudan eşliyoruz.
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => SocialAuthFailure.canceled,
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        SocialAuthFailure.network,
      GoogleSignInExceptionCode.clientConfigurationError =>
        SocialAuthFailure.notEnabled,
      _ => SocialAuthFailure.unknown,
    };
  }

  final code = switch (error) {
    FirebaseAuthException(:final code) => code,
    PlatformException(:final code) => code,
    _ => '',
  }.toLowerCase();

  // İptal kodu platforma ve sürüme göre değişiyor (web-context-canceled,
  // canceled, ERROR_ABORTED_BY_USER...). Tek tek saymak yerine gövdesinde
  // "cancel"/"abort" geçenleri iptal sayıyoruz; kalıba uymayan tek kod
  // web'den gelen popup-closed-by-user.
  if (code.contains('cancel') ||
      code.contains('abort') ||
      code == 'popup-closed-by-user') {
    return SocialAuthFailure.canceled;
  }
  return switch (code) {
    'account-exists-with-different-credential' ||
    'email-already-in-use' ||
    'credential-already-in-use' =>
      SocialAuthFailure.differentMethod,
    'operation-not-allowed' ||
    'configuration-not-found' ||
    'invalid-oauth-client-id' ||
    'invalid-oauth-provider' =>
      SocialAuthFailure.notEnabled,
    'network-request-failed' || 'too-many-requests' =>
      SocialAuthFailure.network,
    _ => SocialAuthFailure.unknown,
  };
}
