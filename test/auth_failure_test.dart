import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kopilka_app/features/auth/auth_service.dart';

/// Sosyal giriş hatalarının sınıflandırılması. Buradaki tek kritik kural:
/// kullanıcının sayfayı kapatması HATA DEĞİL — mağaza sürümünde bunu kırmızı
/// uyarı olarak göstermek kullanıcıyı boşuna korkutur.
void main() {
  group('classifySocialAuthError', () {
    test('iptal kodları — platforma göre değişen hepsi', () {
      for (final code in const [
        'web-context-canceled',
        'web-context-cancelled',
        'canceled',
        'user-canceled',
        'popup-closed-by-user',
        'cancelled-popup-request',
        'ERROR_ABORTED_BY_USER',
      ]) {
        expect(
          classifySocialAuthError(FirebaseAuthException(code: code)),
          SocialAuthFailure.canceled,
          reason: code,
        );
      }
      expect(
        classifySocialAuthError(PlatformException(code: 'CANCELED')),
        SocialAuthFailure.canceled,
      );
    });

    test('e-posta başka yöntemle kayıtlı', () {
      for (final code in const [
        'account-exists-with-different-credential',
        'email-already-in-use',
        'credential-already-in-use',
      ]) {
        expect(
          classifySocialAuthError(FirebaseAuthException(code: code)),
          SocialAuthFailure.differentMethod,
          reason: code,
        );
      }
    });

    test('sağlayıcı açık değil — bizim yapılandırma hatamız', () {
      expect(
        classifySocialAuthError(
          FirebaseAuthException(code: 'operation-not-allowed'),
        ),
        SocialAuthFailure.notEnabled,
      );
      expect(
        classifySocialAuthError(
          FirebaseAuthException(code: 'configuration-not-found'),
        ),
        SocialAuthFailure.notEnabled,
      );
    });

    test('ağ', () {
      expect(
        classifySocialAuthError(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        SocialAuthFailure.network,
      );
    });

    test('yerel Google akışının kendi hataları', () {
      expect(
        classifySocialAuthError(
          const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        ),
        SocialAuthFailure.canceled,
      );
      expect(
        classifySocialAuthError(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
        SocialAuthFailure.notEnabled,
      );
      expect(
        classifySocialAuthError(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
          ),
        ),
        SocialAuthFailure.network,
      );
    });

    test('tanınmayan her şey unknown; FirebaseAuthException olmayan da', () {
      expect(
        classifySocialAuthError(FirebaseAuthException(code: 'internal-error')),
        SocialAuthFailure.unknown,
      );
      expect(
        classifySocialAuthError(Exception('bir şey oldu')),
        SocialAuthFailure.unknown,
      );
    });
  });
}
