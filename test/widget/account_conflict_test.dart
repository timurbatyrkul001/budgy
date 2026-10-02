import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/auth/auth_service.dart';
import 'package:kopilka_app/features/auth/data_at_risk.dart';
import 'package:kopilka_app/features/auth/sign_in_screen.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/onboarding/onboarding_save.dart';
import 'package:kopilka_app/features/onboarding/widgets/budgy_money_envelope.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Veri kaybı kapısı: anonim hesapta kayıt varken başka bir hesaba
/// SORMADAN geçilmez.
///
/// Firebase Auth testte yok; [AuthService] yerine [SignInActions] /
/// [SaveBookPage.connectGoogle] kancalarıyla [AccountConflict] fırlatan
/// sahteler kullanılıyor. "Veri var mı" sorusu ya sahte Firestore'dan
/// ([DataAtRiskProbe], gerçek sorgu) ya da bellekteki akışlardan
/// ([anonymousHasData], harness override'ları) cevaplanıyor — ikisi de
/// gerçek kod yolu.
void main() {
  final str = Strings.tr;
  final rs = RS.tr;

  /// Kimlik başka hesabın: [signInAnyway] çağrılırsa [log]'a yazar.
  AccountConflict conflictOf(List<String> log, {Object? thenThrow}) =>
      AccountConflict(
        code: 'credential-already-in-use',
        signInAnyway: () async {
          log.add('signInAnyway');
          if (thenThrow != null) throw thenThrow;
        },
      );

  /// Sahte Firestore'a tek bir işlem yazar — "kaybedilecek bir şey var".
  Future<FakeFirebaseFirestore> dbWithTransaction() async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/$testUid/transactions/t1').set({
      'type': 'expense',
      'amount': 120,
      'date': DateTime(2026, 9, 20),
    });
    return db;
  }

  group('SignInScreen · sosyal giriş', () {
    Future<void> pumpSignIn(
      WidgetTester tester, {
      required FakeFirebaseFirestore db,
      required SignInActions actions,
      required VoidCallback onSignedIn,
    }) => pumpBudgyScreen(
      tester,
      SignInScreen(onSignedIn: onSignedIn, actions: actions),
      db: db,
    );

    testWidgets('çakışma + kayıt var → diyalog çıkar, henüz geçilmez', (
      tester,
    ) async {
      final log = <String>[];
      var signedIn = false;
      await pumpSignIn(
        tester,
        db: await dbWithTransaction(),
        actions: SignInActions(google: () async => throw conflictOf(log)),
        onSignedIn: () => signedIn = true,
      );

      await tester.tap(find.text(str.continueGoogle));
      await tester.pumpAndSettle();

      expect(find.text(rs.conflictTitle), findsOneWidget);
      expect(find.text(rs.conflictBody), findsOneWidget);
      expect(find.text(rs.conflictSignIn), findsOneWidget);
      expect(find.text(rs.conflictKeep), findsOneWidget);
      // Diyalog AÇIKKEN hiçbir şey değişmedi.
      expect(log, isEmpty);
      expect(signedIn, isFalse);
    });

    testWidgets('çakışma + hesap boş → sormadan o hesaba girer', (
      tester,
    ) async {
      final log = <String>[];
      var signedIn = false;
      await pumpSignIn(
        tester,
        db: FakeFirebaseFirestore(),
        actions: SignInActions(google: () async => throw conflictOf(log)),
        onSignedIn: () => signedIn = true,
      );

      await tester.tap(find.text(str.continueGoogle));
      await tester.pumpAndSettle();

      expect(find.text(rs.conflictTitle), findsNothing);
      expect(log, ['signInAnyway']);
      expect(signedIn, isTrue);
    });

    testWidgets('vazgeç → hiçbir şey olmaz: ekran yerinde, şerit yok', (
      tester,
    ) async {
      final log = <String>[];
      var signedIn = false;
      await pumpSignIn(
        tester,
        db: await dbWithTransaction(),
        actions: SignInActions(google: () async => throw conflictOf(log)),
        onSignedIn: () => signedIn = true,
      );

      await tester.tap(find.text(str.continueGoogle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(rs.conflictKeep));
      await tester.pumpAndSettle();

      expect(find.text(rs.conflictTitle), findsNothing);
      expect(log, isEmpty);
      expect(signedIn, isFalse);
      expect(find.text(str.signInTitle), findsNWidgets(2));
      // Vazgeçmek hata değil: kırmızı şerit çıkmaz.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('dışarı dokunarak kapatmak da vazgeçmek sayılır', (
      tester,
    ) async {
      final log = <String>[];
      await pumpSignIn(
        tester,
        db: await dbWithTransaction(),
        actions: SignInActions(google: () async => throw conflictOf(log)),
        onSignedIn: () {},
      );

      await tester.tap(find.text(str.continueGoogle));
      await tester.pumpAndSettle();
      // Bariyere (diyalogun dışına) dokun.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text(rs.conflictTitle), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('onayla → o hesaba girilir ve içeri alınır', (tester) async {
      final log = <String>[];
      var signedIn = false;
      await pumpSignIn(
        tester,
        db: await dbWithTransaction(),
        actions: SignInActions(apple: () async => throw conflictOf(log)),
        onSignedIn: () => signedIn = true,
      );

      await tester.tap(find.text(str.continueApple));
      await tester.pumpAndSettle();
      await tester.tap(find.text(rs.conflictSignIn));
      await tester.pumpAndSettle();

      expect(find.text(rs.conflictTitle), findsNothing);
      expect(log, ['signInAnyway']);
      expect(signedIn, isTrue);
    });

    testWidgets('çakışma yok → doğrudan girer, diyalog yok', (tester) async {
      var signedIn = false;
      await pumpSignIn(
        tester,
        db: await dbWithTransaction(),
        actions: SignInActions(google: () async {}),
        onSignedIn: () => signedIn = true,
      );

      await tester.tap(find.text(str.continueGoogle));
      await tester.pumpAndSettle();

      expect(find.text(rs.conflictTitle), findsNothing);
      expect(signedIn, isTrue);
    });
  });

  group('SignInScreen · e-posta/şifre', () {
    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextField, str.emailHint),
        'timur@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, str.passwordHint),
        'hunter22!',
      );
      await tester.tap(find.widgetWithText(FilledButton, str.signInButton));
      // Diyalog açıkken düğmedeki yükleniyor göstergesi dönmeye devam
      // ediyor; `pumpAndSettle` hiç durulmaz. Sorgu + diyalog için birkaç
      // kare yeter.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // E-posta girişi BAĞLAMAZ, hesabı değiştirir: Firebase'de anonim
    // kullanıcıya e-posta bağlamak, adres yoksa yeni hesap AÇAR — "Giriş
    // yap" ekranında adresi yanlış yazan biri sessizce yanlış adrese
    // kaydolurdu. Bu yüzden burada çakışma sinyali beklenmiyor: kayıt
    // varsa uyarı ÖNCEDEN çıkıyor.
    testWidgets('kayıt varsa giriş denenmeden ÖNCE sorulur', (tester) async {
      final seen = <(String, String)>[];
      var signedIn = false;
      await pumpBudgyScreen(
        tester,
        SignInScreen(
          onSignedIn: () => signedIn = true,
          actions: SignInActions(
            email: (email, password) async {
              seen.add((email, password));
            },
          ),
        ),
        db: await dbWithTransaction(),
      );

      await fillAndSubmit(tester);

      // Önemli olan bu: diyalog çıkana kadar giriş DENENMEDİ.
      expect(find.text(rs.conflictTitle), findsOneWidget);
      expect(seen, isEmpty);
      expect(signedIn, isFalse);

      await tester.tap(find.text(rs.conflictSignIn));
      await tester.pumpAndSettle();
      expect(seen, [('timur@example.com', 'hunter22!')]);
      expect(signedIn, isTrue);
    });

    testWidgets('vazgeçerse giriş hiç denenmez', (tester) async {
      final seen = <(String, String)>[];
      var signedIn = false;
      await pumpBudgyScreen(
        tester,
        SignInScreen(
          onSignedIn: () => signedIn = true,
          actions: SignInActions(email: (e, p) async => seen.add((e, p))),
        ),
        db: await dbWithTransaction(),
      );

      await fillAndSubmit(tester);
      await tester.tap(find.text(rs.conflictKeep));
      await tester.pumpAndSettle();

      expect(seen, isEmpty);
      expect(signedIn, isFalse);
      // İptal hata değil: kırmızı şerit yok, kullanıcı ekranda kalıyor.
      expect(find.text(str.signInError), findsNothing);
      expect(find.text(str.signInTitle), findsNWidgets(2));
    });

    testWidgets('onayladı ama şifre yanlış → hata metni, anonim kalır', (
      tester,
    ) async {
      var signedIn = false;
      await pumpBudgyScreen(
        tester,
        SignInScreen(
          onSignedIn: () => signedIn = true,
          actions: SignInActions(
            email: (_, _) async =>
                throw FirebaseAuthException(code: 'wrong-password'),
          ),
        ),
        db: await dbWithTransaction(),
      );

      await fillAndSubmit(tester);
      await tester.tap(find.text(rs.conflictSignIn));
      await tester.pumpAndSettle();

      expect(signedIn, isFalse);
      expect(find.text(str.signInError), findsOneWidget);
      expect(find.text(str.signInTitle), findsNWidgets(2));
    });

    testWidgets('kaybedilecek kayıt yoksa sormadan girer', (tester) async {
      var signedIn = false;
      await pumpBudgyScreen(
        tester,
        SignInScreen(
          onSignedIn: () => signedIn = true,
          actions: SignInActions(email: (_, _) async {}),
        ),
        db: FakeFirebaseFirestore(),
      );

      await fillAndSubmit(tester);

      expect(find.text(rs.conflictTitle), findsNothing);
      expect(signedIn, isTrue);
    });
  });

  group('SaveBookPage (onboarding sonu)', () {
    Future<void> pumpSave(
      WidgetTester tester, {
      required Future<void> Function() connectGoogle,
      required VoidCallback onDone,
      required Future<bool> Function() hasData,
    }) => pumpBudgyScreen(
      tester,
      Scaffold(
        body: SaveBookPage(
          onDone: onDone,
          connectGoogle: connectGoogle,
          hasData: hasData,
        ),
      ),
      db: FakeFirebaseFirestore(),
    );

    testWidgets(
      'çakışma + kayıt → diyalog; vazgeç → sayfa yerinde, düğme açık',
      (tester) async {
        final log = <String>[];
        var done = false;
        await pumpSave(
          tester,
          connectGoogle: () async => throw conflictOf(log),
          onDone: () => done = true,
          hasData: () async => true,
        );

        await tester.tap(find.text(rs.saveGoogle));
        await tester.pumpAndSettle();
        expect(find.text(rs.conflictTitle), findsOneWidget);

        await tester.tap(find.text(rs.conflictKeep));
        await tester.pumpAndSettle();
        expect(find.text(rs.conflictTitle), findsNothing);
        expect(log, isEmpty);
        expect(done, isFalse);
        // Hata metni de yok: vazgeçmek hata değil.
        expect(find.text(rs.saveErrDifferent), findsNothing);
        expect(find.text(rs.saveFailed), findsNothing);

        // Düğme yeniden dokunulabilir (meşgul kilidi açıldı).
        await tester.tap(find.text(rs.saveGoogle));
        await tester.pumpAndSettle();
        expect(find.text(rs.conflictTitle), findsOneWidget);
      },
    );

    testWidgets(
      'onayla → o hesaba girilir, zarf mühürlenir, onboarding biter',
      (tester) async {
        final log = <String>[];
        var done = false;
        await pumpSave(
          tester,
          connectGoogle: () async => throw conflictOf(log),
          onDone: () => done = true,
          hasData: () async => true,
        );

        await tester.tap(find.text(rs.saveGoogle));
        await tester.pumpAndSettle();
        await tester.tap(find.text(rs.conflictSignIn));
        await tester.pump();
        await tester.pump(BudgyMoneyEnvelope.sealDuration);
        await tester.pumpAndSettle();

        expect(log, ['signInAnyway']);
        expect(done, isTrue);
      },
    );

    testWidgets('çakışma + boş hesap → sormadan girer', (tester) async {
      final log = <String>[];
      var done = false;
      await pumpSave(
        tester,
        connectGoogle: () async => throw conflictOf(log),
        onDone: () => done = true,
        hasData: () async => false,
      );

      await tester.tap(find.text(rs.saveGoogle));
      await tester.pump();
      await tester.pump(BudgyMoneyEnvelope.sealDuration);
      await tester.pumpAndSettle();

      expect(find.text(rs.conflictTitle), findsNothing);
      expect(log, ['signInAnyway']);
      expect(done, isTrue);
    });
  });

  group('anonymousHasData · bellekteki akışlar', () {
    /// Üç akışı da izleyen küçük ekran; düğme [anonymousHasData]'yı çağırır.
    Future<bool> ask(
      WidgetTester tester, {
      List<Tx> transactions = const [],
      List<Envelope> envelopes = const [],
      double cashBalance = 0,
    }) async {
      bool? answer;
      await pumpBudgyScreen(
        tester,
        _HasDataProbe(onAnswer: (v) => answer = v),
        db: FakeFirebaseFirestore(),
        transactions: transactions,
        envelopes: envelopes,
        cashBalance: cashBalance,
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(answer, isNotNull);
      return answer!;
    }

    final preset = testEnvelope(id: 'e1', presetKey: 'food');
    final custom = testEnvelope(id: 'e2', name: 'Kedi maması');
    final tx = Tx(
      id: 't1',
      type: TxType.expense,
      amount: 40,
      date: DateTime(2026, 9, 20),
    );

    testWidgets('yalnız hazır kategoriler, işlem yok, bakiye 0 → yok', (
      tester,
    ) async {
      expect(await ask(tester, envelopes: [preset]), isFalse);
    });

    testWidgets('bir işlem → var', (tester) async {
      expect(
        await ask(tester, envelopes: [preset], transactions: [tx]),
        isTrue,
      );
    });

    testWidgets('elle açılmış kategori → var', (tester) async {
      expect(await ask(tester, envelopes: [preset, custom]), isTrue);
    });

    testWidgets('sıfır olmayan bakiye → var', (tester) async {
      expect(await ask(tester, cashBalance: 250), isTrue);
    });
  });
}

class _HasDataProbe extends ConsumerWidget {
  const _HasDataProbe({required this.onAnswer});

  final void Function(bool) onAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gerçek uygulamada ana ekranın yaptığı: akışlar bellekte, cevap ücretsiz.
    ref.watch(journalProvider);
    ref.watch(envelopesProvider);
    ref.watch(cashBalanceProvider);
    return Scaffold(
      body: TextButton(
        onPressed: () async => onAnswer(await anonymousHasData(ref)),
        child: const Text('ask'),
      ),
    );
  }
}
