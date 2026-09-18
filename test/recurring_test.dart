import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/recurring/recurring.dart';

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
