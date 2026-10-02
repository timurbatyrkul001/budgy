import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/account_card.dart';
import 'package:kopilka_app/features/accounts/account_picker.dart';

/// `AccountPicker` şeridi, `AccountChip` ve `showAccountPicker` sheet'i:
/// render, seçim halkası, dokunma, tek hesapta gizlenme, 320dp'de taşma
/// yok, semantics.
void main() {
  const enpara = Account(
    id: 'a1',
    name: 'Enpara',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 0,
  );
  const kapital = Account(
    id: 'a2',
    name: 'Kapital Bank',
    currency: 'AZN',
    kind: AccountKind.card,
    balance: 0,
  );
  const cash = Account(
    id: Account.cashId,
    name: 'Nakit',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 0,
  );
  const three = [cash, enpara, kapital];

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double screenWidth = 390,
  }) async {
    tester.view.physicalSize = Size(screenWidth, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // ProviderScope: nakit kartı "nakit" notunu dilden okuyor (RS.cash).
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(backgroundColor: Ex.bg, body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AccountCard cardOf(WidgetTester tester, String id) =>
      tester.widget<AccountCard>(find.byKey(ValueKey('account-card-$id')));

  /// Kartın dış halka rengi (`AnimatedContainer`'ın border'ı).
  Color ringColor(WidgetTester tester, String id) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey('account-card-$id')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final deco = container.decoration as BoxDecoration;
    return deco.border!.top.color;
  }

  group('AccountPicker', () {
    testWidgets('şerit render olur: her hesap için bir kart', (tester) async {
      await pump(
        tester,
        AccountPicker(accounts: three, selectedId: 'a1', onChanged: (_) {}),
      );
      expect(find.byType(AccountCard), findsNWidgets(3));
      expect(find.text('Enpara'), findsOneWidget);
      expect(find.text('Kapital Bank'), findsOneWidget);
      expect(find.text('Nakit'), findsWidgets);
    });

    testWidgets('yalnız seçili kartın halkası var', (tester) async {
      await pump(
        tester,
        AccountPicker(accounts: three, selectedId: 'a1', onChanged: (_) {}),
      );
      expect(cardOf(tester, 'a1').selected, isTrue);
      expect(cardOf(tester, 'cash').selected, isFalse);
      expect(cardOf(tester, 'a2').selected, isFalse);
      expect(ringColor(tester, 'a1'), Ex.text);
      expect(ringColor(tester, 'cash'), Colors.transparent);
    });

    testWidgets('dokunma seçimi değiştirir; seçiliye dokunmak çağırmaz', (
      tester,
    ) async {
      final picked = <String>[];
      await pump(
        tester,
        AccountPicker(accounts: three, selectedId: 'a1', onChanged: picked.add),
      );
      await tester.tap(find.byKey(const ValueKey('account-card-a2')));
      await tester.pump();
      expect(picked, ['a2']);

      await tester.tap(find.byKey(const ValueKey('account-card-a1')));
      await tester.pump();
      expect(picked, ['a2'], reason: 'zaten seçili karta dokunmak sessiz');
    });

    testWidgets('seçim üstten değişince halka yeni karta geçer', (
      tester,
    ) async {
      String? selected = 'a1';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: AccountPicker(
                  accounts: three,
                  selectedId: selected,
                  onChanged: (id) => setState(() => selected = id),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-card-a2')));
      await tester.pumpAndSettle();
      expect(cardOf(tester, 'a2').selected, isTrue);
      expect(cardOf(tester, 'a1').selected, isFalse);
    });

    testWidgets('tek hesapta hiç çizilmez', (tester) async {
      await pump(
        tester,
        AccountPicker(
          accounts: const [cash],
          selectedId: Account.cashId,
          onChanged: (_) {},
          warning: 'uyarı',
        ),
      );
      expect(find.byType(AccountCard), findsNothing);
      expect(find.text('uyarı'), findsNothing);
      expect(tester.getSize(find.byType(AccountPicker)), Size.zero);
    });

    testWidgets('boş listede de çizilmez', (tester) async {
      await pump(
        tester,
        AccountPicker(accounts: const [], selectedId: null, onChanged: (_) {}),
      );
      expect(find.byType(AccountCard), findsNothing);
    });

    testWidgets('320dp ekranda taşmaz, uyarı notu görünür', (tester) async {
      await pump(
        tester,
        AccountPicker(
          accounts: three,
          selectedId: 'a2',
          onChanged: (_) {},
          warning:
              'Bu kart AZN ile çalışıyor; ana para biriminiz TRY. '
              'Tutar günün kuruyla çevrilecek.',
        ),
        screenWidth: 320,
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('kuruyla'), findsOneWidget);
      // Şerit ekran genişliğini aşmıyor.
      expect(
        tester.getSize(find.byType(ListView)).width,
        lessThanOrEqualTo(320),
      );
    });

    testWidgets('uyarı yoksa not satırı yok', (tester) async {
      await pump(
        tester,
        AccountPicker(accounts: three, selectedId: 'a1', onChanged: (_) {}),
      );
      // Şeridin yüksekliği tam kart yüksekliği: altında ek satır yok.
      final probe = const AccountCard(account: cash, width: 168);
      expect(tester.getSize(find.byType(AccountPicker)).height, probe.height);
    });

    testWidgets('semantics: her kart button, seçili olan selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        AccountPicker(accounts: three, selectedId: 'a1', onChanged: (_) {}),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('account-card-a1'))),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Enpara, TRY',
          hasEnabledState: true,
          // Seçili kartta onTap null → etkin değil, tap eylemi yok; ekran
          // okuyucu "seçili" deyip bırakır, "çift dokun" demez.
          isEnabled: false,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('account-card-a2'))),
        matchesSemantics(
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          label: 'Kapital Bank, AZN',
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });
  });

  group('AccountChip', () {
    testWidgets('ad + para birimi gösterir, dokununca çağırır', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Center(
          child: AccountChip(account: kapital, onTap: () => taps++),
        ),
      );
      expect(find.text('Kapital Bank'), findsOneWidget);
      expect(find.text('AZN'), findsOneWidget);
      await tester.tap(find.byType(AccountChip));
      expect(taps, 1);
    });

    testWidgets('uzun ad 320dp\'de taşmaz', (tester) async {
      await pump(
        tester,
        Center(
          child: AccountChip(
            account: enpara.copyWith(
              name: 'Enpara Maaş Hesabım Çok Uzun Bir Ad İle',
            ),
            onTap: () {},
          ),
        ),
        screenWidth: 320,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AccountChip)).width,
        lessThanOrEqualTo(320),
      );
    });

    testWidgets('semantics: button + etiket', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        Center(
          child: AccountChip(account: enpara, onTap: () {}),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AccountChip)),
        matchesSemantics(
          isButton: true,
          label: 'Enpara, TRY',
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('showAccountPicker', () {
    Future<String?> open(
      WidgetTester tester, {
      VoidCallback? onAdd,
      String? addLabel = 'Kart ekle',
    }) async {
      String? result;
      var opened = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    opened = true;
                    result = await showAccountPicker(
                      context,
                      selectedId: 'a1',
                      accounts: three,
                      title: 'Hangi hesaptan?',
                      addLabel: addLabel,
                      onAddAccount: onAdd,
                    );
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      return result;
    }

    testWidgets('sheet açılır, satıra dokununca id ile döner', (tester) async {
      String? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showAccountPicker(
                      context,
                      selectedId: 'a1',
                      accounts: three,
                      title: 'Hangi hesaptan?',
                    );
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text('Hangi hesaptan?'), findsOneWidget);
      // onAddAccount verilmedi → ekleme satırı yok.
      expect(find.text('Kart ekle'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('account-row-a2')));
      await tester.pumpAndSettle();
      expect(result, 'a2');
      expect(find.text('Hangi hesaptan?'), findsNothing);
    });

    testWidgets('"Kart ekle" sheet\'i kapatır, null döner, callback çağrılır', (
      tester,
    ) async {
      var added = 0;
      String? result = 'unset';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showAccountPicker(
                      context,
                      selectedId: 'a1',
                      accounts: three,
                      title: 'Hangi hesaptan?',
                      addLabel: 'Kart ekle',
                      onAddAccount: () => added++,
                    );
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kart ekle'));
      await tester.pumpAndSettle();
      expect(added, 1);
      expect(result, isNull);
      expect(find.text('Hangi hesaptan?'), findsNothing);
    });

    testWidgets('semantics: satırlar button, seçili satır selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('account-row-a1'))),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Enpara, TRY',
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('account-row-cash'))),
        matchesSemantics(
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          label: 'Nakit, TRY',
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
