import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

const _uid = 'test-user';

/// Nakit = ana birim. Ana birimi lira olmayan kullanıcıda:
/// * eski (hesapsız, 'TRY' damgalı) geçmiş ana birimde sayılmaya devam eder
///   — 'TRY' orada gerçek lira değil "ana birim" koduydu (Tx.legacyMainCode);
/// * hata döneminde yazılmış nakit kayıtları (nakit 'TRY' sanılıp çapraz
///   kurla dondurulmuş) okuma anında ham tutarıyla sayılır;
/// * göç nakit belgesine ana birimi yazar.
void main() {
  group('Tx.baseOr — ana birim lira değil', () {
    Tx legacy(double amount) => Tx(
          id: 'l',
          type: TxType.expense,
          amount: amount,
          date: DateTime(2026, 9, 1),
          currency: 'TRY', // hesaplar öncesi: "ana birim" kodu
        );

    test('hesapsız eski kayıt AZN/KZT/USD ana biriminde de sayılır', () {
      for (final main in ['AZN', 'KZT', 'USD', 'EUR', 'RUB', 'TRY']) {
        expect(legacy(300).baseOr(main), 300, reason: main);
      }
    });

    test('hata dönemi nakit kaydı: ×13 dondurulmuş tutar değil ham tutar',
        () {
      // Tenge kullanıcısı 5 000 ₸ nakit harcadı; nakit 'TRY' sanılıp
      // 1 ₺ = 13 ₸ ile 65 000 ₸ dondurulmuştu.
      final tx = Tx(
        id: 'b',
        type: TxType.expense,
        amount: 5000,
        date: DateTime(2026, 9, 1),
        currency: 'TRY',
        accountId: Account.cashId,
        baseAmount: 65000,
        baseCurrency: 'KZT',
        fxRate: 13,
      );
      expect(tx.isMislabeledCash, isTrue);
      expect(tx.baseOr('KZT'), 5000);
    });

    test('dolar: ÷41 dondurulmuş 100 \$ yine 100', () {
      final tx = Tx(
        id: 'b',
        type: TxType.expense,
        amount: 100,
        date: DateTime(2026, 9, 1),
        currency: 'TRY',
        accountId: Account.cashId,
        baseAmount: 2.44,
        baseCurrency: 'USD',
        fxRate: 1 / 41,
      );
      expect(tx.baseOr('USD'), 100);
    });

    test('gerçek lira nakit kaydı (baseCurrency TRY) dondurulmuş tutarla',
        () {
      final tx = Tx(
        id: 'ok',
        type: TxType.expense,
        amount: 150,
        date: DateTime(2026, 9, 1),
        currency: 'TRY',
        accountId: Account.cashId,
        baseAmount: 150,
        baseCurrency: 'TRY',
        fxRate: 1,
      );
      expect(tx.isMislabeledCash, isFalse);
      expect(tx.baseOr('TRY'), 150);
    });

    test('yeni nakit kaydı (currency = ana birim) olduğu gibi', () {
      final tx = Tx(
        id: 'n',
        type: TxType.expense,
        amount: 5000,
        date: DateTime(2026, 9, 1),
        currency: 'KZT',
        accountId: Account.cashId,
        baseAmount: 5000,
        baseCurrency: 'KZT',
        fxRate: 1,
      );
      expect(tx.isMislabeledCash, isFalse);
      expect(tx.baseOr('KZT'), 5000);
    });

    test('kart kaydına dokunulmaz: TRY kartından ₸ ana birime gerçek çevrim',
        () {
      // Türkiye kartı olan tenge kullanıcısı: bu çevrim DOĞRU, kalmalı.
      final tx = Tx(
        id: 'c',
        type: TxType.expense,
        amount: 100,
        date: DateTime(2026, 9, 1),
        currency: 'TRY',
        accountId: 'enpara',
        baseAmount: 1300,
        baseCurrency: 'KZT',
        fxRate: 13,
      );
      expect(tx.isMislabeledCash, isFalse);
      expect(tx.baseOr('KZT'), 1300);
    });

    test('fromDoc üzerinden de aynı', () async {
      final db = FakeFirebaseFirestore();
      final ref = await db.collection('t').add({
        'type': 'expense',
        'amount': 5000,
        'date': Timestamp.fromDate(DateTime(2026, 9, 1)),
        'currency': 'TRY',
        'accountId': 'cash',
        'baseAmount': 65000,
        'baseCurrency': 'KZT',
        'fxRate': 13,
      });
      final tx = Tx.fromDoc(await ref.get());
      expect(tx.baseOr('KZT'), 5000);
    });
  });

  group('BudgetRepository — nakit ana birimde', () {
    late FakeFirebaseFirestore db;
    late BudgetRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = BudgetRepository(db, _uid);
    });

    DocumentReference<Map<String, dynamic>> cash() =>
        db.collection('users').doc(_uid).collection('accounts').doc('cash');

    test('migrateToWallet nakit belgesine ANA birimi yazar', () async {
      await db
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('main')
          .set({'currency': 'KZT'});
      await repo.migrateToWallet();
      expect((await cash().get()).data()!['currency'], 'KZT');
    });

    test('ayar yoksa göç ₺ yazar (eski davranış)', () async {
      await repo.migrateToWallet();
      expect((await cash().get()).data()!['currency'], 'TRY');
    });

    test('mainCurrency ayarı okur, yoksa ₺', () async {
      expect(await repo.mainCurrency(), 'TRY');
      await db
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('main')
          .set({'currency': 'USD'});
      expect(await repo.mainCurrency(), 'USD');
    });

    test('accountId "cash" ile gider, belge yokken de nakdi açar', () async {
      await repo.addExpense(
        amount: 5000,
        currency: 'KZT',
        accountId: Account.cashId,
        baseAmount: 5000,
        baseCurrency: 'KZT',
        fxRate: 1,
      );
      expect((await cash().get()).data()!['balance'], -5000);
      await repo.addCashIncome(
        amount: 8000,
        currency: 'KZT',
        accountId: Account.cashId,
        baseAmount: 8000,
        baseCurrency: 'KZT',
        fxRate: 1,
      );
      expect((await cash().get()).data()!['balance'], 3000);
    });

    test('hesapsız eski yol: ₺ kodu nakit demektir, ana birim ne olursa',
        () async {
      await db
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('main')
          .set({'currency': 'AZN'});
      await repo.addCashIncome(amount: 1000);
      await repo.addExpense(amount: 300);
      expect((await cash().get()).data()!['balance'], 700);
      final txs = (await db
              .collection('users')
              .doc(_uid)
              .collection('transactions')
              .get())
          .docs
          .map(Tx.fromDoc);
      // Manat kullanıcısının geçmişi: ikisi de ana birimde sayılır.
      expect(txs.map((t) => t.baseOr('AZN')), unorderedEquals([1000, 300]));
    });
  });
}
