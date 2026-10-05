import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/auth/auth_gate.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/onboarding/onboarding_flow.dart';
import 'package:kopilka_app/features/root/root_screen.dart';

import '../support/harness.dart';

/// Açılış kapısı: oturum düşerse çıkışsız kalınmaz; veri akışı düşerse
/// onboarding DEĞİL hata gösterilir; yeni kullanıcı onboarding'i görür.
///
/// Firebase testte yok: oturum akışı [authStateProvider] override'ıyla,
/// anonim giriş [AuthGateActions] kancasıyla sahte.
void main() {
  final str = Strings.tr;
  final rs = RS.tr;

  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final user = _FakeUser();

  Future<void> pumpGate(
    WidgetTester tester, {
    required Stream<User?> auth,
    required Stream<bool> Function() onboardingDone,
    List envelopes = const [],
    AuthGateActions actions = const AuthGateActions(
      hasCurrentUser: _alwaysTrue,
      signInAnonymously: _noop,
    ),
  }) async {
    await pumpBudgyScreen(
      tester,
      AuthGate(actions: actions),
      db: FakeFirebaseFirestore(),
      envelopes: envelopes.cast(),
      // Ana ekran 800 px'te sığıyor; kısa tutmak gereksiz.
      extraOverrides: [
        authStateProvider.overrideWith((ref) => auth),
        onboardingDoneProvider.overrideWith((ref) => onboardingDone()),
        // Göç gerçek depoda sahte Firestore'a yazar; burada konu o değil.
        walletMigrationProvider.overrideWith((ref) async {}),
      ],
    );
  }

  group('veri akışı', () {
    testWidgets('onboarding bayrağı akışı düştü → hata ekranı, onboarding YOK',
        (tester) async {
      await pumpGate(
        tester,
        auth: Stream.value(user),
        onboardingDone: () => Stream.error(
          StateError('permission-denied'),
        ),
      );
      expect(find.text(str.dataLoadFailed), findsOneWidget);
      expect(find.text(rs.retry), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.byType(RootScreen), findsNothing);
    });

    testWidgets('Tekrar dene akışı yeniden kurar; düzelince ana ekran', (
      tester,
    ) async {
      var attempts = 0;
      await pumpGate(
        tester,
        auth: Stream.value(user),
        envelopes: [testEnvelope(id: 'e1')],
        onboardingDone: () {
          attempts++;
          // İlk abonelik düşer, ikincisi (Tekrar dene) okur.
          return attempts == 1
              ? Stream.error(StateError('permission-denied'))
              : Stream.value(true);
        },
      );
      expect(find.text(str.dataLoadFailed), findsOneWidget);
      expect(attempts, 1);

      await tester.tap(find.text(rs.retry));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text(str.dataLoadFailed), findsNothing);
      expect(find.byType(RootScreen), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
    });

    testWidgets('yeni kullanıcı (bayrak yok, zarf yok) → onboarding', (
      tester,
    ) async {
      await pumpGate(
        tester,
        auth: Stream.value(user),
        onboardingDone: () => Stream.value(false),
      );
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text(str.dataLoadFailed), findsNothing);
    });

    testWidgets('eski kullanıcı (bayrak var) → ana ekran', (tester) async {
      await pumpGate(
        tester,
        auth: Stream.value(user),
        onboardingDone: () => Stream.value(true),
      );
      expect(find.byType(RootScreen), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
    });

    testWidgets('bayrak yok ama zarf var (eski hesap) → ana ekran', (
      tester,
    ) async {
      await pumpGate(
        tester,
        auth: Stream.value(user),
        envelopes: [testEnvelope(id: 'e1')],
        onboardingDone: () => Stream.value(false),
      );
      expect(find.byType(RootScreen), findsOneWidget);
    });
  });

  group('oturum düşmesi', () {
    testWidgets(
      'oturum null olunca anonim giriş denenir; ağ yoksa Tekrar dene çıkar',
      (tester) async {
        final auth = StreamController<User?>();
        var hasUser = true;
        var attempts = 0;
        await pumpGate(
          tester,
          auth: auth.stream,
          onboardingDone: () => Stream.value(true),
          actions: AuthGateActions(
            hasCurrentUser: () => hasUser,
            signInAnonymously: () async {
              attempts++;
              throw StateError('network-request-failed');
            },
          ),
        );
        auth.add(user);
        await tester.pumpAndSettle();
        expect(find.byType(RootScreen), findsOneWidget);
        expect(attempts, 0);

        // Hesap silindi / çıkış yapıldı: oturum düştü.
        hasUser = false;
        auth.add(null);
        await tester.pumpAndSettle();

        // Eskiden burada düğmesiz "Budgy" ekranı vardı.
        expect(attempts, 1);
        expect(find.text(rs.startupFailed), findsOneWidget);
        expect(find.text(rs.retry), findsOneWidget);
        expect(find.text('Budgy'), findsNothing);

        await tester.tap(find.text(rs.retry));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.text(rs.retry), findsOneWidget);
        await auth.close();
      },
    );

    testWidgets('oturum düştü, anonim giriş başardı → yeni oturumla devam', (
      tester,
    ) async {
      final auth = StreamController<User?>();
      var hasUser = true;
      var attempts = 0;
      await pumpGate(
        tester,
        auth: auth.stream,
        onboardingDone: () => Stream.value(true),
        actions: AuthGateActions(
          hasCurrentUser: () => hasUser,
          signInAnonymously: () async {
            attempts++;
            // Gerçek Firebase'de oturum akışı yeni anonim kullanıcıyı yayar.
            hasUser = true;
            auth.add(user);
          },
        ),
      );
      auth.add(user);
      await tester.pumpAndSettle();

      hasUser = false;
      auth.add(null);
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text(rs.startupFailed), findsNothing);
      expect(find.byType(RootScreen), findsOneWidget);
      await auth.close();
    });
  });
}

bool _alwaysTrue() => true;
Future<void> _noop() async {}

/// Firebase [User]'ın testte var olan tek kısmı: uid ve anonimlik.
class _FakeUser extends Fake implements User {
  @override
  String get uid => testUid;

  @override
  bool get isAnonymous => true;

  @override
  String? get displayName => null;
}
