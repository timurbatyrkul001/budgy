import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

/// Harcamanın SEÇİLEN karttan düşmesi, gelirin SEÇİLEN karta girmesi, kurun
/// işlem anında dondurulması; düzenleme/silmede hesabın geri alınması.
/// Buradaki asıl kural: `accountId` verilmeyen eski yol birebir korunmalı —
/// hiç kart eklememiş kullanıcı değişikliği hissetmemeli.
void main() {
  late FakeFirebaseFirestore db;
  late BudgetRepository repo;
  const uid = 'u1';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = BudgetRepository(db, uid);
  });

  Future<Map<String, dynamic>> txDoc(String id) async =>
      (await db.doc('users/$uid/transactions/$id').get()).data()!;

  Future<double> balanceOf(String accountId) async =>
      ((await db.doc('users/$uid/accounts/$accountId').get()).data()?['balance']
              as num?)
          ?.toDouble() ??
      0;

  test('hesap verilince para o karttan düşer, kur donar', () async {
    await db.doc('users/$uid/accounts/az-card').set({
      'name': 'Kapital Bank',
      'currency': 'AZN',
      'kind': 'card',
      'balance': 500.0,
    });

    final id = await repo.addExpense(
      amount: 40,
      currency: 'AZN',
      accountId: 'az-card',
      baseAmount: 78.8,
      baseCurrency: 'TRY',
      fxRate: 1.97,
      envelopeId: 'market',
      envelopeName: 'Market',
    );

    final tx = await txDoc(id);
    expect(tx['accountId'], 'az-card');
    expect(tx['amount'], 40);
    expect(tx['currency'], 'AZN');
    // Çevrilmiş tutar kayda yazıldı: analizler bunu toplayacak.
    expect(tx['baseAmount'], 78.8);
    expect(tx['baseCurrency'], 'TRY');
    expect(tx['fxRate'], 1.97);

    // Bakiye hesabın KENDİ biriminde düşer — çevrilmiş tutar değil.
    expect(await balanceOf('az-card'), 460);
    // Nakit kasasına dokunulmadı.
    expect(await balanceOf(Account.cashId), 0);
  });

  test('hesap verilmezse eski tek kasa yolu aynen çalışır', () async {
    final id = await repo.addExpense(amount: 100, envelopeId: 'market');

    final tx = await txDoc(id);
    expect(tx.containsKey('accountId'), isFalse);
    expect(tx.containsKey('baseAmount'), isFalse);
    expect(await balanceOf(Account.cashId), -100);
  });

  /// Gelir, giderin aynası: para seçilen hesaba GİRER, kur yine donar.
  /// Bu olmadan karttan para yalnız çıkıyor, hiç girmiyordu — maaşı o karta
  /// yatan kullanıcıda bakiye sürekli düşerdi.
  group('gelir', () {
    setUp(() async {
      await db.doc('users/$uid/accounts/tr-card').set({
        'name': 'Enpara',
        'currency': 'TRY',
        'kind': 'card',
        'balance': 1000.0,
      });
      await db.doc('users/$uid/accounts/az-card').set({
        'name': 'Kapital Bank',
        'currency': 'AZN',
        'kind': 'card',
        'balance': 500.0,
      });
    });

    test('hesap verilince para o karta girer, nakit dokunulmaz', () async {
      final id = await repo.addCashIncome(
        amount: 5000,
        currency: 'TRY',
        accountId: 'tr-card',
        baseAmount: 5000,
        baseCurrency: 'TRY',
        fxRate: 1,
        envelopeId: 'salary',
        envelopeName: 'Maaş',
      );

      final tx = await txDoc(id);
      expect(tx['type'], 'income');
      expect(tx['accountId'], 'tr-card');
      expect(tx['amount'], 5000);
      expect(tx['currency'], 'TRY');
      expect(tx['envelopeId'], 'salary', reason: 'gelir kaynağı etiketi kalır');
      expect(await balanceOf('tr-card'), 6000);
      expect(await balanceOf(Account.cashId), 0, reason: 'nakit dokunulmadı');
    });

    test('manat kartına 300 ₼, kur 1.97 → baseAmount 591, fxRate 1.97', () async {
      final id = await repo.addCashIncome(
        amount: 300,
        currency: 'AZN',
        accountId: 'az-card',
        baseAmount: 591,
        baseCurrency: 'TRY',
        fxRate: 1.97,
      );

      final tx = await txDoc(id);
      expect(tx['currency'], 'AZN');
      expect(tx['baseAmount'], 591);
      expect(tx['baseCurrency'], 'TRY');
      expect(tx['fxRate'], 1.97);
      // Bakiye kartın KENDİ biriminde artar — çevrilmiş tutar değil.
      expect(await balanceOf('az-card'), 800);
      expect(await balanceOf(Account.cashId), 0);
    });

    test('hesap verilmezse eski nakit yolu aynen çalışır', () async {
      final id = await repo.addCashIncome(amount: 700, envelopeId: 'salary');

      final tx = await txDoc(id);
      expect(tx.containsKey('accountId'), isFalse);
      expect(tx.containsKey('baseAmount'), isFalse);
      expect(tx['currency'], 'TRY');
      expect(await balanceOf(Account.cashId), 700);
      expect(await balanceOf('tr-card'), 1000, reason: 'kartlar dokunulmadı');
      expect(await balanceOf('az-card'), 500);
    });
  });

  /// Düzenleme ve silme: eski etki hesaptan geri alınır, yenisi uygulanır.
  /// Kural: sonuç, eski işlem hiç olmamış da yenisi sıfırdan yazılmış gibi.
  group('düzenleme ve silme', () {
    final d0 = DateTime(2026, 9, 10, 12);

    setUp(() async {
      await db.doc('users/$uid/accounts/tr-card').set({
        'name': 'Enpara',
        'currency': 'TRY',
        'kind': 'card',
        'balance': 1000.0,
      });
      await db.doc('users/$uid/accounts/az-card').set({
        'name': 'Kapital Bank',
        'currency': 'AZN',
        'kind': 'card',
        'balance': 500.0,
      });
    });

    Future<String> azExpense40() => repo.addExpense(
          amount: 40,
          currency: 'AZN',
          accountId: 'az-card',
          baseAmount: 78.8,
          baseCurrency: 'TRY',
          fxRate: 1.97,
          envelopeId: 'market',
          envelopeName: 'Market',
          date: d0,
        );

    test('aynı kartta 40 → 60: bakiye yalnız FARK kadar oynar', () async {
      final id = await azExpense40();
      expect(await balanceOf('az-card'), 460);

      await repo.updateTx(id,
          type: TxType.expense,
          amount: 60,
          currency: 'AZN',
          date: d0,
          envelopeId: 'market',
          envelopeName: 'Market',
          accountId: 'az-card',
          baseAmount: 118.2,
          baseCurrency: 'TRY',
          fxRate: 1.97);

      // 500 − 60: ne 500 − 40 − 60 (iki kez düşme) ne 500 − 40 + 40 − 60'ın
      // dışında bir şey.
      expect(await balanceOf('az-card'), 440);
      expect(await balanceOf(Account.cashId), 0, reason: 'nakit dokunulmadı');
      final tx = await txDoc(id);
      expect(tx['amount'], 60);
      expect(tx['baseAmount'], 118.2, reason: 'kur yeniden donduruldu');
      expect(tx['accountId'], 'az-card');
    });

    test('kart değişince: eskisine iade, yenisinden düşüş', () async {
      final id = await azExpense40();

      await repo.updateTx(id,
          type: TxType.expense,
          amount: 40,
          currency: 'TRY',
          date: d0,
          envelopeId: 'market',
          envelopeName: 'Market',
          accountId: 'tr-card',
          baseAmount: 40,
          baseCurrency: 'TRY',
          fxRate: 1);

      expect(await balanceOf('az-card'), 500, reason: '40 ₼ geri geldi');
      expect(await balanceOf('tr-card'), 960, reason: '40 ₺ düştü');
      expect(await balanceOf(Account.cashId), 0);
      final tx = await txDoc(id);
      expect(tx['accountId'], 'tr-card');
      expect(tx['currency'], 'TRY');
      expect(tx['fxRate'], 1);
    });

    test('hesaplı gelirin tutarı değişince kart farkla oynar', () async {
      final id = await repo.addCashIncome(
          amount: 5000,
          currency: 'TRY',
          accountId: 'tr-card',
          baseAmount: 5000,
          baseCurrency: 'TRY',
          fxRate: 1,
          date: d0);
      expect(await balanceOf('tr-card'), 6000);

      await repo.updateTx(id,
          type: TxType.income,
          amount: 4500,
          currency: 'TRY',
          date: d0,
          accountId: 'tr-card',
          baseAmount: 4500,
          baseCurrency: 'TRY',
          fxRate: 1);
      expect(await balanceOf('tr-card'), 5500);
      expect(await balanceOf(Account.cashId), 0);
    });

    test('kart → nakit: kart iade edilir, nakit düşer, hesap alanları silinir',
        () async {
      final id = await azExpense40();

      await repo.updateTx(id,
          type: TxType.expense,
          amount: 80,
          currency: 'TRY',
          date: d0,
          envelopeId: 'market',
          envelopeName: 'Market');

      expect(await balanceOf('az-card'), 500);
      expect(await balanceOf(Account.cashId), -80);
      final tx = await txDoc(id);
      expect(tx.containsKey('accountId'), isFalse);
      expect(tx.containsKey('baseAmount'), isFalse,
          reason: 'eski karttan kalan kur kırıntısı analizleri yanıltmasın');
      expect(tx.containsKey('fxRate'), isFalse);
    });

    test('silme: kart bakiyesi geri döner', () async {
      final id = await azExpense40();
      final inc = await repo.addCashIncome(
          amount: 300,
          currency: 'AZN',
          accountId: 'az-card',
          baseAmount: 591,
          baseCurrency: 'TRY',
          fxRate: 1.97,
          date: d0);
      expect(await balanceOf('az-card'), 760);

      await repo.deleteTx(id);
      expect(await balanceOf('az-card'), 800, reason: '40 ₼ gider geri geldi');
      await repo.deleteTx(inc);
      expect(await balanceOf('az-card'), 500, reason: '300 ₼ gelir geri alındı');
      expect(await balanceOf(Account.cashId), 0, reason: 'nakit hiç karışmadı');
      expect((await db.collection('users/$uid/transactions').get()).docs, isEmpty);
    });

    test('eski hesapsız kayıt eskisi gibi düzenlenir', () async {
      final id = await repo.addExpense(amount: 450, envelopeId: 'market', date: d0);
      expect(await balanceOf(Account.cashId), -450);

      await repo.updateTx(id,
          type: TxType.expense,
          amount: 700,
          currency: 'TRY',
          date: d0,
          envelopeId: 'market',
          envelopeName: 'Market');

      expect(await balanceOf(Account.cashId), -700);
      expect(await balanceOf('tr-card'), 1000, reason: 'kartlar dokunulmadı');
      expect(await balanceOf('az-card'), 500);
      final tx = await txDoc(id);
      expect(tx.containsKey('accountId'), isFalse);
      expect(tx.containsKey('baseAmount'), isFalse);
    });

    test('accountId "cash": cüzdana tek artış, iki kez değil', () async {
      await db.doc('users/$uid/accounts/cash').set({'balance': 1000.0});
      final id = await repo.addExpense(
          amount: 100,
          currency: 'TRY',
          accountId: Account.cashId,
          baseAmount: 100,
          baseCurrency: 'TRY',
          fxRate: 1,
          date: d0);
      expect(await balanceOf(Account.cashId), 900);

      await repo.updateTx(id,
          type: TxType.expense,
          amount: 150,
          currency: 'TRY',
          date: d0,
          accountId: Account.cashId,
          baseAmount: 150,
          baseCurrency: 'TRY',
          fxRate: 1);
      expect(await balanceOf(Account.cashId), 850);

      await repo.deleteTx(id);
      expect(await balanceOf(Account.cashId), 1000);
    });
  });
}
