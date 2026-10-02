import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/accounts/accounts_screen.dart';

import '../support/harness.dart';

void main() {
  testWidgets('drag debug', (tester) async {
    final db = FakeFirebaseFirestore();
    for (final a in const [
      Account(id: 'cash', name: 'Nakit', currency: 'TRY', kind: AccountKind.cash, balance: 1),
      Account(id: 'enpara', name: 'Enpara', currency: 'TRY', kind: AccountKind.card, balance: 1, sortOrder: 1),
      Account(id: 'kapital', name: 'Kapital Bank', currency: 'AZN', kind: AccountKind.card, balance: 1, sortOrder: 2),
    ]) {
      await db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());
    }
    final repo = AccountsRepository(db, testUid);
    await pumpBudgyScreen(
      tester,
      ProviderScope(overrides: [
        accountsRepositoryProvider.overrideWithValue(repo),
        accountsProvider.overrideWith((ref) => repo.watchAccounts()),
      ], child: const ManageAccountsScreen()),
      db: db,
    );
    debugPrint('platform: ${Theme.of(tester.element(find.byType(ReorderableListView))).platform} handles: ${find.byIcon(Icons.drag_handle).evaluate().length}');
    await tester.ensureVisible(find.byKey(const ValueKey('kapital')));
    await tester.pumpAndSettle();
    for (final id in ['cash', 'enpara', 'kapital']) {
      debugPrint('$id -> ${tester.getRect(find.byKey(ValueKey(id)))}');
    }
    debugPrint('list rect ${tester.getRect(find.byType(ReorderableListView))}');
    // Bisect: start on the balance label (no GestureDetector) instead of the card.
    final tileRect = tester.getRect(find.byKey(const ValueKey('kapital')));
    final from = Offset(tileRect.left + 60, tileRect.bottom - 40);
    final to = tester.getCenter(find.byKey(const ValueKey('enpara')));
    debugPrint('from $from to $to');
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    debugPrint('kapital count after press: ${find.byKey(const ValueKey('kapital')).evaluate().length}');
    debugPrint('pending timers? ${tester.binding.hasScheduledFrame}');
    await gesture.moveTo(to);
    await tester.pump(kPressTimeout);
    debugPrint('after move: enpara ${tester.getRect(find.byKey(const ValueKey('enpara')))}');
    await gesture.up();
    await tester.pumpAndSettle();
    final snap = await db.collection('users').doc(testUid).collection('accounts').get();
    debugPrint({for (final d in snap.docs) d.id: d.data()['sortOrder']}.toString());
  });
}
