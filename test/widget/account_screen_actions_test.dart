import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show User, UserInfo, UserMetadata;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/settings/settings_account_screen.dart';

import '../support/harness.dart';

/// Hesabım › çıkış ve silme: ağ yokken tuzak yok, silme sırasında çift
/// dokunma yok.
///
/// Firebase Auth testte yok; [AccountActions] kancalarıyla üye bir
/// kullanıcı ve anonim giriş sahteleniyor.
void main() {
  final str = Strings.tr;

  Future<void> pumpAccount(
    WidgetTester tester, {
    required AccountActions actions,
  }) async {
    await pumpBudgyScreen(
      tester,
      SettingsAccountScreen(actions: actions),
      db: FakeFirebaseFirestore(),
    );
  }

  /// Tehlikeli işlemler kartı 800 px'lik ekranda katlanmanın altında.
  /// `scrollUntilVisible` tembel liste öğeyi KURDUĞU anda durur (ekranın
  /// 250 px altındaki önbellekte olabilir); dokunmak için gerçekten
  /// görünür olması gerekiyor — ardından `ensureVisible`.
  Future<void> scrollToDanger(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text(str.deleteAccount),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(str.deleteAccount));
    await tester.pumpAndSettle();
  }

  /// Diyalogdaki kırmızı onay düğmesi (satırdaki başlıkla aynı metin).
  Finder confirmButton(String text) =>
      find.widgetWithText(TextButton, text);

  group('çıkış', () {
    testWidgets('ağ yok → şerit, kullanıcı HESABINDA kalır, satır yine açık',
        (tester) async {
      final user = _FakeUser();
      var attempts = 0;
      await pumpAccount(
        tester,
        actions: AccountActions(
          currentUser: () => user,
          signInAnonymously: () async {
            attempts++;
            throw StateError('network-request-failed');
          },
        ),
      );
      await scrollToDanger(tester);
      expect(find.text(str.signOutWord), findsOneWidget);

      await tester.tap(find.text(str.signOutWord));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton(str.signOutWord));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text(str.signOutFailed), findsOneWidget);
      // Ekran yerinde, kullanıcı hâlâ üye: çıkış satırı duruyor.
      expect(find.text(str.signOutWord), findsOneWidget);

      // Meşgul kilidi açıldı: tekrar denenebiliyor.
      await tester.tap(find.text(str.signOutWord));
      await tester.pumpAndSettle();
      expect(confirmButton(str.signOutWord), findsOneWidget);
      await tester.tap(confirmButton(str.signOutWord));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    });

    testWidgets('ağ var → anonim giriş bir kez, şerit yok', (tester) async {
      var attempts = 0;
      await pumpAccount(
        tester,
        actions: AccountActions(
          currentUser: _FakeUser.new,
          signInAnonymously: () async => attempts++,
        ),
      );
      await scrollToDanger(tester);
      await tester.tap(find.text(str.signOutWord));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton(str.signOutWord));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text(str.signOutFailed), findsNothing);
    });

    testWidgets('vazgeç → hiçbir şey olmaz', (tester) async {
      var attempts = 0;
      await pumpAccount(
        tester,
        actions: AccountActions(
          currentUser: _FakeUser.new,
          signInAnonymously: () async => attempts++,
        ),
      );
      await scrollToDanger(tester);
      await tester.tap(find.text(str.signOutWord));
      await tester.pumpAndSettle();
      await tester.tap(find.text(str.cancel));
      await tester.pumpAndSettle();
      expect(attempts, 0);
    });
  });

  group('hesap silme', () {
    testWidgets('silme sürerken gösterge var, ikinci dokunma diyalog açmaz', (
      tester,
    ) async {
      final deletion = Completer<void>();
      final user = _FakeUser(onDelete: () => deletion.future);
      var anonymousSignIns = 0;
      await pumpAccount(
        tester,
        actions: AccountActions(
          currentUser: () => user,
          signInAnonymously: () async => anonymousSignIns++,
        ),
      );
      await scrollToDanger(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text(str.deleteAccount));
      await tester.pumpAndSettle();
      expect(find.text(str.deleteAccountBody), findsOneWidget);
      await tester.tap(confirmButton(str.deleteAccount));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Silme askıda: gösterge dönüyor.
      expect(user.deleteCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Aynı satıra yeniden dokun: ne diyalog ne ikinci silme.
      await tester.tap(find.text(str.deleteAccount));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(str.deleteAccountBody), findsNothing);
      expect(user.deleteCalls, 1);

      deletion.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Anonim oturumu bu ekran DEĞİL AuthGate açar.
      expect(anonymousSignIns, 0);
      expect(find.text(str.deleteAccountFailed), findsNothing);
    });

    testWidgets('silme düştü → şerit, gösterge kalkar, satır yine açık', (
      tester,
    ) async {
      final user = _FakeUser(
        onDelete: () async => throw StateError('network-request-failed'),
      );
      await pumpAccount(
        tester,
        actions: AccountActions(
          currentUser: () => user,
          signInAnonymously: () async {},
        ),
      );
      await scrollToDanger(tester);
      await tester.tap(find.text(str.deleteAccount));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton(str.deleteAccount));
      await tester.pumpAndSettle();

      expect(find.text(str.deleteAccountFailed), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Yüzen şerit satırın üstünü örtüyor; sönmesini bekle, sonra dokun.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text(str.deleteAccount));
      await tester.pumpAndSettle();
      expect(find.text(str.deleteAccountBody), findsOneWidget);
    });
  });
}

/// Üye (anonim olmayan) kullanıcı: az önce girmiş, yeniden doğrulama
/// gerekmez; sağlayıcı listesi boş.
class _FakeUser extends Fake implements User {
  _FakeUser({Future<void> Function()? onDelete}) : _onDelete = onDelete;

  final Future<void> Function()? _onDelete;
  int deleteCalls = 0;

  @override
  String get uid => testUid;

  @override
  bool get isAnonymous => false;

  @override
  String? get email => 'timur@example.com';

  @override
  UserMetadata get metadata => _FakeMetadata();

  @override
  List<UserInfo> get providerData => const [];

  @override
  Future<void> delete() {
    deleteCalls++;
    return (_onDelete ?? () async {})();
  }
}

class _FakeMetadata extends Fake implements UserMetadata {
  @override
  DateTime? get lastSignInTime => DateTime.now();
}
