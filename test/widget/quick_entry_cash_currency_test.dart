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
import 'package:kopilka_app/features/recurring/recurring.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Ana birimi lira OLMAYAN kullanıcıda hızlı giriş:
/// * nakit harcaması ÇEVRİLMEZ — nakit tanım gereği ana birimde; eski
///   `accounts/cash` belgesinde 'TRY' yazsa bile çapraz kur uygulanmaz;
/// * tekrar kuralı hangi hesaptan girildiyse onu hatırlar.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  const kaspi = Account(
    id: 'k1',
    name: 'Kaspi',
    currency: 'KZT',
    kind: AccountKind.card,
    balance: 100000,
    sortOrder: 1,
  );

  /// ₸ tabanlı gerçekçi tablo: 1 ₺ ≈ 13 ₸. Hata varsa ekran bunu uygular
  /// ve 5 000 ₸ → 65 000 ₸ olur; doğru davranışta tabloya hiç bakılmaz.
  final fx = FxSnapshot(
    base: 'KZT',
    rates: {'TRY': 1 / 13.0, 'USD': 1 / 540.0},
    fetchedAt: DateTime.now(),
  );

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
    FxSnapshot? fxSnapshot,
  }) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/$testUid/settings/main').set({'currency': 'KZT'});
    // Eski göçün bıraktığı gibi: nakit belgesinde 'TRY' yazıyor.
    await db
        .doc('users/$testUid/accounts/${Account.cashId}')
        .set({'balance': 50000, 'currency': 'TRY', 'name': 'wallet'});
    await db.doc('users/$testUid/accounts/${kaspi.id}').set(kaspi.toMap());
    await pumpBudgyScreen(
      tester,
      scoped(db, const QuickEntryScreen()),
      db: db,
      language: AppLanguage.tr,
      currency: 'KZT',
      fxSnapshot: fxSnapshot,
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

  Future<void> pickCard(WidgetTester tester, String accountId) async {
    await tester.tap(find.byType(AccountChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('account-row-$accountId')));
    await tester.pumpAndSettle();
  }

  Future<List<Tx>> txs(FakeFirebaseFirestore db) async {
    final snap = await db
        .collection('users')
        .doc(testUid)
        .collection('transactions')
        .get();
    return [for (final d in snap.docs) Tx.fromDoc(d)];
  }

  Future<double> balanceOf(FakeFirebaseFirestore db, String id) async {
    final doc = await db.doc('users/$testUid/accounts/$id').get();
    return (doc.data()!['balance'] as num).toDouble();
  }

  Account chipAccount(WidgetTester tester) =>
      tester.widget<AccountChip>(find.byType(AccountChip)).account;

  testWidgets('5 000 ₸ nakit: çevrim yok, baseAmount 5 000, kur 1', (
    tester,
  ) async {
    final db = await pumpEntry(tester, fxSnapshot: fx);
    await pickCard(tester, Account.cashId);
    final cash = chipAccount(tester);
    expect(cash.isCash, isTrue);
    expect(cash.currency, 'KZT', reason: 'çip nakdi ana birimde gösterir');

    await type(tester, '5000');
    await save(tester);

    final tx = (await txs(db)).single;
    expect(tx.accountId, Account.cashId);
    expect(tx.currency, 'KZT');
    expect(tx.amount, 5000);
    expect(tx.baseAmount, 5000, reason: '65 000 değil');
    expect(tx.baseCurrency, 'KZT');
    expect(tx.fxRate, 1);
    expect(tx.baseOr('KZT'), 5000, reason: 'ay toplamına 5 000 girer');
    expect(await balanceOf(db, Account.cashId), 45000);
    expect(await balanceOf(db, 'k1'), 100000);
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('kur tablosu YOKKEN de nakit kaydı geçer (ağ gerekmez)', (
    tester,
  ) async {
    final db = await pumpEntry(tester, fxSnapshot: null);
    await pickCard(tester, Account.cashId);
    await type(tester, '700');
    await save(tester);

    final tx = (await txs(db)).single;
    expect(tx.currency, 'KZT');
    expect(tx.baseAmount, 700);
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('₸ kartından harcama da çevrilmez (kart zaten ana birimde)', (
    tester,
  ) async {
    final db = await pumpEntry(tester, fxSnapshot: null);
    await pickCard(tester, 'k1');
    await type(tester, '2500');
    await save(tester);

    final tx = (await txs(db)).single;
    expect(tx.accountId, 'k1');
    expect(tx.currency, 'KZT');
    expect(tx.baseAmount, 2500);
    expect(await balanceOf(db, 'k1'), 97500);
    expect(await balanceOf(db, Account.cashId), 50000);
  });

  testWidgets('tekrar kuralı seçilen hesabı hatırlar', (tester) async {
    final db = await pumpEntry(tester, fxSnapshot: null);
    await pickCard(tester, 'k1');
    await type(tester, '900');
    // Tekrar düğmesi (ikon) → sayfada "Aylık".
    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RS.tr.monthly).last);
    await tester.pumpAndSettle();
    await save(tester);

    final rules = await db
        .collection('users')
        .doc(testUid)
        .collection('recurring')
        .get();
    final rule = RecurringRule.fromDoc(rules.docs.single);
    expect(rule.accountId, 'k1');
    expect(rule.accountName, 'Kaspi');
    expect(rule.currency, 'KZT');
    expect(rule.freq, Recurrence.monthly);
  });
}
