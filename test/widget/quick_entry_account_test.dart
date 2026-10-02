import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/account_picker.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Hızlı girişte hesap (kart) seçimi ve kurun kayıt anında dondurulması:
/// çip yalnız iki+ hesapta görünür, tek hesapta akış eskisi gibi; manat
/// kartından harcama `baseAmount`/`fxRate` ile yazılır; kur yoksa kayıt
/// YAPILMAZ ve form dolu kalır; elle seçilen kart kategori değişince öneriyle
/// ezilmez. Gelirde de aynı çip: para karta GİRER, kur yine donar.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  const cash = Account(
    id: Account.cashId,
    name: 'Nakit',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 1000,
    sortOrder: 0,
  );
  const enpara = Account(
    id: 'a1',
    name: 'Enpara',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 1000,
    sortOrder: 1,
  );
  const kapital = Account(
    id: 'a2',
    name: 'Kapital Bank',
    currency: 'AZN',
    kind: AccountKind.card,
    balance: 500,
    sortOrder: 2,
  );

  /// 1 ₼ = 1,97 ₺ — tablo ana birim (TRY) tabanlı, gerçek kaynaktaki gibi:
  /// rates['AZN'] = 1 ₺ kaç ₼. Ekran çapraz kurdan 1/0.5076… = 1.97 çıkarır.
  final fx = FxSnapshot(
    base: 'TRY',
    rates: {'AZN': 1 / 1.97, 'USD': 1 / 41.0},
    fetchedAt: DateTime.now(),
  );

  Future<void> seed(
    FakeFirebaseFirestore db,
    Iterable<Account> accounts,
  ) async {
    for (final a in accounts) {
      await db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());
    }
  }

  /// Gerçek `accountsRepositoryProvider` `uidProvider`'a bağlı ve testte
  /// fırlatır; harness'ta hesap deposu için override yok. Ekranı sahte
  /// depoyla iç içe bir scope'a sarıyoruz (accounts_screen_test ile aynı).
  Widget scoped(FakeFirebaseFirestore db, Widget child) {
    final repo = AccountsRepository(db, testUid);
    return ProviderScope(
      overrides: [
        accountsRepositoryProvider.overrideWithValue(repo),
        accountsProvider.overrideWith((ref) => repo.watchAccounts()),
      ],
      child: child,
    );
  }

  Future<FakeFirebaseFirestore> pumpEntry(
    WidgetTester tester, {
    required Iterable<Account> accounts,
    FxSnapshot? fxSnapshot,
    List<Tx> transactions = const [],
    List<Envelope> envelopes = const [],
  }) async {
    final db = FakeFirebaseFirestore();
    await seed(db, accounts);
    await pumpBudgyScreen(
      tester,
      scoped(db, const QuickEntryScreen()),
      db: db,
      language: AppLanguage.tr,
      fxSnapshot: fxSnapshot,
      transactions: transactions,
      envelopes: envelopes,
    );
    return db;
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final k in digits.split('')) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, RS.tr.save));
    await tester.pumpAndSettle();
  }

  /// Çipe dokun → sheet → [accountId] satırı.
  Future<void> pickCard(WidgetTester tester, String accountId) async {
    await tester.tap(find.byType(AccountChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('account-row-$accountId')));
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, dynamic>>> txs(FakeFirebaseFirestore db) async {
    final snap = await db
        .collection('users')
        .doc(testUid)
        .collection('transactions')
        .get();
    return [for (final d in snap.docs) d.data()];
  }

  Future<double> balanceOf(FakeFirebaseFirestore db, String id) async {
    final doc = await db.doc('users/$testUid/accounts/$id').get();
    return (doc.data()!['balance'] as num).toDouble();
  }

  Account chipAccount(WidgetTester tester) =>
      tester.widget<AccountChip>(find.byType(AccountChip)).account;

  testWidgets('iki kart → kart çipi görünür', (tester) async {
    await pumpEntry(tester, accounts: const [enpara, kapital]);
    expect(find.byType(AccountChip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tek hesap → çip yok, kayıt eskisi gibi tek kasadan düşer', (
    tester,
  ) async {
    final db = await pumpEntry(tester, accounts: const [cash]);
    expect(find.byType(AccountChip), findsNothing);

    await type(tester, '2000');
    await save(tester);

    final all = await txs(db);
    expect(all, hasLength(1));
    final tx = all.single;
    expect(tx['amount'], 2000);
    expect(tx['currency'], 'TRY');
    expect(
      tx.containsKey('accountId'),
      isFalse,
      reason: 'hesap seçimi devrede değil — eski yol',
    );
    expect(tx.containsKey('baseAmount'), isFalse);
    expect(tx.containsKey('fxRate'), isFalse);
    expect(await balanceOf(db, Account.cashId), 1000 - 2000);
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('manat kartından 40 ₼: kur dondurulur, baseAmount 78,8 ₺', (
    tester,
  ) async {
    final db = await pumpEntry(
      tester,
      accounts: const [cash, kapital],
      fxSnapshot: fx,
    );
    // Tutarın yanındaki simge girilen paranın birimi: kart seçilince ₺
    // gider, yerine kartın birimi gelir (AZN'nin tabloda simgesi yok, kod
    // yazılır — çipte de aynı kod olduğu için ₺'nin yokluğunu sınıyoruz).
    // ₺ iki yerde: üst para birimi çipi + büyük tutar; ikisi de kartı izler.
    expect(find.text('₺'), findsNWidgets(2));
    await pickCard(tester, 'a2');
    expect(chipAccount(tester).id, 'a2');
    expect(find.text('₺'), findsNothing);

    await type(tester, '40');
    await save(tester);

    final all = await txs(db);
    expect(all, hasLength(1));
    final tx = all.single;
    expect(tx['amount'], 40);
    expect(tx['currency'], 'AZN');
    expect(tx['accountId'], 'a2');
    expect(tx['baseAmount'], 78.8);
    expect(tx['baseCurrency'], 'TRY');
    expect(tx['fxRate'], closeTo(1.97, 1e-9));
    // Para kartın KENDİ biriminde düşer: 500 ₼ − 40 ₼.
    expect(await balanceOf(db, 'a2'), 460);
    expect(
      await balanceOf(db, Account.cashId),
      1000,
      reason: 'nakit dokunulmadı',
    );
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('kur yok → kayıt YAPILMAZ, mesaj çıkar, form dolu kalır', (
    tester,
  ) async {
    final db = await pumpEntry(
      tester,
      accounts: const [cash, kapital],
      fxSnapshot: null,
    );
    await pickCard(tester, 'a2');
    await type(tester, '40');
    await save(tester);

    expect(await txs(db), isEmpty, reason: 'kursuz kayıt ay toplamını bozar');
    expect(await balanceOf(db, 'a2'), 500);
    expect(find.text(RS.tr.fxFreezeUnavailable), findsOneWidget);
    // Ekran açık, kart seçimi yerinde; Kaydet etkin = tutar hâlâ dolu.
    expect(find.byType(QuickEntryScreen), findsOneWidget);
    expect(chipAccount(tester).id, 'a2');
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, RS.tr.save),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('kur yok ama kart ana birimde → kayıt geçer (ağ gerekmez)', (
    tester,
  ) async {
    final db = await pumpEntry(
      tester,
      accounts: const [cash, enpara],
      fxSnapshot: null,
    );
    await pickCard(tester, 'a1');
    await type(tester, '150');
    await save(tester);

    final all = await txs(db);
    expect(all, hasLength(1));
    final tx = all.single;
    expect(tx['accountId'], 'a1');
    expect(tx['currency'], 'TRY');
    expect(tx['baseAmount'], 150);
    expect(tx['baseCurrency'], 'TRY');
    expect(tx['fxRate'], 1);
    expect(await balanceOf(db, 'a1'), 850);
  });

  group('gelir', () {
    Future<void> toIncome(WidgetTester tester) async {
      await tester.tap(find.text(RS.tr.income));
      await tester.pumpAndSettle();
    }

    testWidgets('iki hesap → gelirde de çip var; 5000 ₺ Enpara\'ya girer', (
      tester,
    ) async {
      final db = await pumpEntry(tester, accounts: const [cash, enpara]);
      await toIncome(tester);
      expect(find.byType(AccountChip), findsOneWidget);
      await pickCard(tester, 'a1');
      expect(chipAccount(tester).id, 'a1');

      await type(tester, '5000');
      await save(tester);

      final all = await txs(db);
      expect(all, hasLength(1));
      final tx = all.single;
      expect(tx['type'], 'income');
      expect(tx['amount'], 5000);
      expect(tx['currency'], 'TRY');
      expect(tx['accountId'], 'a1');
      expect(tx['baseAmount'], 5000);
      expect(tx['fxRate'], 1);
      // Para karta GİRDİ: 1000 + 5000. Nakit dokunulmadı.
      expect(await balanceOf(db, 'a1'), 6000);
      expect(await balanceOf(db, Account.cashId), 1000);
      expect(find.byType(QuickEntryScreen), findsNothing);
    });

    testWidgets('manat kartına 300 ₼ gelir: baseAmount 591, fxRate 1.97', (
      tester,
    ) async {
      final db = await pumpEntry(
        tester,
        accounts: const [cash, kapital],
        fxSnapshot: fx,
      );
      await toIncome(tester);
      await pickCard(tester, 'a2');
      expect(find.text('₺'), findsNothing, reason: 'simge kartın birimi');

      await type(tester, '300');
      await save(tester);

      final tx = (await txs(db)).single;
      expect(tx['type'], 'income');
      expect(tx['amount'], 300);
      expect(tx['currency'], 'AZN');
      expect(tx['accountId'], 'a2');
      expect(tx['baseAmount'], 591);
      expect(tx['baseCurrency'], 'TRY');
      expect(tx['fxRate'], closeTo(1.97, 1e-9));
      // Bakiye kartın KENDİ biriminde artar: 500 ₼ + 300 ₼.
      expect(await balanceOf(db, 'a2'), 800);
      expect(await balanceOf(db, Account.cashId), 1000);
    });

    testWidgets('gelirde kur yok → kayıt YAPILMAZ, gelir mesajı çıkar', (
      tester,
    ) async {
      final db = await pumpEntry(
        tester,
        accounts: const [cash, kapital],
        fxSnapshot: null,
      );
      await toIncome(tester);
      await pickCard(tester, 'a2');
      await type(tester, '300');
      await save(tester);

      expect(await txs(db), isEmpty);
      expect(await balanceOf(db, 'a2'), 500);
      expect(find.text(RS.tr.fxFreezeUnavailableIncome), findsOneWidget);
      expect(find.byType(QuickEntryScreen), findsOneWidget);
      expect(chipAccount(tester).id, 'a2');
    });

    testWidgets('tek hesap → gelir eskisi gibi nakde girer', (tester) async {
      final db = await pumpEntry(tester, accounts: const [cash]);
      await toIncome(tester);
      expect(find.byType(AccountChip), findsNothing);

      await type(tester, '700');
      await save(tester);

      final tx = (await txs(db)).single;
      expect(tx['type'], 'income');
      expect(tx.containsKey('accountId'), isFalse, reason: 'eski yol');
      expect(tx.containsKey('baseAmount'), isFalse);
      expect(await balanceOf(db, Account.cashId), 1700);
    });
  });

  group('öneri ve elle seçim', () {
    final now = DateTime.now();
    // Geçmiş: genel favori Enpara (2 harcama), ama kuaför en son Kapital.
    final history = [
      Tx(
        id: 't1',
        type: TxType.expense,
        amount: 10,
        date: now.subtract(const Duration(days: 1)),
        envelopeId: 'e2',
        accountId: 'a1',
      ),
      Tx(
        id: 't2',
        type: TxType.expense,
        amount: 10,
        date: now.subtract(const Duration(days: 2)),
        envelopeId: 'e2',
        accountId: 'a1',
      ),
      Tx(
        id: 't3',
        type: TxType.expense,
        amount: 10,
        date: now.subtract(const Duration(days: 3)),
        envelopeId: 'e1',
        accountId: 'a2',
        currency: 'AZN',
      ),
    ];
    final envelopes = [
      testEnvelope(id: 'e1', name: 'Kuaför Ayşe'),
      testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', sortOrder: 1),
    ];

    Future<void> pickCategory(WidgetTester tester, String name) async {
      await tester.tap(find.text(RS.tr.pickCategory));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets('kategori değişince öneri yenilenir', (tester) async {
      await pumpEntry(
        tester,
        accounts: const [cash, enpara, kapital],
        transactions: history,
        envelopes: envelopes,
      );
      expect(chipAccount(tester).id, 'a1', reason: 'kategorisiz: genel favori');
      await pickCategory(tester, 'Kuaför Ayşe');
      expect(
        chipAccount(tester).id,
        'a2',
        reason: 'kuaför en son Kapital\'den ödendi',
      );
    });

    testWidgets('elle seçilen kart kategori değişince ezilmez', (tester) async {
      await pumpEntry(
        tester,
        accounts: const [cash, enpara, kapital],
        transactions: history,
        envelopes: envelopes,
      );
      await pickCard(tester, Account.cashId);
      expect(chipAccount(tester).id, Account.cashId);
      await pickCategory(tester, 'Kuaför Ayşe');
      expect(
        chipAccount(tester).id,
        Account.cashId,
        reason: 'öneri Kapital derdi; kullanıcının seçimi önde',
      );
    });
  });
}
