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

  group('classifyEmailSignInError', () {
    // Giriş ekranı eskiden HER kodu "e-posta ya da şifre yanlış" sayıyordu.
    // Ağ, deneme sınırı ve kapatılmış hesap artık ayrı; yalnız gerçekten
    // kimlikle ilgili olanlar credentials.
    test('kimlik hataları — Firebase\'in eski ve yeni kodları', () {
      for (final code in const [
        'wrong-password',
        'user-not-found',
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
        'invalid-login-credentials',
      ]) {
        expect(
          classifyEmailSignInError(code),
          EmailSignInFailure.credentials,
          reason: code,
        );
      }
    });

    test('ağ, deneme sınırı, kapatılmış hesap, bozuk e-posta ayrı ayrı', () {
      expect(
        classifyEmailSignInError('network-request-failed'),
        EmailSignInFailure.network,
      );
      expect(
        classifyEmailSignInError('too-many-requests'),
        EmailSignInFailure.tooManyRequests,
      );
      expect(
        classifyEmailSignInError('user-disabled'),
        EmailSignInFailure.disabled,
      );
      expect(
        classifyEmailSignInError('invalid-email'),
        EmailSignInFailure.invalidEmail,
      );
    });

    test('tanınmayan kod unknown — şifre hatası DEĞİL', () {
      expect(
        classifyEmailSignInError('operation-not-allowed'),
        EmailSignInFailure.unknown,
      );
      expect(classifyEmailSignInError(''), EmailSignInFailure.unknown);
    });
  });
}
