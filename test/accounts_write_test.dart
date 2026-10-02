import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';

/// Harcamanın SEÇİLEN karttan düşmesi ve kurun işlem anında dondurulması.
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
}
