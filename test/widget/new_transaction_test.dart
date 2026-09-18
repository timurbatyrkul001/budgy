import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/transactions/new_transaction_sheet.dart';

import '../support/harness.dart';

/// Ekranı bir düğmeye basarak açar: showNewTransaction bir route ittiği için
/// doğrudan pump edilemiyor.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.mode, this.envelopeId});

  final TxMode mode;
  final String? envelopeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () =>
              showNewTransaction(context, mode: mode, envelopeId: envelopeId),
          child: const Text('aç'),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  late FakeFirebaseFirestore db;
  final str = Strings.tr;

  Future<void> openSheet(
    WidgetTester tester, {
    required TxMode mode,
    List<Envelope> envelopes = const [],
    String? envelopeId,
  }) async {
    db = FakeFirebaseFirestore();
    for (final e in envelopes) {
      await seedEnvelope(db, e);
    }
    await pumpBudgyScreen(
      tester,
      _Launcher(mode: mode, envelopeId: envelopeId),
      db: db,
      envelopes: envelopes,
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('kasadan harcama kaydeder (serbest gider)', (tester) async {
    await openSheet(tester, mode: TxMode.expense, envelopes: [
      testEnvelope(id: 'e1', name: 'Yemek'),
    ]);

    await tester.enterText(find.byType(TextField).first, '250');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, str.save));
    await tester.pumpAndSettle();

    final txs = await db.collection('users/$testUid/transactions').get();
    expect(txs.docs, hasLength(1));
    final tx = txs.docs.first.data();
    expect(tx['type'], 'expense');
    expect(tx['amount'], 250);
    final cash = await db.doc('users/$testUid/accounts/cash').get();
    expect(cash.data()!['balance'], -250,
        reason: 'kategorisiz gider de cüzdandan düşer');
  });

  testWidgets('kategorili harcama cüzdandan düşer, zarfa dokunmaz',
      (tester) async {
    await openSheet(
      tester,
      mode: TxMode.expense,
      envelopes: [testEnvelope(id: 'e1', name: 'Yemek', balance: 500)],
      envelopeId: 'e1',
    );
    await db
        .doc('users/$testUid/accounts/cash')
        .set({'balance': 1000.0, 'currency': 'TRY'});

    await tester.enterText(find.byType(TextField).first, '120');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, str.save));
    await tester.pumpAndSettle();

    final cash = await db.doc('users/$testUid/accounts/cash').get();
    expect(cash.data()!['balance'], 880);
    final env = await db.doc('users/$testUid/envelopes/e1').get();
    expect(env.data()!['balance'], 500,
        reason: 'zarf artık kategori — para tutmuyor');
  });

  testWidgets('gelir doğrudan cüzdana yazılır', (tester) async {
    await openSheet(tester, mode: TxMode.income, envelopes: [
      testEnvelope(id: 'e1', name: 'Yemek'),
    ]);

    await tester.enterText(find.byType(TextField).first, '2500');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, str.save));
    await tester.pumpAndSettle();

    final cash = await db.doc('users/$testUid/accounts/cash').get();
    expect(cash.data()!['balance'], 2500);
    final txs = await db.collection('users/$testUid/transactions').get();
    expect(txs.docs.single.data()['type'], 'income');
  });

  testWidgets('arşivlenmiş zarf ve hedef seçicide görünmez', (tester) async {
    await openSheet(tester, mode: TxMode.expense, envelopes: [
      testEnvelope(id: 'e1', name: 'Yemek'),
      testEnvelope(id: 'arch', name: 'Eski', archived: true, sortOrder: 1),
      testEnvelope(id: 'goal', name: 'Tatil', isGoal: true, sortOrder: 2),
    ]);

    await tester.tap(find.text(str.withoutEnvelope));
    await tester.pumpAndSettle();

    expect(find.text('Yemek'), findsWidgets);
    expect(find.text('Eski'), findsNothing);
    expect(find.text('Tatil'), findsNothing);
  });

  testWidgets('tutar girilmeden kaydedilemez', (tester) async {
    await openSheet(tester, mode: TxMode.expense, envelopes: [
      testEnvelope(id: 'e1', name: 'Yemek'),
    ]);

    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, str.save));
    expect(button.onPressed, isNull);
  });
}
