import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/transactions/journal_screen.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Gelir kaynağı seçimi (hızlı giriş) ve işlem düzenleme (ön dolu ekran,
/// yerinde kayıt), TxTile'da kaynaklı gelir görseli + Düzenle eylemi.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  CollectionReference<Map<String, dynamic>> txs(FakeFirebaseFirestore db) =>
      db.collection('users').doc(testUid).collection('transactions');
  Future<double> cash(FakeFirebaseFirestore db) async =>
      ((await db.collection('users').doc(testUid).collection('accounts').doc('cash').get())
              .data()?['balance'] as num?)
          ?.toDouble() ??
      0;

  final salary = testEnvelope(id: 'sal', name: 'Salary', emoji: '💼', presetKey: 'salary');
  final groceries =
      testEnvelope(id: 'gro', name: 'Groceries', emoji: '🛒', presetKey: 'groceries');

  testWidgets('gelir modunda kaynak seçilir; seçici yalnız gelir kataloğunu gösterir',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: db, envelopes: [salary, groceries], language: AppLanguage.en);
    await tester.tap(find.text(RS.en.income));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.pickCategory), findsOneWidget, reason: 'nakit gelirde pill var');

    await tester.tap(find.text(RS.en.pickCategory));
    await tester.pumpAndSettle();
    expect(find.text(RS.en.pickIncomeSource), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Freelance'), findsOneWidget, reason: 'katalog gelir maddesi');
    expect(find.text('Groceries'), findsNothing, reason: 'gider kataloğu yok');

    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    for (final k in ['4', '4', '0', '0']) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, RS.en.save));
    await tester.pumpAndSettle();

    final docs = (await txs(db).get()).docs;
    expect(docs, hasLength(1));
    final d = docs.single.data();
    expect(d['type'], 'income');
    expect(d['amount'], 4400);
    expect(d['envelopeId'], 'sal');
    expect(d['envelopeName'], 'Salary');
    expect(await cash(db), 4400);
    // Kaynak zarfının bakiyesi değişmez (yalnız etiket).
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('gider → gelir geçişinde seçili kategori sıfırlanır', (tester) async {
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: FakeFirebaseFirestore(), envelopes: [salary, groceries], language: AppLanguage.en);
    await tester.tap(find.text(RS.en.pickCategory));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsNothing, reason: 'gider seçicisinde gelir yok');
    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.text(RS.en.income));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsNothing);
    expect(find.text(RS.en.pickCategory), findsOneWidget);
  });

  testWidgets('düzenleme: ekran ön dolu, kayıt aynı belgeyi günceller (tek işlem)',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final date = DateTime(2026, 9, 3, 12);
    await txs(db).doc('t1').set({
      'type': 'expense',
      'amount': 450,
      'date': Timestamp.fromDate(date),
      'note': 'weekly shop',
      'envelopeId': 'gro',
      'envelopeName': 'Groceries',
      'envelopeIds': ['gro'],
      'currency': 'TRY',
    });
    await db.collection('users').doc(testUid).collection('accounts').doc('cash')
        .set({'balance': 1000 - 450});
    final tx = Tx(
      id: 't1',
      type: TxType.expense,
      amount: 450,
      date: date,
      note: 'weekly shop',
      envelopeId: 'gro',
      envelopeName: 'Groceries',
    );
    await pumpBudgyScreen(tester, QuickEntryScreen(editing: tx),
        db: db, envelopes: [salary, groceries], language: AppLanguage.en);

    // Ön dolu: tutar rakamları, kategori, tarih (3 Sep), Düzenleniyor rozeti.
    expect(find.text(RS.en.editingLabel), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('3 Sep'), findsOneWidget);
    for (final ch in ['4', '5', '0']) {
      expect(find.text(ch), findsWidgets);
    }
    expect(find.byIcon(Icons.repeat_rounded), findsNothing, reason: 'tekrar düzenlenmez');
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing, reason: 'çoklu mod yok');

    // 450 → 4500, kaydet.
    await tester.tap(find.widgetWithText(InkWell, '0').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, RS.en.save));
    await tester.pumpAndSettle();

    final docs = (await txs(db).get()).docs;
    expect(docs, hasLength(1), reason: 'yeni belge değil, aynı belge');
    final d = docs.single.data();
    expect(docs.single.id, 't1');
    expect(d['amount'], 4500);
    expect(d['envelopeId'], 'gro');
    expect(d['note'], 'weekly shop');
    expect(await cash(db), 1000 - 4500);
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('TxTile: kaynaklı gelir kaynağın adını ve görselini gösterir; sayfada Düzenle',
      (tester) async {
    final income = Tx(
      id: 'i1',
      type: TxType.income,
      amount: 4400,
      date: DateTime(2026, 9, 5, 12),
      envelopeId: 'sal',
      envelopeName: 'Salary',
    );
    final convert = Tx(
      id: 'c1',
      type: TxType.expense,
      amount: 100,
      date: DateTime(2026, 9, 5, 12),
      isConvert: true,
    );
    await pumpBudgyScreen(
      tester,
      Scaffold(
        body: ListView(children: [
          TxTile(tx: income, str: Strings.en),
          TxTile(tx: convert, str: Strings.en),
        ]),
      ),
      db: FakeFirebaseFirestore(),
      envelopes: [salary, groceries],
      language: AppLanguage.en,
    );
    // Başlık kaynak adı, alt satır "Income"; yön oku değil kategori görseli.
    expect(find.text('Salary'), findsOneWidget);
    expect(find.byIcon(Icons.work_rounded), findsOneWidget);
    expect(find.byIcon(Icons.south_west_rounded), findsNothing);

    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, RS.en.edit), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, RS.en.edit));
    await tester.pumpAndSettle();
    expect(find.byType(QuickEntryScreen), findsOneWidget);
    expect(find.text(RS.en.editingLabel), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget, reason: 'kaynak ön dolu');
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    // Çevrim bacağında Düzenle yok.
    await tester.tap(find.text(Strings.en.convertTitle).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, RS.en.edit), findsNothing);
    expect(find.widgetWithText(FilledButton, Strings.en.deleteWord), findsOneWidget);
  });
}
