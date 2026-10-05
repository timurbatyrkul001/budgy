import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/auth/sign_in_screen.dart';

import '../support/harness.dart';

/// E-posta girişinde hata kodları AYRI metinler verir.
///
/// Eskiden her `FirebaseAuthException` "e-posta ya da şifre yanlış"
/// olarak çıkıyordu: ağ yokken kullanıcı doğru şifresini değiştirip
/// duruyordu. Firebase Auth testte yok; [SignInActions.email] kancası
/// istenen kodu fırlatıyor. Hesap boş (sahte Firestore) → veri kaybı
/// diyalogu çıkmaz, giriş doğrudan denenir.
void main() {
  final str = Strings.tr;

  Future<void> pumpAndFail(WidgetTester tester, String code) async {
    await pumpBudgyScreen(
      tester,
      SignInScreen(
        onSignedIn: () => fail('giriş başarılı sayılmamalı'),
        actions: SignInActions(
          email: (_, _) async => throw FirebaseAuthException(code: code),
        ),
      ),
      db: FakeFirebaseFirestore(),
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.emailHint),
      'timur@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.passwordHint),
      'hunter22!',
    );
    await tester.tap(find.widgetWithText(FilledButton, str.signInButton));
    await tester.pumpAndSettle();
  }

  /// E-posta alanının kenarlığı kırmızı mı (kimlik hatası işareti).
  bool emailFieldRed(WidgetTester tester) {
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, str.emailHint),
    );
    final border = field.decoration!.enabledBorder as OutlineInputBorder;
    return border.borderSide.color == Ex.red;
  }

  testWidgets('ağ yok → bağlantı metni, "şifre yanlış" DEĞİL', (tester) async {
    await pumpAndFail(tester, 'network-request-failed');
    expect(find.text(str.signInErrorNetwork), findsOneWidget);
    expect(find.text(str.signInError), findsNothing);
    // Alanlar kırmızıya boyanmaz: şifre yanlış değil.
    expect(emailFieldRed(tester), isFalse);
  });

  testWidgets('çok fazla deneme → bekle metni', (tester) async {
    await pumpAndFail(tester, 'too-many-requests');
    expect(find.text(str.signInErrorTooMany), findsOneWidget);
    expect(find.text(str.signInError), findsNothing);
  });

  testWidgets('hesap kapatılmış → devre dışı metni', (tester) async {
    await pumpAndFail(tester, 'user-disabled');
    expect(find.text(str.signInErrorDisabled), findsOneWidget);
    expect(find.text(str.signInError), findsNothing);
  });

  testWidgets('yanlış şifre → eski kimlik metni, alanlar kırmızı', (
    tester,
  ) async {
    await pumpAndFail(tester, 'wrong-password');
    expect(find.text(str.signInError), findsOneWidget);
    expect(emailFieldRed(tester), isTrue);
  });

  testWidgets('yeni birleşik kod invalid-credential → kimlik metni', (
    tester,
  ) async {
    await pumpAndFail(tester, 'invalid-credential');
    expect(find.text(str.signInError), findsOneWidget);
  });

  testWidgets('bozuk e-posta → e-posta metni', (tester) async {
    await pumpAndFail(tester, 'invalid-email');
    expect(find.text(str.invalidEmail), findsOneWidget);
    expect(find.text(str.signInError), findsNothing);
  });

  testWidgets('tanınmayan kod → genel metin', (tester) async {
    await pumpAndFail(tester, 'operation-not-allowed');
    expect(find.text(str.errorGeneric), findsOneWidget);
    expect(find.text(str.signInError), findsNothing);
  });

  testWidgets('hata sonrası düğme yeniden açık, ikinci deneme metni değiştirir',
      (tester) async {
    var calls = 0;
    await pumpBudgyScreen(
      tester,
      SignInScreen(
        onSignedIn: () {},
        actions: SignInActions(
          email: (_, _) async {
            calls++;
            throw FirebaseAuthException(
              code: calls == 1 ? 'network-request-failed' : 'wrong-password',
            );
          },
        ),
      ),
      db: FakeFirebaseFirestore(),
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.emailHint),
      'timur@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.passwordHint),
      'hunter22!',
    );
    await tester.tap(find.widgetWithText(FilledButton, str.signInButton));
    await tester.pumpAndSettle();
    expect(find.text(str.signInErrorNetwork), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, str.signInButton));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text(str.signInErrorNetwork), findsNothing);
    expect(find.text(str.signInError), findsOneWidget);
  });
}
