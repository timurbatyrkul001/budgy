import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Hesaba bağlı işlemin düzenlenmesi (QuickEntryScreen `editing:` modu):
/// ekran kaydın kartını gösterir, iki+ hesapta değiştirtir; tutar ya da kart
/// değişince kur yeniden dondurulur ve kart bakiyesi yalnız FARK kadar oynar;
/// para tarafı değişmediyse eski kur korunur (ağ gerekmez); eski hesapsız
/// kayıt eskisi gibi, çipsiz düzenlenir.
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
  // 500 ₼'den 40 ₼ harcanmış hâli: düzenlenen kayıt zaten düşülmüş.
  const kapital = Account(
    id: 'a2',
    name: 'Kapital Bank',
    currency: 'AZN',
    kind: AccountKind.card,
    balance: 460,
    sortOrder: 2,
  );

  /// 1 ₼ = 1,97 ₺ (quick_entry_account_test ile aynı tablo).
  final fx = FxSnapshot(
    base: 'TRY',
    rates: {'AZN': 1 / 1.97},
    fetchedAt: DateTime.now(),
  );

  final date = DateTime(2026, 9, 3, 12);
  final groceries = testEnvelope(id: 'gro', name: 'Market', emoji: '🛒');

  /// Kapital'den 40 ₼ gider, kur 1,97 ile dondurulmuş.
  final azTx = Tx(
    id: 't1',
    type: TxType.expense,
    amount: 40,
    date: date,
    envelopeId: 'gro',
    envelopeName: 'Market',
    currency: 'AZN',
    accountId: 'a2',
    baseAmount: 78.8,
    baseCurrency: 'TRY',
    fxRate: 1.97,
  );

  Map<String, dynamic> docOf(Tx tx) => {
        'type': tx.type.name,
        'amount': tx.amount,
        'date': Timestamp.fromDate(tx.date),
        'note': tx.note,
        'envelopeId': ?tx.envelopeId,
        'envelopeName': ?tx.envelopeName,
        'envelopeIds': [?tx.envelopeId],
        'currency': tx.currency,
        'accountId': ?tx.accountId,
        'baseAmount': ?tx.baseAmount,
        'baseCurrency': ?tx.baseCurrency,
        'fxRate': ?tx.fxRate,
      };

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

  Future<FakeFirebaseFirestore> pumpEdit(
    WidgetTester tester, {
    required Tx tx,
    required Iterable<Account> accounts,
    FxSnapshot? fxSnapshot,
  }) async {
    final db = FakeFirebaseFirestore();
    for (final a in accounts) {
      await db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());
    }
    await db.doc('users/$testUid/transactions/${tx.id}').set(docOf(tx));
    await pumpBudgyScreen(
      tester,
      scoped(db, QuickEntryScreen(editing: tx)),
      db: db,
      language: AppLanguage.tr,
      fxSnapshot: fxSnapshot,
      envelopes: [groceries],
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

  /// Ön dolu tutarı tamamen sil (⌫ uzun basış = temizle).
  Future<void> clearAmount(WidgetTester tester) async {
    await tester.longPress(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, RS.tr.save));
    await tester.pumpAndSettle();
  }

  Future<void> pickCard(WidgetTester tester, String accountId) async {
    await tester.tap(find.byType(AccountChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('account-row-$accountId')));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> txDoc(FakeFirebaseFirestore db, String id) async =>
      (await db.doc('users/$testUid/transactions/$id').get()).data()!;

  Future<int> txCount(FakeFirebaseFirestore db) async =>
      (await db.collection('users/$testUid/transactions').get()).docs.length;

  Future<double> balanceOf(FakeFirebaseFirestore db, String id) async {
    final doc = await db.doc('users/$testUid/accounts/$id').get();
    return (doc.data()!['balance'] as num).toDouble();
  }

  Account chipAccount(WidgetTester tester) =>
      tester.widget<AccountChip>(find.byType(AccountChip)).account;

  testWidgets('ekran kaydın kartını gösterir; 40 → 60 ₼: bakiye yalnız fark kadar',
      (tester) async {
    final db = await pumpEdit(
      tester,
      tx: azTx,
      accounts: const [cash, enpara, kapital],
      fxSnapshot: fx,
    );
    expect(find.text(RS.tr.editingLabel), findsOneWidget);
    expect(chipAccount(tester).id, 'a2', reason: 'öneri değil, kaydın kartı');
    expect(find.text('₺'), findsNothing, reason: 'tutar kartın biriminde');
    expect(find.text('Market'), findsOneWidget,
        reason: 'döviz kayıt ama kategori yutulmadı — bu bir kart, cüzdan değil');

    await clearAmount(tester);
    await type(tester, '60');
    await save(tester);

    expect(await txCount(db), 1, reason: 'aynı belge güncellendi');
    final d = await txDoc(db, 't1');
    expect(d['amount'], 60);
    expect(d['currency'], 'AZN');
    expect(d['accountId'], 'a2');
    expect(d['baseAmount'], 118.2, reason: 'kur yeniden donduruldu: 60 × 1,97');
    expect(d['fxRate'], closeTo(1.97, 1e-9));
    expect(d['envelopeId'], 'gro');
    // 460 − 20: ne 460 − 60 (çift düşme) ne başka bir şey.
    expect(await balanceOf(db, 'a2'), 440);
    expect(await balanceOf(db, Account.cashId), 1000, reason: 'nakit dokunulmadı');
    expect(await balanceOf(db, 'a1'), 1000);
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('kart değişince: Kapital\'e iade, Enpara\'dan düşer, kur ₺/₺',
      (tester) async {
    final db = await pumpEdit(
      tester,
      tx: azTx,
      accounts: const [cash, enpara, kapital],
      fxSnapshot: null, // ₺ karta geçiş ağ istemez
    );
    await pickCard(tester, 'a1');
    expect(chipAccount(tester).id, 'a1');
    expect(find.text('₺'), findsWidgets, reason: 'simge yeni kartı izler');

    await save(tester);

    final d = await txDoc(db, 't1');
    expect(d['accountId'], 'a1');
    expect(d['currency'], 'TRY');
    expect(d['amount'], 40);
    expect(d['baseAmount'], 40);
    expect(d['fxRate'], 1);
    expect(await balanceOf(db, 'a2'), 500, reason: '40 ₼ geri geldi');
    expect(await balanceOf(db, 'a1'), 960, reason: '40 ₺ düştü');
    expect(await balanceOf(db, Account.cashId), 1000);
  });

  testWidgets('tek hesap: çip görünür ama seçici açılmaz; bağ korunur',
      (tester) async {
    final db = await pumpEdit(
      tester,
      tx: azTx,
      accounts: const [kapital],
      fxSnapshot: fx,
    );
    expect(chipAccount(tester).id, 'a2', reason: '"nereden" bilgisi gösterilir');
    await tester.tap(find.byType(AccountChip));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-row-a2')), findsNothing,
        reason: 'değiştirecek ikinci hesap yok');

    await clearAmount(tester);
    await type(tester, '50');
    await save(tester);

    final d = await txDoc(db, 't1');
    expect(d['accountId'], 'a2', reason: 'bağ nakde kaymadı');
    expect(d['baseAmount'], 98.5);
    expect(await balanceOf(db, 'a2'), 450);
  });

  testWidgets('para tarafı değişmedi → eski kur korunur, ağ gerekmez',
      (tester) async {
    final db = await pumpEdit(
      tester,
      tx: azTx,
      accounts: const [cash, kapital],
      fxSnapshot: null,
    );
    await save(tester);

    expect(find.text(RS.tr.fxFreezeUnavailableEdit), findsNothing);
    expect(find.byType(QuickEntryScreen), findsNothing, reason: 'kayıt geçti');
    final d = await txDoc(db, 't1');
    expect(d['baseAmount'], 78.8, reason: 'geçmiş kur bugünkünün üstüne yazılmadı');
    expect(d['fxRate'], 1.97);
    expect(await balanceOf(db, 'a2'), 460);
  });

  testWidgets('tutar değişti ama kur yok → değişiklik KAYDEDİLMEZ', (tester) async {
    final db = await pumpEdit(
      tester,
      tx: azTx,
      accounts: const [cash, kapital],
      fxSnapshot: null,
    );
    await clearAmount(tester);
    await type(tester, '60');
    await save(tester);

    expect(find.text(RS.tr.fxFreezeUnavailableEdit), findsOneWidget);
    expect(find.byType(QuickEntryScreen), findsOneWidget, reason: 'form açık kaldı');
    final d = await txDoc(db, 't1');
    expect(d['amount'], 40, reason: 'uydurma kurla yazılmadı');
    expect(d['baseAmount'], 78.8);
    expect(await balanceOf(db, 'a2'), 460);
  });

  testWidgets('eski hesapsız kayıt: çip yok, nakit yolu eskisi gibi', (tester) async {
    final legacy = Tx(
      id: 't0',
      type: TxType.expense,
      amount: 450,
      date: date,
      envelopeId: 'gro',
      envelopeName: 'Market',
    );
    final db = await pumpEdit(
      tester,
      tx: legacy,
      accounts: const [cash, enpara],
    );
    expect(find.byType(AccountChip), findsNothing,
        reason: 'öneriyle kart iliştirmek parayı sessizce taşırdı');

    await type(tester, '0'); // 450 → 4500
    await save(tester);

    final d = await txDoc(db, 't0');
    expect(d['amount'], 4500);
    expect(d.containsKey('accountId'), isFalse);
    expect(d.containsKey('baseAmount'), isFalse);
    expect(await balanceOf(db, Account.cashId), 1000 + 450 - 4500);
    expect(await balanceOf(db, 'a1'), 1000, reason: 'kart dokunulmadı');
  });
}
