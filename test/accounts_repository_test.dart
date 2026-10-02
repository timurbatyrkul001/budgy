import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';

const _uid = 'test-user';

extension on FakeFirebaseFirestore {
  CollectionReference<Map<String, dynamic>> get accounts =>
      collection('users').doc(_uid).collection('accounts');
  CollectionReference<Map<String, dynamic>> get transactions =>
      collection('users').doc(_uid).collection('transactions');
}

void main() {
  late FakeFirebaseFirestore db;
  late AccountsRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = AccountsRepository(db, _uid);
  });

  Future<List<Account>> current() => repo.watchAccounts().first;

  group('add', () {
    test('ilk hesap sortOrder 0, sonrakiler artarak', () async {
      final a = await repo.add(
        name: 'Enpara',
        currency: 'TRY',
        kind: AccountKind.card,
      );
      final b = await repo.add(
        name: 'Azeri kart',
        currency: 'AZN',
        kind: AccountKind.card,
      );

      final list = await current();
      expect(list.map((x) => x.id), [a, b]);
      expect(list.map((x) => x.sortOrder), [0, 1]);
      expect(list[1].currency, 'AZN');
    });

    test('sortOrder mevcut `cash` belgesinden sonra devam eder', () async {
      await db.accounts.doc(Account.cashId).set({'balance': 100});
      final id = await repo.add(
        name: 'Enpara',
        currency: 'TRY',
        kind: AccountKind.card,
      );

      final list = await current();
      // Eski cash sortOrder'sız (0) → yeni kart 1 alır, nakit önde kalır.
      expect(list.map((x) => x.id), [Account.cashId, id]);
      expect(list.last.sortOrder, 1);
    });

    test('arşivli hesapların sortOrder\'ı da hesaba katılır', () async {
      await db.accounts.add({
        'name': 'Eski',
        'currency': 'TRY',
        'kind': 'card',
        'balance': 0,
        'sortOrder': 7,
        'archived': true,
      });
      await repo.add(name: 'Yeni', currency: 'TRY', kind: AccountKind.card);
      final list = await current();
      expect(list.single.sortOrder, 8);
    });
  });

  group('archive', () {
    test('arşivlenen hesap listeden düşer, belge kalır', () async {
      final id = await repo.add(
        name: 'Azeri kart',
        currency: 'AZN',
        kind: AccountKind.card,
      );
      await repo.archive(id);

      expect(await current(), isEmpty);
      final doc = await db.accounts.doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['archived'], isTrue);
    });

    test('arşivden çıkarınca geri gelir', () async {
      final id = await repo.add(
        name: 'Azeri kart',
        currency: 'AZN',
        kind: AccountKind.card,
      );
      await repo.archive(id);
      await repo.archive(id, archived: false);
      expect((await current()).single.id, id);
    });

    test('nakit arşivlenemez', () async {
      await db.accounts.doc(Account.cashId).set({'balance': 100});
      expect(() => repo.archive(Account.cashId), throwsStateError);
      // Belgeye dokunulmadı.
      final doc = await db.accounts.doc(Account.cashId).get();
      expect(doc.data(), {'balance': 100});
    });
  });

  group('transactionCount / delete', () {
    /// Sahte işlem belgesi: depo yalnız `accountId` alanına bakar, gerisi
    /// burada önemsiz.
    Future<void> seedTx(String? accountId) => db.transactions.add({
          'type': 'expense',
          'amount': 10,
          'currency': 'TRY',
          'accountId': ?accountId,
        });

    test('transactionCount yalnız o hesabın işlemlerini sayar', () async {
      await seedTx('enpara');
      await seedTx('enpara');
      await seedTx('kapital');
      await seedTx(null); // eski dönem kaydı, hesapsız

      expect(await repo.transactionCount('enpara'), 2);
      expect(await repo.transactionCount('kapital'), 1);
      expect(await repo.transactionCount('yok'), 0);
    });

    test('işlemsiz hesap tamamen silinir', () async {
      final id = await repo.add(
        name: 'Yanlış kart',
        currency: 'TRY',
        kind: AccountKind.card,
      );
      await seedTx('baska-hesap'); // başka hesabın işlemi engel değil

      await repo.delete(id);

      expect((await db.accounts.doc(id).get()).exists, isFalse);
      expect(await current(), isEmpty);
    });

    test('işlemi olan hesap silinemez, belge kalır', () async {
      final id = await repo.add(
        name: 'Kullanılan kart',
        currency: 'TRY',
        kind: AccountKind.card,
      );
      await seedTx(id);

      await expectLater(repo.delete(id), throwsStateError);
      expect((await db.accounts.doc(id).get()).exists, isTrue);
    });

    test('nakit silinemez — işlemi olmasa bile', () async {
      await db.accounts.doc(Account.cashId).set({'balance': 100});

      await expectLater(repo.delete(Account.cashId), throwsStateError);
      final doc = await db.accounts.doc(Account.cashId).get();
      expect(doc.data(), {'balance': 100});
    });
  });

  group('watchAccounts', () {
    test(
      'yalnız `balance` alanı olan eski cash belgesi listede çıkar',
      () async {
        await db.accounts.doc(Account.cashId).set({'balance': 1250.5});

        final list = await current();
        final cash = list.single;
        expect(cash.id, Account.cashId);
        expect(cash.isCash, isTrue);
        expect(cash.kind, AccountKind.cash);
        expect(cash.currency, 'TRY');
        expect(cash.balance, 1250.5);
        expect(cash.archived, isFalse);
      },
    );

    test('sortOrder\'a göre sıralar', () async {
      final b = await repo.add(
        name: 'B',
        currency: 'TRY',
        kind: AccountKind.card,
        sortOrder: 5,
      );
      final a = await repo.add(
        name: 'A',
        currency: 'TRY',
        kind: AccountKind.card,
        sortOrder: 2,
      );
      expect((await current()).map((x) => x.id), [a, b]);
    });
  });

  group('reorder', () {
    test('verilen sıraya 0..n yazar', () async {
      final a = await repo.add(
        name: 'A',
        currency: 'TRY',
        kind: AccountKind.card,
      );
      final b = await repo.add(
        name: 'B',
        currency: 'TRY',
        kind: AccountKind.card,
      );
      final c = await repo.add(
        name: 'C',
        currency: 'TRY',
        kind: AccountKind.card,
      );

      await repo.reorder([c, a, b]);

      final list = await current();
      expect(list.map((x) => x.id), [c, a, b]);
      expect(list.map((x) => x.sortOrder), [0, 1, 2]);
    });
  });

  group('rename / setBalance', () {
    test('rename yalnız görünüm alanlarını değiştirir', () async {
      final id = await repo.add(
        name: 'Kart',
        currency: 'AZN',
        kind: AccountKind.card,
        balance: 50,
      );
      await repo.rename(id, name: 'Kapital', emoji: '💳', last4: '4421');

      final acc = (await current()).single;
      expect(acc.name, 'Kapital');
      expect(acc.emoji, '💳');
      expect(acc.last4, '4421');
      expect(acc.currency, 'AZN');
      expect(acc.balance, 50);
    });

    test(
      'setBalance kuruşa yuvarlar; eski cash belgesinde de çalışır',
      () async {
        await db.accounts.doc(Account.cashId).set({'balance': 1});
        await repo.setBalance(Account.cashId, 0.1 + 0.2);
        final doc = await db.accounts.doc(Account.cashId).get();
        expect(doc.data()!['balance'], 0.3);
      },
    );
  });

  group('nakit birimi = ana birim', () {
    DocumentReference<Map<String, dynamic>> settings() =>
        db.collection('users').doc(_uid).collection('settings').doc('main');

    test('ayar yoksa ₺ (eski varsayılan)', () async {
      await db.accounts.doc(Account.cashId).set({'balance': 10});
      expect((await current()).single.currency, 'TRY');
    });

    test('ana birim ₸: belgede TRY yazsa da nakit ₸, kart kendi biriminde',
        () async {
      await settings().set({'currency': 'KZT'});
      // Eski göçün yazdığı gibi.
      await db.accounts
          .doc(Account.cashId)
          .set({'balance': 50000, 'currency': 'TRY'});
      await repo.add(name: 'Kaspi', currency: 'KZT', kind: AccountKind.card);
      await repo.add(name: 'Enpara', currency: 'TRY', kind: AccountKind.card);

      final list = await current();
      expect(list.map((a) => a.currency), ['KZT', 'KZT', 'TRY']);
      expect(list.first.isCash, isTrue);
      expect(list.first.balance, 50000, reason: 'bakiye çevrilmez');
      // Belge değişmedi — okuma anında kural.
      final doc = await db.accounts.doc(Account.cashId).get();
      expect(doc.data()!['currency'], 'TRY');
    });

    test('ana birim değişince akış nakdi yeni birimle yeniden yayınlar',
        () async {
      await db.accounts.doc(Account.cashId).set({'balance': 10});
      final seen = <String>[];
      final sub = repo.watchAccounts().listen(
            (list) => seen.add(list.single.currency),
          );
      await Future<void>.delayed(Duration.zero);
      await settings().set({'currency': 'USD'});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen.first, 'TRY');
      expect(seen.last, 'USD');
    });

    test('withMainCurrency yalnız nakde dokunur', () {
      const cash = Account(
          id: Account.cashId,
          name: '',
          currency: 'TRY',
          kind: AccountKind.cash,
          balance: 5);
      const card = Account(
          id: 'c', name: 'K', currency: 'AZN', kind: AccountKind.card, balance: 5);
      expect(cash.withMainCurrency('KZT').currency, 'KZT');
      expect(cash.withMainCurrency('KZT').balance, 5);
      expect(identical(cash.withMainCurrency('TRY'), cash), isTrue);
      expect(identical(card.withMainCurrency('KZT'), card), isTrue);
    });
  });

  group('providers', () {
    /// Riverpod 3: dinleyicisi olmayan provider bir sonraki döngüde
    /// atılır, `read(.future)` yüklenirken askıda kalır. Testte canlı
    /// tutmak için boş bir dinleyici takıyoruz.
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [accountsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.listen(accountsProvider, (_, _) {});
      return c;
    }

    test('defaultAccountProvider ilk sıradaki hesaptır', () async {
      await db.accounts.doc(Account.cashId).set({'balance': 10});
      await repo.add(name: 'Enpara', currency: 'TRY', kind: AccountKind.card);

      final c = container();
      final list = await c.read(accountsProvider.future);
      expect(list.length, 2);
      expect(c.read(defaultAccountProvider).id, Account.cashId);
    });

    test('hiç hesap yoksa nakit', () async {
      final c = container();
      await c.read(accountsProvider.future);
      final d = c.read(defaultAccountProvider);
      expect(d.id, Account.cashId);
      expect(d.kind, AccountKind.cash);
      expect(d.currency, 'TRY');
    });
  });
}
