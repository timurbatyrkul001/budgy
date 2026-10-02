import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/auth/forget_password_screen.dart';
import 'package:kopilka_app/features/settings/settings_hub.dart';
import 'package:kopilka_app/features/settings/settings_signin_security_screen.dart';

import '../support/harness.dart';

/// Giriş ve güvenlik ekranı.
///
/// FirebaseAuth testte yok; ekran [SignInSnapshot] ile besleniyor ve
/// bağlama akışı [SettingsSignInSecurityScreen.connect] ile sahteleniyor.
/// Testler ekranın yalnız GERÇEKTE olanı gösterdiğini sabitliyor: bağlı
/// olmayan sağlayıcıya eylem satırı, e-postasıza kart yok, şifresize kapı yok.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final lastSignIn = DateTime(2026, 9, 29, 13, 35);

  const googleUser = SignInSnapshot(
    providerIds: {'google.com'},
    email: 'timur@example.com',
    isAnonymous: false,
  );
  const passwordUser = SignInSnapshot(
    providerIds: {'password'},
    email: 'timur@example.com',
    isAnonymous: false,
  );
  // Apple ile girmiş, e-postasını gizlemiş kullanıcı: providerData var,
  // email yok.
  const hiddenAppleUser = SignInSnapshot(
    providerIds: {'apple.com'},
    isAnonymous: false,
  );
  const anon = SignInSnapshot();

  Future<void> pump(
    WidgetTester tester,
    SignInSnapshot snap, {
    AppLanguage language = AppLanguage.tr,
    bool showApple = true,
    Size size = const Size(360, 800),
    Future<SignInSnapshot> Function(SignInProvider)? connect,
  }) =>
      pumpBudgyScreen(
        tester,
        SettingsSignInSecurityScreen(
            initial: snap, showApple: showApple, connect: connect),
        db: FakeFirebaseFirestore(),
        language: language,
        logicalSize: size,
      );

  group('giriş yöntemleri', () {
    testWidgets('bağlı Google: "Bağlı" rozeti var, "Google\'ı bağla" yok',
        (tester) async {
      await pump(tester, googleUser.copyWithLastSignIn(lastSignIn));
      final rs = RS.tr;
      expect(find.text('Google'), findsOneWidget);
      expect(find.text(rs.signinConnected), findsOneWidget);
      expect(find.text(rs.signinConnectGoogle), findsNothing);
      // "Birincil" diye bir şey yazılmıyor — Firebase'de o kavram yok.
      expect(find.textContaining('Birincil'), findsNothing);
      // Üye paragrafı, anonim paragrafı değil.
      expect(find.text(rs.signinBodyMember), findsOneWidget);
      expect(find.text(rs.signinBodyAnon), findsNothing);
    });

    testWidgets('bağlı olmayan Apple → eylem satırı görünür', (tester) async {
      await pump(tester, googleUser);
      expect(find.text(RS.tr.signinConnectApple), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('Apple platformu değilse Apple bağla satırı hiç yok',
        (tester) async {
      await pump(tester, googleUser, showApple: false);
      expect(find.text(RS.tr.signinConnectApple), findsNothing);
    });

    testWidgets('bağlama başarılı → ekran taze fotoğrafı çizer',
        (tester) async {
      SignInProvider? asked;
      await pump(tester, anon, connect: (p) async {
        asked = p;
        return googleUser;
      });
      await tester.tap(find.text(RS.tr.signinConnectGoogle));
      await tester.pumpAndSettle();
      expect(asked, SignInProvider.google);
      expect(find.text(RS.tr.signinConnectGoogle), findsNothing);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text(RS.tr.signinConnected), findsOneWidget);
      // Bağlanınca e-posta kartı da belirir.
      expect(find.text('timur@example.com'), findsOneWidget);
    });
  });

  group('anonim', () {
    testWidgets('özel paragraf + iki eylem satırı, rozet ve e-posta yok',
        (tester) async {
      await pump(tester, anon);
      final rs = RS.tr;
      expect(find.text(rs.signinBodyAnon), findsOneWidget);
      expect(find.text(rs.signinBodyMember), findsNothing);
      expect(find.text(rs.signinConnectGoogle), findsOneWidget);
      expect(find.text(rs.signinConnectApple), findsOneWidget);
      expect(find.text(rs.signinConnected), findsNothing);
      expect(find.text(rs.signinEmailLabel), findsNothing);
      // Son giriş yok → satır yok.
      expect(find.textContaining('Son giriş'), findsNothing);
    });
  });

  group('e-posta kartı', () {
    testWidgets('e-posta yoksa kart çizilmez', (tester) async {
      await pump(tester, hiddenAppleUser);
      expect(find.text(RS.tr.signinEmailLabel), findsNothing);
      expect(find.byIcon(Icons.mail_rounded), findsNothing);
      // Apple bağlı olarak görünür.
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('şifre yok → satır dokunulmaz, ok yok', (tester) async {
      await pump(tester, googleUser);
      final rs = RS.tr;
      expect(find.text('timur@example.com'), findsOneWidget);
      expect(find.text(rs.signinEmailAccount), findsOneWidget);
      expect(find.text(rs.signinEmailChangePassword), findsNothing);
      final row = tester.widget<SettingsRow>(
          find.widgetWithText(SettingsRow, 'timur@example.com'));
      expect(row.onTap, isNull);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('şifre var → satır şifre sıfırlamaya götürür', (tester) async {
      await pump(tester, passwordUser);
      final rs = RS.tr;
      expect(find.text(rs.signinEmailPassword), findsOneWidget);
      expect(find.text(rs.signinEmailChangePassword), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.text('timur@example.com'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgetPasswordScreen), findsOneWidget);
    });
  });

  group('son giriş', () {
    testWidgets('lastSignInTime null → satır yok', (tester) async {
      await pump(tester, googleUser, language: AppLanguage.en);
      expect(find.textContaining('Last sign-in'), findsNothing);
    });

    testWidgets('lastSignInTime var → yerel biçimde yazılır', (tester) async {
      await pump(tester, googleUser.copyWithLastSignIn(lastSignIn),
          language: AppLanguage.en);
      expect(find.text('Last sign-in: 29 Sep 2026, 13:35'), findsOneWidget);
    });
  });

  // Dar ekran × üç dil, en kalabalık iki hâl: anonim (iki eylem satırı) ve
  // şifreli üye (üç sağlayıcı satırı + son giriş + e-posta kartı).
  final full = SignInSnapshot(
    providerIds: const {'google.com', 'apple.com', 'password'},
    email: 'cok.uzun.bir.eposta.adresi.deneme@example-domain.com',
    lastSignIn: lastSignIn,
    isAnonymous: false,
  );
  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      for (final (name, snap) in [('anonim', anon), ('tam üye', full)]) {
        testWidgets('$name · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
          await pump(tester, snap,
              language: lang, size: Size(width, 800));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

extension on SignInSnapshot {
  SignInSnapshot copyWithLastSignIn(DateTime t) => SignInSnapshot(
        providerIds: providerIds,
        email: email,
        lastSignIn: t,
        isAnonymous: isAnonymous,
      );
}
