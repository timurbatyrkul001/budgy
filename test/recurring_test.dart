import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/recurring/recurring.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

const _uid = 'test-user';

/// Tekrarlayan işlemler: tarih matematiği + açılışta işleme (yetişme).
void main() {
  group('nextOccurrence', () {
    test('günlük / haftalık', () {
      expect(nextOccurrence(DateTime(2026, 1, 31), Recurrence.daily),
          DateTime(2026, 2, 1));
      expect(nextOccurrence(DateTime(2026, 1, 28), Recurrence.weekly),
          DateTime(2026, 2, 4));
    });

    test('aylık: 31 Ocak → 28 Şubat, artık yılda 29', () {
      expect(nextOccurrence(DateTime(2026, 1, 31), Recurrence.monthly),
          DateTime(2026, 2, 28));
      expect(nextOccurrence(DateTime(2028, 1, 31), Recurrence.monthly),
          DateTime(2028, 2, 29));
    });

    test('aylık: kırpılan gün anchorDay ile geri gelir', () {
      final feb = nextOccurrence(DateTime(2026, 1, 31), Recurrence.monthly);
      final mar = nextOccurrence(feb, Recurrence.monthly, anchorDay: 31);
      expect(mar, DateTime(2026, 3, 31));
      // anchorDay verilmezse 28'de kalırdı.
      expect(nextOccurrence(feb, Recurrence.monthly), DateTime(2026, 3, 28));
    });

    test('yıllık: 29 Şubat → 28 Şubat', () {
      expect(nextOccurrence(DateTime(2028, 2, 29), Recurrence.yearly),
          DateTime(2029, 2, 28));
    });

    test('aralık → ocak yıl atlar', () {
      expect(nextOccurrence(DateTime(2026, 12, 15), Recurrence.monthly),
          DateTime(2027, 1, 15));
    });
  });

  group('materializeRecurring', () {
    late FakeFirebaseFirestore db;
    late BudgetRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = BudgetRepository(db, _uid);
    });

    Future<List<Map<String, dynamic>>> txs() async =>
        (await db.collection('users').doc(_uid).collection('transactions').get())
            .docs
            .map((d) => d.data())
            .toList();

    Future<double> cash() async =>
        ((await db
                    .collection('users')
                    .doc(_uid)
                    .collection('accounts')
                    .doc('cash')
                    .get())
                .data()?['balance'] as num?)
            ?.toDouble() ??
        0;

    test('kural ilk tekrarı ileri tarihle yazar, bugün hiçbir şey işlemez',
        () async {
      final first = DateTime(2026, 9, 15);
      await repo.addRecurringRule(
        amount: 500,
        type: 'expense',
        currency: 'TRY',
        freq: Recurrence.monthly,
        firstDate: first,
        note: 'Kira',
      );
      final rule = (await repo.watchRecurringRules().first).single;
      expect(rule.nextDate, DateTime(2026, 10, 15));
      expect(rule.anchorDay, 15);

      expect(await repo.materializeRecurring(now: DateTime(2026, 9, 20)), 0);
      expect(await txs(), isEmpty);
    });

    test('vadesi gelen tüm tekrarları bugüne kadar işler ve nextDate ilerler',
        () async {
      await repo.addRecurringRule(
        amount: 100,
        type: 'expense',
        currency: 'TRY',
        freq: Recurrence.weekly,
        firstDate: DateTime(2026, 9, 1),
        note: 'Spor',
      );
      // 8, 15, 22 Eylül vadeli → 3 tekrar.
      final posted = await repo.materializeRecurring(now: DateTime(2026, 9, 23));
      expect(posted, 3);
      final list = await txs();
      expect(list, hasLength(3));
      expect(list.every((t) => t['type'] == 'expense' && t['amount'] == 100),
          isTrue);
      expect(await cash(), -300, reason: 'gider cüzdandan düşer');
      final rule = (await repo.watchRecurringRules().first).single;
      expect(rule.nextDate, DateTime(2026, 9, 29));

      // Tekrar çağrı → idempotent, yeni işlem yok.
      expect(await repo.materializeRecurring(now: DateTime(2026, 9, 23)), 0);
      expect(await txs(), hasLength(3));
    });

    test('gelir kuralı cüzdana ekler; döviz kuralı kumbara zarfına', () async {
      final usd = await repo.addCurrencyWallet(
        code: 'USD',
        name: 'USD cüzdanı',
        emoji: '💵',
        amount: 0,
        sortOrder: 0,
      );
      await repo.addRecurringRule(
        amount: 1000,
        type: 'income',
        currency: 'TRY',
        freq: Recurrence.monthly,
        firstDate: DateTime(2026, 8, 31),
        note: 'Maaş',
      );
      await repo.addRecurringRule(
        amount: 50,
        type: 'expense',
        currency: 'USD',
        freq: Recurrence.monthly,
        firstDate: DateTime(2026, 8, 10),
        envelopeId: usd,
        envelopeName: 'USD cüzdanı',
      );
      // Maaş: 30 Eylül (kırpma) vadeli; USD: 10 Eylül vadeli.
      final posted = await repo.materializeRecurring(now: DateTime(2026, 9, 30));
      expect(posted, 2);
      expect(await cash(), 1000);
      final usdSnap = await db
          .collection('users')
          .doc(_uid)
          .collection('envelopes')
          .doc(usd)
          .get();
      expect(usdSnap.data()!['balance'], -50);
      final list = await txs();
      final salary = list.firstWhere((t) => t['type'] == 'income');
      expect((salary['date'] as Timestamp).toDate(), DateTime(2026, 9, 30));
    });

    test('deleteRecurringRule kuralı kaldırır', () async {
      final id = await repo.addRecurringRule(
        amount: 10,
        type: 'expense',
        currency: 'TRY',
        freq: Recurrence.daily,
        firstDate: DateTime(2026, 9, 1),
      );
      await repo.deleteRecurringRule(id);
      expect(await repo.watchRecurringRules().first, isEmpty);
    });
  });

  group('materializeRecurring — hesaba bağlı kurallar', () {
    late FakeFirebaseFirestore db;
    late BudgetRepository repo;

    /// 1 ₼ = 1,97 ₺ (quick_entry_account_test ile aynı tablo, ₺ tabanlı).
    final fx = FxSnapshot(
      base: 'TRY',
      rates: {'AZN': 1 / 1.97},
      fetchedAt: DateTime(2026, 9, 30),
    );

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = BudgetRepository(db, _uid);
    });

    CollectionReference<Map<String, dynamic>> accounts() =>
        db.collection('users').doc(_uid).collection('accounts');

    Future<void> seedAccount(
      String id, {
      required String currency,
      double balance = 1000,
      bool archived = false,
      AccountKind kind = AccountKind.card,
    }) =>
        accounts().doc(id).set(
              Account(
                id: id,
                name: id,
                currency: currency,
                kind: kind,
                balance: balance,
                archived: archived,
              ).toMap(),
            );

    Future<double> balanceOf(String id) async =>
        ((await accounts().doc(id).get()).data()?['balance'] as num?)
            ?.toDouble() ??
        0;

    Future<List<Map<String, dynamic>>> txs() async =>
        (await db.collection('users').doc(_uid).collection('transactions').get())
            .docs
            .map((d) => d.data())
            .toList();

    Future<List<Tx>> txModels() async =>
        (await db.collection('users').doc(_uid).collection('transactions').get())
            .docs
            .map(Tx.fromDoc)
            .toList();

    Future<RecurringRule> rule() async =>
        (await repo.watchRecurringRules().first).single;

    /// Ağ hiç aranmamalı durumları yakalamak için sayan yükleyici.
    int fxCalls = 0;
    Future<FxSnapshot?> loadFx(String base) async {
      fxCalls++;
      expect(base, 'TRY', reason: 'tablo ana birim tabanlı istenir');
      return fx;
    }

    setUp(() => fxCalls = 0);

    test('ana birimdeki karttan kural: O KARTTAN düşer, nakit dokunulmaz',
        () async {
      await seedAccount('cash', currency: 'TRY', kind: AccountKind.cash);
      await seedAccount('enpara', currency: 'TRY', balance: 20000);
      await repo.addRecurringRule(
        amount: 15000,
        type: 'expense',
        currency: 'TRY',
        freq: Recurrence.monthly,
        firstDate: DateTime(2026, 8, 1),
        envelopeId: 'rent',
        envelopeName: 'Kira',
        note: 'Kira',
        accountId: 'enpara',
        accountName: 'Enpara',
      );

      final posted = await repo.materializeRecurring(
          now: DateTime(2026, 9, 1), loadFx: loadFx);

      expect(posted, 1);
      final tx = (await txs()).single;
      expect(tx['accountId'], 'enpara');
      expect(tx['currency'], 'TRY');
      expect(tx['amount'], 15000);
      expect(tx['envelopeId'], 'rent');
      // Aynı birim: kur 1 ile dondurulur, elle girişle aynı alanlar.
      expect(tx['baseAmount'], 15000);
      expect(tx['baseCurrency'], 'TRY');
      expect(tx['fxRate'], 1);
      expect(await balanceOf('enpara'), 5000, reason: 'kira karttan düştü');
      expect(await balanceOf('cash'), 1000, reason: 'nakit DOKUNULMADI');
      expect(fxCalls, 0, reason: 'aynı birimde ağa çıkılmaz');
      final r = await rule();
      expect(r.nextDate, DateTime(2026, 10, 1));
      expect(r.holdReason, isNull);
    });

    test('döviz karttan kural: kur dondurulur, ay toplamında görünür',
        () async {
      await seedAccount('cash', currency: 'TRY', kind: AccountKind.cash);
      await seedAccount('kapital', currency: 'AZN', balance: 500);
      await repo.addRecurringRule(
        amount: 50,
        type: 'expense',
        currency: 'AZN',
        freq: Recurrence.monthly,
        firstDate: DateTime(2026, 8, 10),
        envelopeId: 'sub',
        envelopeName: 'Abonelik',
        accountId: 'kapital',
        accountName: 'Kapital Bank',
      );

      final posted = await repo.materializeRecurring(
          now: DateTime(2026, 9, 30), loadFx: loadFx);

      expect(posted, 1);
      final tx = (await txModels()).single;
      expect(tx.accountId, 'kapital');
      expect(tx.currency, 'AZN');
      expect(tx.amount, 50);
      expect(tx.baseCurrency, 'TRY');
      expect(tx.baseAmount, 98.5);
      expect(tx.fxRate, closeTo(1.97, 1e-9));
      // Aylık toplamın okuduğu şey: 0 değil, çevrilmiş tutar.
      expect(tx.baseOr('TRY'), 98.5);
      // Bakiye kartın KENDİ biriminde: 500 ₼ − 50 ₼. Kategori zarfı yok.
      expect(await balanceOf('kapital'), 450);
      expect(await balanceOf('cash'), 1000);
      expect(fxCalls, 1);
    });

    test('yetişmede kur tablosu bir kez yüklenir, her tekrar aynı kurla',
        () async {
      await seedAccount('kapital', currency: 'AZN', balance: 500);
      await repo.addRecurringRule(
        amount: 10,
        type: 'expense',
        currency: 'AZN',
        freq: Recurrence.weekly,
        firstDate: DateTime(2026, 9, 1),
        accountId: 'kapital',
      );
      // 8, 15, 22 Eylül → 3 tekrar.
      final posted = await repo.materializeRecurring(
          now: DateTime(2026, 9, 23), loadFx: loadFx);
      expect(posted, 3);
      expect(fxCalls, 1);
      final list = await txs();
      expect(list, hasLength(3));
      expect(list.every((t) => t['baseAmount'] == 19.7), isTrue);
      expect(await balanceOf('kapital'), 470);
    });

    test('ESKİ hesapsız kural eskisi gibi: nakitten, hesap/kur alanı YOK',
        () async {
      // Hesaplar öncesi yazılmış belge: accountId alanı hiç yok.
      await db.collection('users').doc(_uid).collection('recurring').add({
        'amount': 500,
        'type': 'expense',
        'currency': 'TRY',
        'freq': 'monthly',
        'nextDate': Timestamp.fromDate(DateTime(2026, 9, 15)),
        'anchorDay': 15,
        'envelopeId': 'gym',
        'envelopeName': 'Spor',
      });
      // Kullanıcının bu arada kartları da olsun — kural onlara bakmamalı.
      await seedAccount('cash', currency: 'TRY', kind: AccountKind.cash);
      await seedAccount('enpara', currency: 'TRY');

      final posted = await repo.materializeRecurring(
          now: DateTime(2026, 9, 20), loadFx: loadFx);

      expect(posted, 1);
      final tx = (await txs()).single;
      expect(tx['amount'], 500);
      expect(tx['currency'], 'TRY');
      expect(tx['envelopeId'], 'gym');
      expect(tx.containsKey('accountId'), isFalse, reason: 'eski yol');
      expect(tx.containsKey('baseAmount'), isFalse);
      expect(tx.containsKey('baseCurrency'), isFalse);
      expect(tx.containsKey('fxRate'), isFalse);
      expect(await balanceOf('cash'), 500, reason: 'nakitten düştü');
      expect(await balanceOf('enpara'), 1000, reason: 'kart dokunulmadı');
      expect(fxCalls, 0, reason: 'hesapsız kural için ayar/kur okunmaz');
      // Eski kural için model de hesapsız; holdReason yok.
      final r = await rule();
      expect(r.accountId, isNull);
      expect(r.holdReason, isNull);
    });

    test('eski hesapsız döviz kuralı kumbara zarfından düşmeye devam eder',
        () async {
      final usd = await repo.addCurrencyWallet(
        code: 'USD',
        name: 'USD cüzdanı',
        emoji: '💵',
        amount: 200,
        sortOrder: 0,
      );
      await db.collection('users').doc(_uid).collection('recurring').add({
        'amount': 50,
        'type': 'expense',
        'currency': 'USD',
        'freq': 'monthly',
        'nextDate': Timestamp.fromDate(DateTime(2026, 9, 10)),
        'anchorDay': 10,
        'envelopeId': usd,
        'envelopeName': 'USD cüzdanı',
      });
      await repo.materializeRecurring(now: DateTime(2026, 9, 30), loadFx: loadFx);
      final env = await db
          .collection('users')
          .doc(_uid)
          .collection('envelopes')
          .doc(usd)
          .get();
      expect(env.data()!['balance'], 150);
      expect(fxCalls, 0);
    });

    group('hesap yok / arşivli → kural BEKLER, nextDate ilerlemez', () {
      Future<String> rentRule() => repo.addRecurringRule(
            amount: 15000,
            type: 'expense',
            currency: 'TRY',
            freq: Recurrence.monthly,
            firstDate: DateTime(2026, 8, 1),
            note: 'Kira',
            accountId: 'enpara',
            accountName: 'Enpara',
          );

      test('silinmiş hesap: işlem yok, nakit dokunulmadı, holdReason yazıldı',
          () async {
        await seedAccount('cash', currency: 'TRY', kind: AccountKind.cash);
        await rentRule(); // 'enpara' belgesi HİÇ yok

        final posted = await repo.materializeRecurring(
            now: DateTime(2026, 10, 1), loadFx: loadFx);

        expect(posted, 0);
        expect(await txs(), isEmpty);
        expect(await balanceOf('cash'), 1000,
            reason: 'sessizce nakitten düşülmedi');
        final r = await rule();
        expect(r.nextDate, DateTime(2026, 9, 1), reason: 'vade kaybolmadı');
        expect(r.holdReason, RecurringRule.holdAccountMissing);
      });

      test('arşivli hesap: aynı — paraya görünmeyen yere akıtılmaz',
          () async {
        await seedAccount('enpara', currency: 'TRY', archived: true);
        await rentRule();

        expect(
            await repo.materializeRecurring(
                now: DateTime(2026, 9, 1), loadFx: loadFx),
            0);
        expect(await txs(), isEmpty);
        expect(await balanceOf('enpara'), 1000);
        expect((await rule()).holdReason, RecurringRule.holdAccountMissing);
      });

      test('ikinci açılışta işaret zaten varsa belge yeniden yazılmaz',
          () async {
        await rentRule();
        await repo.materializeRecurring(now: DateTime(2026, 9, 1));
        final before = (await db
                .collection('users')
                .doc(_uid)
                .collection('recurring')
                .get())
            .docs
            .single
            .data();
        await repo.materializeRecurring(now: DateTime(2026, 9, 2));
        final after = (await db
                .collection('users')
                .doc(_uid)
                .collection('recurring')
                .get())
            .docs
            .single
            .data();
        expect(after, before);
      });

      test('hesap arşivden çıkınca biriken tekrarlar yetişir, işaret silinir',
          () async {
        await seedAccount('enpara', currency: 'TRY', balance: 50000,
            archived: true);
        await rentRule();
        await repo.materializeRecurring(now: DateTime(2026, 10, 5));
        expect(await txs(), isEmpty);

        await accounts().doc('enpara').set({'archived': false},
            SetOptions(merge: true));
        final posted = await repo.materializeRecurring(
            now: DateTime(2026, 10, 5), loadFx: loadFx);

        // 1 Eylül + 1 Ekim vadeleri — ikisi de yazıldı, hiçbiri kaybolmadı.
        expect(posted, 2);
        expect(await balanceOf('enpara'), 20000);
        final r = await rule();
        expect(r.nextDate, DateTime(2026, 11, 1));
        expect(r.holdReason, isNull);
      });

      test('bir kuralın engeli diğer kuralları durdurmaz', () async {
        await seedAccount('cash', currency: 'TRY', kind: AccountKind.cash);
        await rentRule(); // enpara yok → bekler
        await repo.addRecurringRule(
          amount: 100,
          type: 'expense',
          currency: 'TRY',
          freq: Recurrence.monthly,
          firstDate: DateTime(2026, 8, 1),
          note: 'Spor',
        );
        final posted = await repo.materializeRecurring(
            now: DateTime(2026, 9, 1), loadFx: loadFx);
        expect(posted, 1);
        expect((await txs()).single['note'], 'Spor');
        expect(await balanceOf('cash'), 900);
      });
    });

    group('kur yok → kural BEKLER, uydurma kurla yazılmaz', () {
      Future<String> subRule() => repo.addRecurringRule(
            amount: 50,
            type: 'expense',
            currency: 'AZN',
            freq: Recurrence.monthly,
            firstDate: DateTime(2026, 8, 10),
            accountId: 'kapital',
          );

      test('yükleyici null (çevrimdışı): işlem yok, nextDate aynı, hold',
          () async {
        await seedAccount('kapital', currency: 'AZN', balance: 500);
        await subRule();

        final posted = await repo.materializeRecurring(
            now: DateTime(2026, 9, 30), loadFx: (_) async => null);

        expect(posted, 0);
        expect(await txs(), isEmpty);
        expect(await balanceOf('kapital'), 500);
        final r = await rule();
        expect(r.nextDate, DateTime(2026, 9, 10));
        expect(r.holdReason, RecurringRule.holdFxUnavailable);
      });

      test('yükleyici verilmedi ya da fırlattı: aynı şekilde bekler',
          () async {
        await seedAccount('kapital', currency: 'AZN');
        await subRule();
        expect(await repo.materializeRecurring(now: DateTime(2026, 9, 30)), 0);
        expect(
            await repo.materializeRecurring(
                now: DateTime(2026, 9, 30),
                loadFx: (_) async => throw StateError('ağ')),
            0);
        expect(await txs(), isEmpty);
        expect((await rule()).holdReason, RecurringRule.holdFxUnavailable);
      });

      test('tabloda çift yok (KZT): bekler, sıfır/bir kurla yazmaz', () async {
        await seedAccount('kaspi', currency: 'KZT');
        await repo.addRecurringRule(
          amount: 5000,
          type: 'expense',
          currency: 'KZT',
          freq: Recurrence.monthly,
          firstDate: DateTime(2026, 8, 10),
          accountId: 'kaspi',
        );
        expect(
            await repo.materializeRecurring(
                now: DateTime(2026, 9, 30), loadFx: loadFx),
            0);
        expect(await txs(), isEmpty);
        expect((await rule()).holdReason, RecurringRule.holdFxUnavailable);
      });

      test('kur gelince biriken tekrarlar yetişir, işaret silinir', () async {
        await seedAccount('kapital', currency: 'AZN', balance: 500);
        await subRule();
        await repo.materializeRecurring(
            now: DateTime(2026, 10, 15), loadFx: (_) async => null);
        expect(await txs(), isEmpty);

        final posted = await repo.materializeRecurring(
            now: DateTime(2026, 10, 15), loadFx: loadFx);
        // 10 Eylül + 10 Ekim.
        expect(posted, 2);
        expect(await balanceOf('kapital'), 400);
        final list = await txModels();
        expect(list.map((t) => t.baseOr('TRY')), everyElement(98.5));
        final r = await rule();
        expect(r.nextDate, DateTime(2026, 11, 10));
        expect(r.holdReason, isNull);
      });

      test('kur yokken ana birimdeki kart kuralı yine işlenir', () async {
        await seedAccount('enpara', currency: 'TRY');
        await seedAccount('kapital', currency: 'AZN');
        await subRule();
        await repo.addRecurringRule(
          amount: 100,
          type: 'expense',
          currency: 'TRY',
          freq: Recurrence.monthly,
          firstDate: DateTime(2026, 8, 10),
          accountId: 'enpara',
        );
        final posted = await repo.materializeRecurring(
            now: DateTime(2026, 9, 30), loadFx: (_) async => null);
        expect(posted, 1);
        expect((await txs()).single['accountId'], 'enpara');
        expect(await balanceOf('enpara'), 900);
        expect(await balanceOf('kapital'), 1000);
      });
    });

    test('nakit hesabına bağlı kural, ana birim ₸: çevrim YOK, ağ YOK',
        () async {
      await db
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('main')
          .set({'currency': 'KZT'});
      // Eski göçün bıraktığı gibi: belgede 'TRY' yazıyor.
      await accounts().doc('cash').set({'balance': 50000, 'currency': 'TRY'});
      await repo.addRecurringRule(
        amount: 5000,
        type: 'expense',
        currency: 'KZT',
        freq: Recurrence.monthly,
        firstDate: DateTime(2026, 8, 1),
        accountId: Account.cashId,
      );

      final posted = await repo.materializeRecurring(
          now: DateTime(2026, 9, 1),
          loadFx: (_) async => throw StateError('ağa çıkılmamalı'));

      expect(posted, 1);
      final tx = (await txModels()).single;
      expect(tx.accountId, 'cash');
      expect(tx.currency, 'KZT');
      expect(tx.baseAmount, 5000);
      expect(tx.baseCurrency, 'KZT');
      expect(tx.fxRate, 1);
      expect(tx.baseOr('KZT'), 5000);
      expect(await balanceOf('cash'), 45000);
    });

    test('nakit belgesi henüz yokken nakit kuralı belgeyi açar (set+merge)',
        () async {
      await repo.addRecurringRule(
        amount: 100,
        type: 'expense',
        currency: 'TRY',
        freq: Recurrence.monthly,
        firstDate: DateTime(2026, 8, 1),
        accountId: Account.cashId,
      );
      expect(await repo.materializeRecurring(now: DateTime(2026, 9, 1)), 1);
      expect(await balanceOf('cash'), -100);
      expect((await txs()).single['accountId'], 'cash');
    });

    test('hesaba bağlı GELİR kuralı: para o karta girer, kur donar',
        () async {
      await seedAccount('cash', currency: 'TRY', kind: AccountKind.cash);
      await seedAccount('kapital', currency: 'AZN', balance: 500);
      await repo.addRecurringRule(
        amount: 300,
        type: 'income',
        currency: 'AZN',
        freq: Recurrence.monthly,
        firstDate: DateTime(2026, 8, 5),
        envelopeId: 'salary',
        envelopeName: 'Maaş',
        accountId: 'kapital',
      );
      final posted = await repo.materializeRecurring(
          now: DateTime(2026, 9, 5), loadFx: loadFx);
      expect(posted, 1);
      final tx = (await txModels()).single;
      expect(tx.type, TxType.income);
      expect(tx.accountId, 'kapital');
      expect(tx.currency, 'AZN');
      expect(tx.envelopeId, 'salary', reason: 'kaynak etiketi korunur');
      expect(tx.baseAmount, 591);
      expect(tx.fxRate, closeTo(1.97, 1e-9));
      expect(await balanceOf('kapital'), 800);
      expect(await balanceOf('cash'), 1000);
    });

    test('kural belgesi accountId/accountName taşır ve geri okunur', () async {
      await repo.addRecurringRule(
        amount: 1,
        type: 'expense',
        currency: 'TRY',
        freq: Recurrence.daily,
        firstDate: DateTime(2026, 9, 1),
        accountId: 'enpara',
        accountName: 'Enpara',
      );
      final r = await rule();
      expect(r.accountId, 'enpara');
      expect(r.accountName, 'Enpara');
    });
  });

  group('setTxCategory', () {
    test('yalnız etiket alanları değişir, bakiye aynı kalır', () async {
      final db = FakeFirebaseFirestore();
      final repo = BudgetRepository(db, _uid);
      final id = await repo.addExpense(amount: 200);
      await repo.setTxCategory(id, envelopeId: 'e1', envelopeName: 'Market');
      final tx = (await db
              .collection('users')
              .doc(_uid)
              .collection('transactions')
              .doc(id)
              .get())
          .data()!;
      expect(tx['envelopeId'], 'e1');
      expect(tx['envelopeName'], 'Market');
      expect(tx['envelopeIds'], ['e1']);
      expect(tx['amount'], 200);
    });
  });
}
