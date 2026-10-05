import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/auth/email_verify_screen.dart';

import '../support/harness.dart';

/// E-posta doğrulama ekranı.
///
/// Eskiden gönderim hatası boş `catch`te yutuluyor ve "gönderildi" HER
/// zaman yazılıyordu — ağ yokken kullanıcı hiç gitmemiş bir postayı
/// bekliyordu. Firebase testte yok; gönderim ve kontrol
/// [EmailVerifyScreen.sendVerification] / [EmailVerifyScreen.checkVerified]
/// ile sahteleniyor. Ekran açılır açılmaz bir kez kendisi gönderir (1. çağrı).
void main() {
  final str = Strings.tr;
  const email = 'timur@example.com';

  /// Kullanıcı ekranda kaldıkça yoklama ve bekleme sayacı çalışır; testin
  /// sonunda ağacı söküp zamanlayıcıları kapatıyoruz.
  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  Future<int Function()> pumpVerify(
    WidgetTester tester, {
    required Future<void> Function(int call) send,
    Future<bool> Function()? check,
    VoidCallback? onVerified,
  }) async {
    var calls = 0;
    await pumpBudgyScreen(
      tester,
      EmailVerifyScreen(
        email: email,
        onVerified: onVerified ?? () => fail('doğrulanmış sayılmamalı'),
        sendVerification: () => send(++calls),
        checkVerified: check ?? () async => false,
      ),
      db: FakeFirebaseFirestore(),
    );
    return () => calls;
  }

  TextButton resendButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.byType(TextButton));

  FilledButton doneButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  group('gönderim', () {
    testWidgets('açılışta posta gider; başarıda bekleme sayacı başlar',
        (tester) async {
      final calls = await pumpVerify(tester, send: (_) async {});
      expect(calls(), 1);
      // Açılıştaki gönderimde şerit yok (kullanıcı bir şey yapmadı).
      expect(find.text(str.verifySent), findsNothing);
      // 45 sn'lik bekleme: "Tekrar gönder" kapalı ve sayaç görünür.
      expect(resendButton(tester).onPressed, isNull);
      expect(find.text('${str.verifyResend} (45s)'), findsOneWidget);
      await tearDownTree(tester);
    });

    testWidgets('açılışta ağ yok → bağlantı metni, "gönderildi" DEĞİL, '
        'bekleme başlamaz', (tester) async {
      await pumpVerify(
        tester,
        send: (_) async =>
            throw FirebaseAuthException(code: 'network-request-failed'),
      );
      expect(find.text(str.signInErrorNetwork), findsOneWidget);
      expect(find.text(str.verifySent), findsNothing);
      // Posta gitmedi: kullanıcı hemen yeniden deneyebilmeli.
      expect(resendButton(tester).onPressed, isNotNull);
      expect(find.text(str.verifyResend), findsOneWidget);
      await tearDownTree(tester);
    });

    testWidgets('tekrar gönder başarılı → "gönderildi" şeridi', (tester) async {
      final calls = await pumpVerify(tester, send: (_) async {});
      // Bekleme süresini geç.
      await tester.pump(const Duration(seconds: 46));
      expect(resendButton(tester).onPressed, isNotNull);

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(calls(), 2);
      expect(find.text(str.verifySent), findsOneWidget);
      expect(resendButton(tester).onPressed, isNull, reason: 'sayaç başladı');
      await tearDownTree(tester);
    });

    for (final (code, expected) in [
      ('network-request-failed', str.signInErrorNetwork),
      ('too-many-requests', str.signInErrorTooMany),
      ('user-disabled', str.signInErrorDisabled),
      ('user-not-found', str.verifySendFailed),
      ('internal-error', str.verifySendFailed),
    ]) {
      testWidgets('tekrar gönder $code → "$expected", "gönderildi" DEĞİL',
          (tester) async {
        await pumpVerify(
          tester,
          send: (call) async {
            if (call == 1) return;
            throw FirebaseAuthException(
              code: code,
              message: 'RAW FIREBASE MESSAGE',
            );
          },
        );
        await tester.pump(const Duration(seconds: 46));
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
        expect(find.text(str.verifySent), findsNothing);
        // Ham Firebase metni/kodu ekrana sızmaz.
        expect(find.textContaining('RAW FIREBASE'), findsNothing);
        expect(find.textContaining(code), findsNothing);
        // Posta gitmedi: bekleme başlamaz, düğme açık.
        expect(resendButton(tester).onPressed, isNotNull);
        await tearDownTree(tester);
      });
    }

    testWidgets('gönderim sürerken düğme kapalı; çift dokunuş ikinci posta '
        'yollamaz', (tester) async {
      final gate = Completer<void>();
      final calls = await pumpVerify(
        tester,
        send: (call) {
          // Açılıştaki gönderim düşsün ki bekleme başlamasın ve düğme
          // açık kalsın; sonrakiler biz bırakana kadar asılı.
          if (call == 1) {
            throw FirebaseAuthException(code: 'network-request-failed');
          }
          return gate.future;
        },
      );
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(resendButton(tester).onPressed, isNull);
      await tester.tap(find.byType(TextButton), warnIfMissed: false);
      await tester.pump();
      expect(calls(), 2, reason: '1 açılış + 1 kullanıcı; ikinci dokunuş yok');

      gate.complete();
      await tester.pumpAndSettle();
      await tearDownTree(tester);
    });
  });

  group('"Doğruladım"', () {
    testWidgets('henüz değil → bilgi şeridi, ekran yerinde', (tester) async {
      await pumpVerify(tester, send: (_) async {});
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(str.verifyNotYet), findsOneWidget);
      await tearDownTree(tester);
    });

    testWidgets('doğrulanmış → onVerified', (tester) async {
      var verified = 0;
      await pumpVerify(
        tester,
        send: (_) async {},
        check: () async => true,
        onVerified: () => verified++,
      );
      // Açılıştan 4 sn sonra arka plan yoklaması zaten yakalar; biz
      // düğmeden gidiyoruz.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(verified, 1);
      await tearDownTree(tester);
    });

    testWidgets('kontrol ağ yüzünden düşerse kullanıcı sebebini görür',
        (tester) async {
      await pumpVerify(
        tester,
        send: (_) async {},
        check: () async =>
            throw FirebaseAuthException(code: 'network-request-failed'),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(str.signInErrorNetwork), findsOneWidget);
      expect(find.text(str.verifyNotYet), findsNothing);
      // Düğme yeniden açık.
      expect(doneButton(tester).onPressed, isNotNull);
      await tearDownTree(tester);
    });

    testWidgets('arka plan yoklaması düşerse SESSİZ kalır', (tester) async {
      await pumpVerify(
        tester,
        send: (_) async {},
        check: () async =>
            throw FirebaseAuthException(code: 'network-request-failed'),
      );
      // İki yoklama turu geçsin.
      await tester.pump(const Duration(seconds: 9));
      expect(find.byType(SnackBar), findsNothing);
      await tearDownTree(tester);
    });

    testWidgets('kontrol sürerken düğme kapalı; çift dokunuş ikinci reload '
        'yapmaz', (tester) async {
      final gate = Completer<bool>();
      var checks = 0;
      await pumpVerify(
        tester,
        send: (_) async {},
        check: () {
          checks++;
          return gate.future;
        },
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(doneButton(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(checks, 1);

      gate.complete(false);
      await tester.pumpAndSettle();
      expect(doneButton(tester).onPressed, isNotNull);
      await tearDownTree(tester);
    });
  });
}
