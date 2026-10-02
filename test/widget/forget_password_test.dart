import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/auth/forget_password_screen.dart';

import '../support/harness.dart';

/// Şifre sıfırlama ekranı.
///
/// Bu ekran bir dönem yalnızca "mailini kontrol et" dialogunu açıyor, hiçbir
/// mail yollamıyordu. Testler gönderimin gerçekten tetiklendiğini ve hata
/// yollarının kullanıcıya anlaşılır metinle döndüğünü sabitliyor. Firebase
/// testte başlatılamadığı için gönderim `sendResetEmail` ile sahteleniyor.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  const email = 'timur@example.com';

  Future<List<String>> pumpForget(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.tr,
    Size size = const Size(360, 800),
    Object? throwError,
  }) async {
    final sent = <String>[];
    await pumpBudgyScreen(
      tester,
      ForgetPasswordScreen(
        onDone: () {},
        sendResetEmail: (e) async {
          sent.add(e);
          if (throwError != null) throw throwError;
        },
      ),
      db: FakeFirebaseFirestore(),
      language: language,
      logicalSize: size,
    );
    return sent;
  }

  FilledButton continueButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  Future<void> typeAndSubmit(WidgetTester tester, [String value = email]) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('geçersiz e-posta ile buton kapalı', (tester) async {
    final sent = await pumpForget(tester);
    expect(continueButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'timur@');
    await tester.pump();
    expect(continueButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), email);
    await tester.pump();
    expect(continueButton(tester).onPressed, isNotNull);
    expect(sent, isEmpty, reason: 'butona basılmadan mail gitmemeli');
  });

  testWidgets('geçerli e-posta → gönderim tetiklenir ve dialog açılır',
      (tester) async {
    final sent = await pumpForget(tester);
    await typeAndSubmit(tester);

    expect(sent, [email]);
    expect(find.text(Strings.tr.checkEmailTitle), findsOneWidget);
    expect(
      find.text(tpl(Strings.tr.checkEmailBody, {'email': email})),
      findsOneWidget,
    );
  });

  testWidgets('gönderim sürerken buton kilitlenir ve yükleniyor gösterir',
      (tester) async {
    var calls = 0;
    // Elle tamamlanan future: ekran biz bırakana kadar "gönderiliyor"
    // hâlinde kalır (Future.delayed asılı timer bırakıp testi düşürür).
    final gate = Completer<void>();
    await pumpBudgyScreen(
      tester,
      ForgetPasswordScreen(
        onDone: () {},
        sendResetEmail: (_) {
          calls++;
          return gate.future;
        },
      ),
      db: FakeFirebaseFirestore(),
    );
    await tester.enterText(find.byType(TextField), email);
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1, reason: 'ikinci dokunuş ikinci mail yollamamalı');

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(Strings.tr.checkEmailTitle), findsOneWidget);
  });

  testWidgets('ağ hatası → anlaşılır mesaj, dialog yok, çökme yok',
      (tester) async {
    await pumpForget(
      tester,
      throwError: FirebaseAuthException(code: 'network-request-failed'),
    );
    await typeAndSubmit(tester);

    expect(find.text(RS.tr.saveErrOffline), findsOneWidget);
    expect(find.text(Strings.tr.checkEmailTitle), findsNothing);
    // Ham Firebase kodu ekrana sızmamalı.
    expect(find.textContaining('network-request-failed'), findsNothing);
    // Hata sonrası buton tekrar açık — kullanıcı yeniden deneyebilmeli.
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('user-not-found → başarı gibi davranır (e-posta sızdırmaz)',
      (tester) async {
    final sent = await pumpForget(
      tester,
      throwError: FirebaseAuthException(code: 'user-not-found'),
    );
    await typeAndSubmit(tester);

    expect(sent, [email]);
    expect(find.text(Strings.tr.checkEmailTitle), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('too-many-requests → bekle mesajı', (tester) async {
    await pumpForget(
      tester,
      throwError: FirebaseAuthException(code: 'too-many-requests'),
    );
    await typeAndSubmit(tester);
    expect(find.text(RS.tr.resetTooMany), findsOneWidget);
  });

  testWidgets('bilinmeyen hata → genel mesaj, ham metin yok', (tester) async {
    await pumpForget(
      tester,
      throwError: FirebaseAuthException(
        code: 'internal-error',
        message: 'RAW FIREBASE MESSAGE',
      ),
    );
    await typeAndSubmit(tester);
    expect(find.text(Strings.tr.errorGeneric), findsOneWidget);
    expect(find.textContaining('RAW FIREBASE'), findsNothing);
  });

  testWidgets('dialogdaki "Tekrar gönder" maili yeniden yollar',
      (tester) async {
    final sent = await pumpForget(tester);
    await typeAndSubmit(tester);

    await tester.tap(find.text(Strings.tr.resend));
    await tester.pumpAndSettle();

    expect(sent, [email, email]);
    // Yeniden gönderimde dialog döngüsü yok, kısa onay var.
    expect(find.text(Strings.tr.checkEmailTitle), findsNothing);
    expect(find.text(RS.tr.resetResent), findsOneWidget);
  });

  // Dar ekranlarda ne form ne dialog taşmamalı; RenderFlex taşması testi
  // kendiliğinden düşürür.
  for (final width in const [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('${width.toInt()}dp ${lang.code}: ekran + dialog taşmaz',
          (tester) async {
        await pumpForget(tester, language: lang, size: Size(width, 800));
        await typeAndSubmit(tester, 'cok.uzun.bir.kullanici.adi@example.com');
        final str = switch (lang) {
          AppLanguage.en => Strings.en,
          AppLanguage.tr => Strings.tr,
          AppLanguage.ru => Strings.ru,
        };
        expect(find.text(str.checkEmailTitle), findsOneWidget);
      });
    }
  }
}
