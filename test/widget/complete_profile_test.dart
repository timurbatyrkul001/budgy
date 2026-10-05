import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/auth/complete_profile_screen.dart';

import '../support/harness.dart';

/// Profili tamamla ekranı (kayıt sonrası ve Kişisel bilgiler › telefon).
///
/// Yazma [guardWrite] kapısından geçer: başarıda `onComplete`, hatada
/// şerit + açık ekran. Burada sahte Firestore'a gerçekten ne yazıldığına
/// ve düğmenin gönderim sürerken kilitli kaldığına bakıyoruz.
void main() {
  final str = Strings.tr;
  const settingsPath = 'users/$testUid/settings/main';

  FilledButton continueButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('ad + telefon Firestore\'a yazılır, onComplete bir kez çağrılır',
      (tester) async {
    final db = FakeFirebaseFirestore();
    var completed = 0;
    await pumpBudgyScreen(
      tester,
      CompleteProfileScreen(onComplete: () => completed++),
      db: db,
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.fullNameHint),
      'Timur Batyrkul',
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.phoneHint),
      '555 123 45 67',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(completed, 1);
    final saved = (await db.doc(settingsPath).get()).data()!;
    expect(saved['name'], 'Timur Batyrkul');
    // Varsayılan ülke kodu + boşluk + numara.
    expect(saved['phone'], '+1 555 123 45 67');
  });

  testWidgets('boş telefon null yazılır (eski numara temizlenir)',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc(settingsPath).set({'name': 'Timur', 'phone': '+90 555'});
    await pumpBudgyScreen(
      tester,
      CompleteProfileScreen(onComplete: () {}),
      db: db,
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.fullNameHint),
      'Timur',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final saved = (await db.doc(settingsPath).get()).data()!;
    expect(saved['name'], 'Timur');
    // Alan var ama null: eski numara açıkça silinmiş, "dokunulmamış" değil.
    expect(saved.containsKey('phone'), isTrue);
    expect(saved['phone'], isNull);
  });

  testWidgets('çift dokunuş ikinci kayıt başlatmaz; düğme kilitlenir',
      (tester) async {
    final db = FakeFirebaseFirestore();
    var completed = 0;
    await pumpBudgyScreen(
      tester,
      CompleteProfileScreen(onComplete: () => completed++),
      db: db,
    );
    await tester.enterText(
      find.widgetWithText(TextField, str.fullNameHint),
      'Timur',
    );
    // İki dokunuş arada kadro çizilmeden: ikincisi eski `onPressed`'e
    // düşer ve `_saving` kapısına takılmalı.
    await tester.tap(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(continueButton(tester).onPressed, isNull);
    await tester.pumpAndSettle();

    expect(completed, 1);
  });
}
