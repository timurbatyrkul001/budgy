import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

const _uid = 'test-user';

/// updateTx: eski etki geri alınıp yenisi uygulanır — sonuç, eski işlem hiç
/// olmamış da yenisi sıfırdan yazılmış gibi olmalı. Her senaryo iki yoldan
/// hesaplanır: (1) düzenleme, (2) taze yazım; cüzdan ve zarf bakiyeleri eşit.
void main() {
  late FakeFirebaseFirestore db;
  late BudgetRepository repo;

  CollectionReference<Map<String, dynamic>> envelopes() =>
      db.collection('users').doc(_uid).collection('envelopes');
  CollectionReference<Map<String, dynamic>> txs() =>
      db.collection('users').doc(_uid).collection('transactions');

  Future<double> cash() async =>
      ((await db.collection('users').doc(_uid).collection('accounts').doc('cash').get())
              .data()?['balance'] as num?)
          ?.toDouble() ??
      0;
  Future<double> bal(String id) async =>
      ((await envelopes().doc(id).get()).data()!['balance'] as num).toDouble();

  Future<String> env(String name, {double balance = 0, String currency = 'TRY'}) async {
    final d = await envelopes().add({
      'name': name,
      'emoji': '🍔',
      'balance': balance,
      'sortOrder': 0,
      'currency': currency,
    });
    return d.id;
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = BudgetRepository(db, _uid);
  });

  final d0 = DateTime(2026, 9, 10, 12);

  test('tutar artar / azalır: cüzdan farkı tam', () async {
    final cat = await env('Market');
    final id = await repo.addExpense(envelopeId: cat, envelopeName: 'Market', amount: 450, date: d0);
    expect(await cash(), -450);

    await repo.updateTx(id,
        type: TxType.expense, amount: 700, currency: 'TRY', date: d0,
        envelopeId: cat, envelopeName: 'Market');
    expect(await cash(), -700);

    await repo.updateTx(id,
        type: TxType.expense, amount: 120, currency: 'TRY', date: d0,
        envelopeId: cat, envelopeName: 'Market');
    expect(await cash(), -120);
    expect(await bal(cat), 0, reason: '₺ kategori zarfı bakiye taşımaz');

    final doc = (await txs().doc(id).get()).data()!;
    expect(doc['amount'], 120);
    expect(doc['envelopeIds'], [cat]);
    expect((await txs().get()).docs, hasLength(1), reason: 'yeni belge yok');
  });

  test('gider → gelir → gider: cüzdan işareti değişir', () async {
    final id = await repo.addExpense(amount: 300, date: d0);
    expect(await cash(), -300);

    final salary = await env('Maaş');
    await repo.updateTx(id,
        type: TxType.income, amount: 300, currency: 'TRY', date: d0,
        envelopeId: salary, envelopeName: 'Maaş');
    expect(await cash(), 300);
    expect(await bal(salary), 0, reason: 'gelir kaynağı yalnız etiket');
    expect((await txs().doc(id).get()).data()!['type'], 'income');

    await repo.updateTx(id,
        type: TxType.expense, amount: 300, currency: 'TRY', date: d0);
    expect(await cash(), -300);
    final doc = (await txs().doc(id).get()).data()!;
    expect(doc['type'], 'expense');
    expect(doc.containsKey('envelopeId'), isFalse, reason: 'etiket kaldırıldı');
    expect(doc['envelopeIds'], isEmpty);
  });

  test('nakit → döviz cüzdanı → nakit: cüzdan ve kumbara birlikte düzelir', () async {
    final usd = await env('Dolar', balance: 1000, currency: 'USD');
    final id = await repo.addExpense(amount: 200, date: d0);
    expect(await cash(), -200);

    await repo.updateTx(id,
        type: TxType.expense, amount: 50, currency: 'USD', date: d0,
        envelopeId: usd, envelopeName: 'Dolar');
    expect(await cash(), 0, reason: 'nakit etkisi tamamen geri alındı');
    expect(await bal(usd), 950);

    await repo.updateTx(id,
        type: TxType.expense, amount: 200, currency: 'TRY', date: d0);
    expect(await cash(), -200);
    expect(await bal(usd), 1000, reason: 'kumbara olduğu gibi');

    // Döviz gelir → döviz gider aynı kumbarada.
    final id2 = await repo.addEnvelopeIncome(
        envelopeId: usd, envelopeName: 'Dolar', amount: 100, currency: 'USD', date: d0);
    expect(await bal(usd), 1100);
    await repo.updateTx(id2,
        type: TxType.expense, amount: 100, currency: 'USD', date: d0,
        envelopeId: usd, envelopeName: 'Dolar');
    expect(await bal(usd), 900);
    expect(await cash(), -200, reason: 'nakit dokunulmadı');
  });

  test('yalnız kategori / not / tarih değişir: bakiyeler dokunulmaz', () async {
    final a = await env('Market');
    final b = await env('Kahve');
    final id = await repo.addExpense(envelopeId: a, envelopeName: 'Market', amount: 90, date: d0);
    final before = await cash();

    final d1 = DateTime(2026, 9, 3, 12);
    await repo.updateTx(id,
        type: TxType.expense, amount: 90, currency: 'TRY', date: d1,
        envelopeId: b, envelopeName: 'Kahve', note: 'sabah');
    expect(await cash(), before);
    expect(await bal(a), 0);
    expect(await bal(b), 0);
    final doc = (await txs().doc(id).get()).data()!;
    expect(doc['envelopeId'], b);
    expect(doc['envelopeName'], 'Kahve');
    expect(doc['note'], 'sabah');
    expect((doc['date'] as Timestamp).toDate(), d1);
  });

  test('düzenleme = sil + taze yaz ile aynı sonuç', () async {
    final usd = await env('Dolar', balance: 500, currency: 'USD');
    final cat = await env('Market');
    // Yol 1: düzenle.
    final id = await repo.addEnvelopeIncome(
        envelopeId: usd, envelopeName: 'Dolar', amount: 80, currency: 'USD', date: d0);
    await repo.addExpense(envelopeId: cat, envelopeName: 'Market', amount: 40, date: d0);
    await repo.updateTx(id,
        type: TxType.expense, amount: 130, currency: 'TRY', date: d0,
        envelopeId: cat, envelopeName: 'Market');
    final cash1 = await cash();
    final usd1 = await bal(usd);

    // Yol 2: taze bir dünyada doğrudan son durumu yaz.
    db = FakeFirebaseFirestore();
    repo = BudgetRepository(db, _uid);
    final usd2 = await env('Dolar', balance: 500, currency: 'USD');
    final cat2 = await env('Market');
    await repo.addExpense(envelopeId: cat2, envelopeName: 'Market', amount: 40, date: d0);
    await repo.addExpense(envelopeId: cat2, envelopeName: 'Market', amount: 130, date: d0);
    expect(cash1, await cash());
    expect(usd1, await bal(usd2));
  });

  test('çevrim bacağı, hedef fonu ve transfer düzenlenemez', () async {
    final leg = await txs().add({
      'type': 'expense', 'amount': 100, 'date': Timestamp.fromDate(d0),
      'currency': 'TRY', 'groupId': 'g1', 'convert': true,
    });
    final fund = await txs().add({
      'type': 'expense', 'amount': 100, 'date': Timestamp.fromDate(d0),
      'currency': 'TRY', 'goalFund': true, 'goalId': 'goal1',
    });
    final transfer = await txs().add({
      'type': 'transfer', 'amount': 100, 'date': Timestamp.fromDate(d0),
    });
    Future<void> attempt(String id, {TxType type = TxType.expense}) => repo.updateTx(id,
        type: type, amount: 5, currency: 'TRY', date: d0);
    await expectLater(attempt(leg.id), throwsA(isA<TxNotEditable>()));
    await expectLater(attempt(fund.id), throwsA(isA<TxNotEditable>()));
    await expectLater(attempt(transfer.id), throwsA(isA<TxNotEditable>()));
    await expectLater(attempt(leg.id, type: TxType.transfer), throwsA(isA<TxNotEditable>()));
    // Hiçbir şey değişmedi.
    expect(await cash(), 0);
    expect((await txs().doc(leg.id).get()).data()!['amount'], 100);
  });

  test('deleteTx aynı geri alma mantığını kullanır (düzenlemeden sonra silmek sıfırlar)',
      () async {
    final usd = await env('Dolar', balance: 300, currency: 'USD');
    final id = await repo.addExpense(amount: 250, date: d0);
    await repo.updateTx(id,
        type: TxType.income, amount: 60, currency: 'USD', date: d0,
        envelopeId: usd, envelopeName: 'Dolar');
    expect(await cash(), 0);
    expect(await bal(usd), 360);
    await repo.deleteTx(id);
    expect(await cash(), 0);
    expect(await bal(usd), 300);
    expect((await txs().get()).docs, isEmpty);
  });
}
