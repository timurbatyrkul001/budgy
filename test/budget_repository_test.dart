import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

const _uid = 'test-user';

/// Testlerde tekrar eden yollar.
extension on FakeFirebaseFirestore {
  CollectionReference<Map<String, dynamic>> get envelopes =>
      collection('users').doc(_uid).collection('envelopes');
  CollectionReference<Map<String, dynamic>> get txs =>
      collection('users').doc(_uid).collection('transactions');
  CollectionReference<Map<String, dynamic>> get workDays =>
      collection('users').doc(_uid).collection('workDays');
  DocumentReference<Map<String, dynamic>> get cash =>
      collection('users').doc(_uid).collection('accounts').doc('cash');
}

Future<double> _cashOf(FakeFirebaseFirestore db) async =>
    ((await db.cash.get()).data()?['balance'] as num?)?.toDouble() ?? 0;

Future<double> _balanceOf(FakeFirebaseFirestore db, String id) async {
  final snap = await db.envelopes.doc(id).get();
  return (snap.data()!['balance'] as num).toDouble();
}

Future<String> _makeEnvelope(
  FakeFirebaseFirestore db, {
  String name = 'Yemek',
  double balance = 0,
  String currency = 'TRY',
  bool goal = false,
}) async {
  final doc = await db.envelopes.add({
    'name': name,
    'emoji': '🍔',
    'balance': balance,
    'sortOrder': 0,
    'currency': currency,
    if (goal) 'goal': true,
  });
  return doc.id;
}

void main() {
  late FakeFirebaseFirestore db;
  late BudgetRepository repo;
  late WorkDaysRepository workDays;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = BudgetRepository(db, _uid);
    workDays = WorkDaysRepository(db, _uid);
  });

  group('migrateToWallet', () {
    test('eski türetilmiş cebi tek seferde cüzdana taşır', () async {
      // Eski dünya: zarflarda para + dağıtılmamış gün + serbest kayıtlar.
      await _makeEnvelope(db, balance: 700);
      await _makeEnvelope(db, name: 'Kira', balance: 300);
      await _makeEnvelope(db, name: 'Dolar', balance: 50, currency: 'USD');
      await _makeEnvelope(db, name: 'Tatil', balance: 400, goal: true);
      await db.workDays.doc('2026-09-01').set({
        'month': '2026-09',
        'amount': 500.0,
      });
      await db.workDays.doc('2026-08-30').set({
        'month': '2026-08',
        'amount': 999.0,
        'allocated': true, // eski dağıtım — zarf bakiyesinde zaten var
      });
      await db.txs.add({
        'type': 'income',
        'amount': 200,
        'date': Timestamp.now(),
        'envelopeIds': <String>[],
        'free': true,
        'allocated': false,
      });
      await db.txs.add({
        'type': 'expense',
        'amount': 150,
        'date': Timestamp.now(),
        'envelopeIds': <String>[],
        'free': true,
        'allocated': false,
      });

      await repo.migrateToWallet();

      // 700+300 (₺ zarflar) + 500 (dağıtılmamış gün) + 200 − 150.
      // USD zarfı ve hedef cüzdana girmez.
      expect(await _cashOf(db), 1550);
    });

    test('ikinci çağrı hiçbir şeyi değiştirmez (idempotent)', () async {
      await _makeEnvelope(db, balance: 700);
      await repo.migrateToWallet();
      // Göçten sonra zarfa "eski usül" bakiye yazılsa bile tekrar sayılmaz.
      await repo.migrateToWallet();
      expect(await _cashOf(db), 700);
    });
  });

  group('gelir/gider cüzdanı hareket ettirir', () {
    test('addCashIncome cüzdana ekler', () async {
      await repo.addCashIncome(amount: 1000);
      expect(await _cashOf(db), 1000);
      final tx = (await db.txs.get()).docs.single.data();
      expect(tx['type'], 'income');
      expect(tx['amount'], 1000);
    });

    test('kategorili gider cüzdandan düşer, zarf bakiyesine DOKUNMAZ',
        () async {
      final id = await _makeEnvelope(db, balance: 500);
      await repo.addCashIncome(amount: 1000);

      await repo.addExpense(
        envelopeId: id,
        envelopeName: 'Yemek',
        amount: 120,
      );

      expect(await _cashOf(db), 880);
      expect(await _balanceOf(db, id), 500,
          reason: 'zarf artık kategori — para tutmuyor');
      final tx = (await db.txs.get()).docs
          .firstWhere((d) => d.data()['type'] == 'expense')
          .data();
      expect(tx['envelopeId'], id, reason: 'istatistik için etiket kalır');
    });

    test('kategorisiz gider de cüzdandan düşer', () async {
      await repo.addCashIncome(amount: 500);
      await repo.addExpense(amount: 200);
      expect(await _cashOf(db), 300);
    });

    test('döviz kumbarasından harcama kumbara bakiyesini düşürür, '
        'cüzdanı DEĞİL', () async {
      final usd = await _makeEnvelope(db, name: 'Dolar', balance: 100, currency: 'USD');
      await repo.addCashIncome(amount: 500);

      await repo.addExpense(
        envelopeId: usd,
        envelopeName: 'Dolar',
        amount: 30,
        currency: 'USD',
      );

      expect(await _balanceOf(db, usd), 70);
      expect(await _cashOf(db), 500);
    });
  });

  group('addCurrencyWallet', () {
    test('tutarlı: zarf + gelir işlemi TEK batch\'te, bakiye tutar kadar',
        () async {
      final id = await repo.addCurrencyWallet(
        code: 'USD',
        name: 'USD cüzdanı',
        emoji: '💵',
        amount: 500,
        sortOrder: 9,
        note: 'Başlangıç bakiyesi',
      );

      final env = (await db.envelopes.doc(id).get()).data()!;
      expect(env['currency'], 'USD');
      expect(env['balance'], 500);
      expect(env['sortOrder'], 9);
      expect(env['goal'], isNull, reason: 'hedef değil, kumbara');

      final tx = (await db.txs.get()).docs.single.data();
      expect(tx['type'], 'income');
      expect(tx['amount'], 500);
      expect(tx['currency'], 'USD');
      expect(tx['envelopeId'], id);
      expect(tx['envelopeName'], 'USD cüzdanı');
      expect(tx['envelopeIds'], [id]);
      expect(tx['note'], 'Başlangıç bakiyesi');
      expect(await _cashOf(db), 0, reason: 'döviz ₺ cüzdanına dokunmaz');
    });

    test('tutarsız: yalnız zarf, işlem yok, bakiye 0', () async {
      final id = await repo.addCurrencyWallet(
        code: 'EUR',
        name: 'EUR cüzdanı',
        emoji: '💶',
        amount: 0,
        sortOrder: 3,
      );
      expect(await _balanceOf(db, id), 0);
      expect((await db.txs.get()).docs, isEmpty);
    });

    test('silinen başlangıç geliri kumbara bakiyesini geri alır', () async {
      final id = await repo.addCurrencyWallet(
        code: 'USD',
        name: 'USD cüzdanı',
        emoji: '💵',
        amount: 200,
        sortOrder: 0,
      );
      final txId = (await db.txs.get()).docs.single.id;
      await repo.deleteTx(txId);
      expect(await _balanceOf(db, id), 0);
    });
  });

  group('çalışma günleri', () {
    test('gün işaretlemek parayı ANINDA cüzdana koyar', () async {
      await workDays.setDay(DateTime(2026, 9, 4), amount: 750);
      expect(await _cashOf(db), 750);
    });

    test('günü düzenlemek yalnız farkı uygular', () async {
      await workDays.setDay(DateTime(2026, 9, 4), amount: 750);
      await workDays.setDay(DateTime(2026, 9, 4), amount: 900);
      expect(await _cashOf(db), 900, reason: '750+900 değil, sadece fark');
    });

    test('günü silmek kazancı geri çeker', () async {
      await workDays.setDay(DateTime(2026, 9, 4), amount: 750);
      await workDays.removeDay(DateTime(2026, 9, 4));
      expect(await _cashOf(db), 0);
    });

    test('göç öncesi günün düzenlenmesi çift saymaz', () async {
      // Eski gün: tutarı göç toplamına girdi.
      await db.workDays.doc('2026-09-01').set({
        'month': '2026-09',
        'amount': 500.0,
      });
      await repo.migrateToWallet();
      expect(await _cashOf(db), 500);

      // Düzenleme: yalnız fark (+100) uygulanmalı.
      await workDays.setDay(DateTime(2026, 9, 1), amount: 600);
      expect(await _cashOf(db), 600);
    });
  });

  group('hedefler cüzdanla konuşur', () {
    test('fundGoal cüzdandan hedefe taşır', () async {
      final goal = await _makeEnvelope(db, name: 'Tatil', goal: true);
      await repo.addCashIncome(amount: 1000);

      await repo.fundGoal(goalId: goal, goalName: 'Tatil', amount: 250);

      expect(await _cashOf(db), 750);
      expect(await _balanceOf(db, goal), 250);
    });

    test('deleteGoal birikeni cüzdana iade eder', () async {
      final goal = await _makeEnvelope(db, name: 'Tatil', balance: 250, goal: true);

      await repo.deleteGoal(goal, 250);

      expect(await _cashOf(db), 250);
      expect((await db.envelopes.doc(goal).get()).exists, isFalse);
    });
  });

  group('döviz çevirme', () {
    test('₺ cüzdandan çıkar, döviz kumbaraya girer', () async {
      final usd = await _makeEnvelope(db, name: 'Dolar', currency: 'USD');
      await repo.addCashIncome(amount: 1000);

      await repo.convert(
        sentAmount: 400,
        toId: usd,
        toName: 'Dolar',
        toCurrency: 'USD',
        receivedAmount: 10,
      );

      expect(await _cashOf(db), 600);
      expect(await _balanceOf(db, usd), 10);
      expect((await db.txs.get()).docs.where(
            (d) => d.data()['convert'] == true,
          ), hasLength(2));
    });
  });

  group('deleteTx para etkisini geri alır', () {
    test('₺ gider silinince para cüzdana döner', () async {
      final id = await _makeEnvelope(db);
      await repo.addCashIncome(amount: 500);
      await repo.addExpense(
          envelopeId: id, envelopeName: 'Yemek', amount: 120);
      final tx = (await db.txs.get())
          .docs
          .firstWhere((d) => d.data()['type'] == 'expense');

      await repo.deleteTx(tx.id);

      expect(await _cashOf(db), 500);
    });

    test('₺ gelir silinince cüzdandan düşer', () async {
      await repo.addCashIncome(amount: 500);
      final tx = (await db.txs.get()).docs.single;

      await repo.deleteTx(tx.id);

      expect(await _cashOf(db), 0);
      expect((await db.txs.get()).docs, isEmpty);
    });

    test('hedef fonu silinince hedef VE cüzdan geri alınır', () async {
      final goal = await _makeEnvelope(db, name: 'Tatil', goal: true);
      await repo.addCashIncome(amount: 1000);
      await repo.fundGoal(goalId: goal, goalName: 'Tatil', amount: 250);
      final tx = (await db.txs.get())
          .docs
          .firstWhere((d) => d.data()['goalFund'] == true);

      await repo.deleteTx(tx.id);

      expect(await _cashOf(db), 1000);
      expect(await _balanceOf(db, goal), 0);
    });

    test('döviz çevrimi silinince iki bacak birlikte gider', () async {
      final usd = await _makeEnvelope(db, name: 'Dolar', currency: 'USD');
      await repo.addCashIncome(amount: 1000);
      await repo.convert(
        sentAmount: 400,
        toId: usd,
        toName: 'Dolar',
        toCurrency: 'USD',
        receivedAmount: 10,
      );
      final anyLeg = (await db.txs.get())
          .docs
          .firstWhere((d) => d.data()['convert'] == true);

      await repo.deleteTx(anyLeg.id);

      expect(await _cashOf(db), 1000);
      expect(await _balanceOf(db, usd), 0);
      expect(
        (await db.txs.get()).docs.where((d) => d.data()['convert'] == true),
        isEmpty,
      );
    });

    test('döviz kumbara gideri silinince kumbara geri dolar', () async {
      final usd = await _makeEnvelope(db, name: 'Dolar', balance: 100, currency: 'USD');
      await repo.addExpense(
          envelopeId: usd, envelopeName: 'Dolar', amount: 30, currency: 'USD');
      final tx = (await db.txs.get()).docs.single;

      await repo.deleteTx(tx.id);

      expect(await _balanceOf(db, usd), 100);
      expect(await _cashOf(db), 0);
    });

    test('göç öncesi eski işlem de doğru geri alınır: ₺ gider → +cüzdan',
        () async {
      // Eski model gideri: zarf bakiyesini düşürmüştü, cüzdan alanı yok.
      final id = await _makeEnvelope(db, balance: 380);
      final old = await db.txs.add({
        'type': 'expense',
        'amount': 120,
        'date': Timestamp.now(),
        'envelopeId': id,
        'envelopeIds': [id],
        'currency': 'TRY',
      });
      await repo.migrateToWallet(); // cüzdan = 380

      await repo.deleteTx(old.id);

      expect(await _cashOf(db), 500,
          reason: 'eski giderin parası bugünkü cüzdana geri döner');
    });
  });

  group('deleteAccountData', () {
    test('accounts dahil tüm koleksiyonları siler', () async {
      await _makeEnvelope(db);
      await repo.addCashIncome(amount: 100);
      await db.workDays.doc('2026-09-01').set({'month': '2026-09'});
      await db
          .collection('users')
          .doc(_uid)
          .collection('reminders')
          .add({'name': 'Kira', 'fromDay': 1, 'toDay': 5});

      await repo.deleteAccountData();

      expect((await db.envelopes.get()).docs, isEmpty);
      expect((await db.txs.get()).docs, isEmpty);
      expect((await db.workDays.get()).docs, isEmpty);
      expect((await db.cash.get()).exists, isFalse,
          reason: 'cüzdan hesabı da silinmeli');
      expect(
        (await db.collection('users').doc(_uid).collection('reminders').get())
            .docs,
        isEmpty,
      );
    });
  });
}
