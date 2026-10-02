import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

/// Giriş: Google + Apple + e-posta/şifre. Her yolda anonim hesap varsa ona
/// BAĞLANIR (uid değişmez, onboarding'de kurulan her şey yerinde kalır).
///
/// O kimlik BAŞKA bir hesaba aitse servis kendi başına o hesaba GEÇMEZ:
/// [AccountConflict] fırlatır. Eskiden burada sessizce `signInWithCredential`
/// çağrılıyordu ve anonim hesaptaki her şey (iki haftalık işlemler, kendi
/// kategorileri, bakiye) bir dokunuşta erişilmez oluyordu — veri Firestore'da
/// duruyor ama anonim oturum geri gelmiyor. Karar kullanıcının; servis
/// `BuildContext` bilmez, soruyu arayüz sorar (bkz. `sign_in_guard.dart`).
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
  static Future<UserCredential> signInWithApple() async {
    final provider = AppleAuthProvider()..addScope('email');
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null || !user.isAnonymous) {
      return _finish(auth.signInWithProvider(provider));
    }
    try {
      return await _finish(user.linkWithProvider(provider));
    } on FirebaseAuthException catch (e) {
      if (!isAccountConflict(e.code)) rethrow;
      // Apple federated akışında hata nesnesi çoğu platformda az önce
      // alınan kimlik bilgisini taşıyor; varsa onunla giriyoruz ki kullanıcı
      // Apple sayfasını ikinci kez görmesin. Yoksa akış yeniden açılır.
      final cred = e.credential;
      throw AccountConflict(
        code: e.code,
        signInAnyway: () => _finish(
          cred != null
              ? auth.signInWithCredential(cred)
              : auth.signInWithProvider(provider),
        ),
      );
    }
  }

  /// E-posta + şifre. Sosyal girişlerle aynı kural: anonimde önce BAĞLA.
  ///
  /// Dikkat: e-posta kimliğini bağlamak, o e-posta Firebase'de yoksa hesabı
  /// o anda OLUŞTURUR (Firebase'in `linkWithCredential` davranışı). Yani
  /// anonim kullanıcı için "giriş" ile "bu e-postayı hesabıma ekle" aynı
  /// şey; e-posta zaten kayıtlıysa `email-already-in-use` gelir ve
  /// [AccountConflict] fırlatılır. Şifre ancak o hesaba GİRİLİRKEN
  /// ([AccountConflict.signInAnyway]) sınanır — yanlışsa Firebase'in kendi
  /// hatası gelir ve kullanıcı anonim hesabında kalır, hiçbir şey değişmez.
  /// E-posta + şifreyle GİRİŞ. Bilerek bağlama denemiyor.
  ///
  /// Google/Apple'da "önce bağla" doğru: kimliği sağlayıcı doğruluyor,
  /// yanlış hesaba bağlanmak mümkün değil. E-postada değil — Firebase'de
  /// anonim kullanıcıya e-posta credential'ı BAĞLAMAK, o e-posta yoksa
  /// yeni bir şifre hesabı AÇAR. Yani "Giriş yap" ekranında adresi yanlış
  /// yazan biri "böyle bir hesap yok" uyarısı yerine sessizce yanlış
  /// adrese kayıt olurdu: şifre kuralı denetlenmez, doğrulama postası
  /// gitmez, ve kendi doğru adresiyle başka bir cihazdan girdiğinde
  /// kayıtlarını bulamazdı.
  ///
  /// İş bölümü zaten var: KAYIT OL ekranı bağlar (kimliği mevcut
  /// kayıtlara iliştirir), GİRİŞ YAP ekranı hesap değiştirir. Veri kaybı
  /// uyarısı bu yolda `signInSwitchingAccount` ile ÖNCEDEN sorulur.
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _finish(
      FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  /// Anonim hesabı varsa kimlik bilgisini BAĞLA (veri kalır); o kimlik başka
  /// bir hesaba aitse karar vermeden [AccountConflict] fırlat.
  static Future<UserCredential> _runCredential(AuthCredential cred) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null || !user.isAnonymous) {
      return _finish(auth.signInWithCredential(cred));
    }
    try {
      return await _finish(user.linkWithCredential(cred));
    } on FirebaseAuthException catch (e) {
      if (!isAccountConflict(e.code)) rethrow;
      throw AccountConflict(
        code: e.code,
        signInAnyway: () => _finish(auth.signInWithCredential(cred)),
      );
    }
  }

  /// Giriş/bağlama bitince sağlayıcı adını kopyala; sonucu olduğu gibi ver.
  static Future<UserCredential> _finish(Future<UserCredential> run) async {
    final result = await run;
    await _adoptProviderName(result.user);
    return result;
  }

  /// Firebase'in "bu kimlik zaten başka bir hesapta" dediği kodlar.
  static bool isAccountConflict(String code) =>
      code == 'credential-already-in-use' || code == 'email-already-in-use';

  /// Anonim hesaba kimlik BAĞLANDIĞINDA Firebase kullanıcının `displayName`
  /// alanını doldurmuyor — anonim profilin boş adı olduğu gibi kalıyor.
  /// Sağlayıcıdan gelen adı bir kez kopyalıyoruz; ana ekrandaki "Merhaba
  /// {ad}!" karşılaması buna bakıyor ve aksi hâlde hep adsız selam veriyor.
  static Future<void> _adoptProviderName(User? user) async {
    if (user == null) return;
    if ((user.displayName ?? '').trim().isNotEmpty) return;
    final fromProvider = user.providerData
        .map((p) => p.displayName?.trim())
        .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null);
    if (fromProvider == null) return;
    try {
      await user.updateDisplayName(fromProvider);
      await user.reload();
    } catch (_) {
      // Ad kozmetik: yazılamazsa giriş yine başarılı sayılır.
    }
  }
}

/// Bağlanmak istenen kimlik BAŞKA bir hesaba ait; anonim hesap olduğu gibi
/// duruyor, hiçbir şey değişmedi.
///
/// Servis bu noktada durur: o hesaba geçmek anonim hesaptaki her şeyi
/// erişilmez kılar ve bunun doğru olup olmadığını yalnız kullanıcı bilir.
/// Arayüz ya [signInAnyway] ile o hesaba girer ya da hiçbir şey yapmaz —
/// ikinci yol her zaman güvenli, kullanıcı olduğu yerde kalır.
///
/// `UserCredential` yerine `Future<void>` taşıyor: testte Firebase tipleri
/// üretilemiyor ve hiçbir çağıran dönen kimliği kullanmıyor.
class AccountConflict implements Exception {
  AccountConflict({required this.code, required this.signInAnyway});

  /// Firebase kodu (`credential-already-in-use` / `email-already-in-use`).
  final String code;

  /// Mevcut hesaba GİR — anonim oturum geri gelmemek üzere gider.
  final Future<void> Function() signInAnyway;

  @override
  String toString() => 'AccountConflict($code)';
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
    'credential-already-in-use' => SocialAuthFailure.differentMethod,
    'operation-not-allowed' ||
    'configuration-not-found' ||
    'invalid-oauth-client-id' ||
    'invalid-oauth-provider' => SocialAuthFailure.notEnabled,
    'network-request-failed' ||
    'too-many-requests' => SocialAuthFailure.network,
    _ => SocialAuthFailure.unknown,
  };
}
