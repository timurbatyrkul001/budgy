import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/account_suggestion.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

/// `suggestAccount`: üç öncelik kuralı, arşiv/silinmiş hesap koruması,
/// boş girdi, "en son kazanır", 30 gün penceresi.
void main() {
  final now = DateTime(2026, 10, 1, 12);

  Account acc(String id, {bool archived = false}) => Account(
        id: id,
        name: id,
        currency: 'TRY',
        kind: AccountKind.card,
        balance: 0,
        archived: archived,
      );

  Tx spend(
    String account, {
    required int daysAgo,
    String? category,
    TxType type = TxType.expense,
    bool convert = false,
  }) =>
      Tx(
        id: '$account-$daysAgo-$category',
        type: type,
        amount: 10,
        date: now.subtract(Duration(days: daysAgo)),
        envelopeId: category,
        accountId: account,
        isConvert: convert,
      );

  final enpara = acc('enpara');
  final garanti = acc('garanti');
  final cash = acc('cash');

  group('Kural 1: kategoride en son kullanılan', () {
    test('kategoride geçmiş varsa o hesap önerilir', () {
      final id = suggestAccount(
        accounts: [cash, enpara, garanti],
        recent: [
          spend('garanti', daysAgo: 1), // kategorisiz, daha yeni — sayılmaz
          spend('enpara', daysAgo: 3, category: 'market'),
          spend('cash', daysAgo: 2, category: 'kahve'),
        ],
        categoryId: 'market',
        now: now,
      );
      expect(id, 'enpara');
    });

    test('aynı kategoride iki hesap varsa EN SON kullanılan kazanır', () {
      // Enpara 5 kez ama eski; Garanti bir kez ama en son — Garanti.
      final id = suggestAccount(
        accounts: [enpara, garanti],
        recent: [
          spend('garanti', daysAgo: 1, category: 'market'),
          for (var d = 2; d <= 6; d++)
            spend('enpara', daysAgo: d, category: 'market'),
        ],
        categoryId: 'market',
        now: now,
      );
      expect(id, 'garanti');
    });

    test('liste sırasına güvenmez: tarihe bakar', () {
      // Eskiden yeniye verilmiş (ters sıra) — yine en yeni olan seçilmeli.
      final id = suggestAccount(
        accounts: [enpara, garanti],
        recent: [
          spend('enpara', daysAgo: 10, category: 'market'),
          spend('garanti', daysAgo: 1, category: 'market'),
        ],
        categoryId: 'market',
        now: now,
      );
      expect(id, 'garanti');
    });

    test('kategori 30 günden eski olsa da geçerli — alışkanlık uzun ömürlü',
        () {
      final id = suggestAccount(
        accounts: [cash, enpara],
        recent: [
          spend('cash', daysAgo: 1),
          spend('enpara', daysAgo: 90, category: 'kira'),
        ],
        categoryId: 'kira',
        now: now,
      );
      expect(id, 'enpara');
    });
  });

  group('Kural 2: son 30 günde en sık', () {
    test('kategori yoksa en sık kullanılan hesap', () {
      final id = suggestAccount(
        accounts: [cash, enpara, garanti],
        recent: [
          spend('garanti', daysAgo: 1),
          spend('enpara', daysAgo: 2),
          spend('enpara', daysAgo: 3),
          spend('enpara', daysAgo: 4),
          spend('garanti', daysAgo: 5),
        ],
        now: now,
      );
      expect(id, 'enpara');
    });

    test('kategoride geçmiş yoksa sıklığa düşer', () {
      final id = suggestAccount(
        accounts: [cash, enpara],
        recent: [
          spend('enpara', daysAgo: 1, category: 'market'),
          spend('enpara', daysAgo: 2, category: 'market'),
        ],
        categoryId: 'yeni-kategori',
        now: now,
      );
      expect(id, 'enpara');
    });

    test('30 günden eski işlemler sayıma girmez', () {
      // Garanti 10 kez ama hepsi 31+ gün önce; Enpara 1 kez dün.
      final id = suggestAccount(
        accounts: [cash, enpara, garanti],
        recent: [
          spend('enpara', daysAgo: 1),
          for (var d = 31; d <= 40; d++) spend('garanti', daysAgo: d),
        ],
        now: now,
      );
      expect(id, 'enpara');
    });

    test('beraberlikte daha yakın zamanda kullanılan kazanır', () {
      final id = suggestAccount(
        accounts: [enpara, garanti],
        recent: [
          spend('garanti', daysAgo: 1),
          spend('enpara', daysAgo: 2),
          spend('enpara', daysAgo: 3),
          spend('garanti', daysAgo: 4),
        ],
        now: now,
      );
      expect(id, 'garanti');
    });

    test('gelir ve döviz çevirme sinyal sayılmaz', () {
      // Maaş Garanti'ye yatıyor (income), döviz de Garanti'den — ama
      // harcama hep Enpara'dan.
      final id = suggestAccount(
        accounts: [enpara, garanti],
        recent: [
          spend('garanti', daysAgo: 1, type: TxType.income),
          spend('garanti', daysAgo: 2, type: TxType.income),
          spend('garanti', daysAgo: 3, convert: true),
          spend('enpara', daysAgo: 4),
        ],
        now: now,
      );
      expect(id, 'enpara');
    });
  });

  group('Kural 3: listedeki ilk hesap', () {
    test('hiç geçmiş yoksa ilk hesap', () {
      final id = suggestAccount(
        accounts: [cash, enpara],
        recent: const [],
        categoryId: 'market',
        now: now,
      );
      expect(id, 'cash');
    });

    test('accountId olmayan eski işlemler görmezden gelinir', () {
      final old = Tx(
        id: 'old',
        type: TxType.expense,
        amount: 5,
        date: now.subtract(const Duration(days: 1)),
        envelopeId: 'market',
      );
      final id = suggestAccount(
        accounts: [garanti, enpara],
        recent: [old],
        categoryId: 'market',
        now: now,
      );
      expect(id, 'garanti');
    });
  });

  group('Koruma', () {
    test('arşivlenmiş hesap önerilmez — kural 1', () {
      final id = suggestAccount(
        accounts: [cash, acc('enpara', archived: true)],
        recent: [spend('enpara', daysAgo: 1, category: 'market')],
        categoryId: 'market',
        now: now,
      );
      expect(id, 'cash');
    });

    test('listede olmayan (silinmiş) hesap önerilmez — kural 2', () {
      final id = suggestAccount(
        accounts: [cash],
        recent: [
          spend('silinmis', daysAgo: 1),
          spend('silinmis', daysAgo: 2),
        ],
        now: now,
      );
      expect(id, 'cash');
    });

    test('hiç hesap yoksa null', () {
      expect(
        suggestAccount(accounts: const [], recent: const [], now: now),
        isNull,
      );
    });

    test('yalnız arşivli hesap varsa null', () {
      expect(
        suggestAccount(
          accounts: [acc('x', archived: true)],
          recent: [spend('x', daysAgo: 1)],
          now: now,
        ),
        isNull,
      );
    });
  });
}
