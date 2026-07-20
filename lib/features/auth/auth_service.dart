import 'package:firebase_auth/firebase_auth.dart';

/// Sosyal giriş: Google + Apple — Firebase'in kendi federated akışı ile
/// (ekstra native paket yok). Anonim hesap varsa ona BAĞLAR (veri korunur),
/// yoksa giriş yapar.
class AuthService {
  static Future<UserCredential> signInWithGoogle() {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    return _run(provider);
  }

  static Future<UserCredential> signInWithApple() {
    final provider = AppleAuthProvider()..addScope('email');
    return _run(provider);
  }

  /// Anonim hesabı varsa sağlayıcıyı BAĞLA (veri kalır); değilse giriş yap.
  static Future<UserCredential> _run(AuthProvider provider) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        return await user.linkWithProvider(provider);
      } on FirebaseAuthException catch (e) {
        // Bu sosyal hesap zaten başka bir Firebase hesabına bağlı.
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          return auth.signInWithProvider(provider);
        }
        rethrow;
      }
    }
    return auth.signInWithProvider(provider);
  }
}
