import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/account_card.dart';
import 'package:kopilka_app/features/accounts/account_editor_sheet.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/accounts/accounts_screen.dart';

import '../support/harness.dart';

/// Hesap yönetimi ekranı: kartlar listelenir, bakiye kendi biriminde yazar,
/// nakit için arşiv yok, boş durumda çağrı var, editör ülke → banka akışını
/// yürütüp depoya yazar, dar ekranda üç dilde taşmaz.
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
    balance: 200,
  );
  const enpara = Account(
    id: 'enpara',
    name: 'Enpara Maaş',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 1500.5,
    sortOrder: 1,
  );
  const kapital = Account(
    id: 'kapital',
    name: 'Kapital Bank',
    currency: 'AZN',
    kind: AccountKind.card,
    balance: 50,
    sortOrder: 2,
  );

  Future<void> seed(FakeFirebaseFirestore db, Iterable<Account> accounts) async {
    for (final a in accounts) {
      await db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> docs(FakeFirebaseFirestore db) =>
      db.collection('users').doc(testUid).collection('accounts').get();

  /// Hesaba bağlı sahte işlem — silme kuralı yalnız `accountId`'ye bakar.
  Future<void> seedTx(FakeFirebaseFirestore db, String accountId) =>
      db.collection('users').doc(testUid).collection('transactions').add({
        'type': 'expense',
        'amount': 10,
        'currency': 'TRY',
        'accountId': accountId,
      });

  Future<void> openMenu(WidgetTester tester, String accountId) async {
    await tester.ensureVisible(find.byKey(ValueKey('menu-$accountId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('menu-$accountId')));
    await tester.pumpAndSettle();
  }

  /// Gerçek `accountsRepositoryProvider` `uidProvider`'a bağlı ve testte
  /// fırlatır; harness'ta hesap deposu için override yok. Ekranı sahte
  /// depoyla iç içe bir scope'a sarıyoruz; modal sayfalar çağıranın
  /// container'ını `UncontrolledProviderScope` ile taşıdığından onlar da
  /// bu depoyu görür.
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

  Future<FakeFirebaseFirestore> pumpScreen(
    WidgetTester tester, {
    Iterable<Account> accounts = const [cash, enpara, kapital],
    AppLanguage language = AppLanguage.tr,
    double width = 360,
  }) async {
    final db = FakeFirebaseFirestore();
    await seed(db, accounts);
    await pumpBudgyScreen(
      tester,
      scoped(db, const ManageAccountsScreen()),
      db: db,
      language: language,
      logicalSize: Size(width, 800),
    );
    return db;
  }

  testWidgets('kartlar listelenir, bakiye kendi biriminde yazar',
      (tester) async {
    await pumpScreen(tester);
    final rs = RS.tr;

    expect(find.byType(AccountCard), findsNWidgets(3));
    expect(find.text('Enpara'), findsOneWidget);
    expect(find.text('Enpara Maaş'), findsOneWidget);
    expect(find.text('Kapital Bank'), findsOneWidget);
    // Nakit ₺, Enpara ₺, Kapital ₼ — ana birime çevrilmiş toplam YOK.
    expect(find.text('200 ₺'), findsOneWidget);
    expect(find.text('1,500.5 ₺'), findsOneWidget);
    expect(find.text('50 ₼'), findsOneWidget);
    expect(find.text(tpl(rs.accountCountTpl, {'n': '3'})), findsOneWidget);
    expect(find.text(rs.accountEmptyTitle), findsNothing);
  });

  testWidgets('nakit menüsünde arşivle yok; kartta var ve arşivler',
      (tester) async {
    final db = await pumpScreen(tester);
    final rs = RS.tr;

    await tester.tap(find.byKey(const ValueKey('menu-${Account.cashId}')));
    await tester.pumpAndSettle();
    expect(find.text(rs.accountRename), findsOneWidget);
    expect(find.text(rs.accountArchive), findsNothing);
    expect(find.text(rs.accountDelete), findsNothing);
    await tester.tapAt(const Offset(10, 10)); // dışarı dokun → kapat
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('menu-kapital')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-kapital')));
    await tester.pumpAndSettle();
    expect(find.text(rs.accountArchive), findsOneWidget);
    await tester.tap(find.text(rs.accountArchive));
    await tester.pumpAndSettle();

    final snap = await docs(db);
    final doc = snap.docs.firstWhere((d) => d.id == 'kapital');
    expect(doc.data()['archived'], isTrue);
    // Arşivlenen kart listeden düştü, geri alma şeridi göründü.
    expect(find.text('Kapital Bank'), findsNothing);
    expect(find.text(rs.undo), findsOneWidget);
  });

  testWidgets('işlemsiz kartta "Tamamen sil" aktif; işlemli kartta soluk + not',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await seed(db, const [cash, enpara, kapital]);
    await seedTx(db, 'enpara');
    await seedTx(db, 'enpara');
    await seedTx(db, 'enpara');
    await pumpBudgyScreen(tester, scoped(db, const ManageAccountsScreen()),
        db: db);
    final rs = RS.tr;

    // Kapital: hiç işlem yok → satır aktif, açıklayıcı not.
    await openMenu(tester, 'kapital');
    expect(find.text(rs.accountDelete), findsOneWidget);
    expect(find.text(rs.accountDeleteNote), findsOneWidget);
    // `Opacity` satırın İÇİNDE (torun), dışında değil.
    final active = tester.widget<Opacity>(find.descendant(
      of: find.byKey(const ValueKey('delete-kapital')),
      matching: find.byType(Opacity),
    ).first);
    expect(active.opacity, 1);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Enpara: 3 işlem → satır soluk, "3 işlem var" notu, dokunuş iş yapmaz.
    await openMenu(tester, 'enpara');
    expect(find.text(rs.accountDelete), findsOneWidget);
    expect(find.text(tpl(rs.accountHasTxTpl, {'n': '3'})), findsOneWidget);
    final dimmed = tester.widget<Opacity>(find.descendant(
      of: find.byKey(const ValueKey('delete-enpara')),
      matching: find.byType(Opacity),
    ).first);
    expect(dimmed.opacity, lessThan(1));
    await tester.tap(find.text(rs.accountDelete));
    await tester.pumpAndSettle();
    // Menü kapanmadı, onay diyaloğu açılmadı, belge yerinde.
    expect(find.text(rs.accountDelete), findsOneWidget);
    expect(find.text(rs.accountDeleteConfirmTitle), findsNothing);
    final snap = await docs(db);
    expect(snap.docs.any((d) => d.id == 'enpara'), isTrue);
  });

  testWidgets('silme onayı: İptal silmez; Sil belgeyi siler, geri al sunmaz',
      (tester) async {
    final db = await pumpScreen(tester);
    final rs = RS.tr;

    // İptal.
    await openMenu(tester, 'kapital');
    await tester.tap(find.text(rs.accountDelete));
    await tester.pumpAndSettle();
    expect(find.text(rs.accountDeleteConfirmTitle), findsOneWidget);
    expect(find.textContaining(rs.accountDeleteIrreversible), findsOneWidget);
    await tester.tap(find.text(rs.accountDeleteCancel));
    await tester.pumpAndSettle();
    expect(find.text(rs.accountDeleteConfirmTitle), findsNothing);
    var snap = await docs(db);
    expect(snap.docs.any((d) => d.id == 'kapital'), isTrue);
    expect(find.text('Kapital Bank'), findsOneWidget);

    // Sil.
    await openMenu(tester, 'kapital');
    await tester.tap(find.text(rs.accountDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(rs.accountDeleteButton));
    await tester.pumpAndSettle();

    snap = await docs(db);
    expect(snap.docs.any((d) => d.id == 'kapital'), isFalse);
    expect(find.text('Kapital Bank'), findsNothing);
    expect(find.text(tpl(rs.accountDeletedTpl, {'name': 'Kapital Bank'})),
        findsOneWidget);
    // Silme geri alınamaz — şeritte "Geri al" YOK.
    expect(find.text(rs.undo), findsNothing);
  });

  testWidgets('boş durum: yalnız nakit varken çağrı görünür', (tester) async {
    await pumpScreen(tester, accounts: const [cash]);
    final rs = RS.tr;
    expect(find.text(rs.accountEmptyTitle), findsOneWidget);
    expect(find.text(rs.accountEmptyBody), findsOneWidget);
    expect(find.byType(AccountCard), findsOneWidget);
  });

  testWidgets('editör: ülke → banka → kaydet depoya yazar', (tester) async {
    final db = await pumpScreen(tester, accounts: const [cash]);
    final rs = RS.tr;

    await tester.tap(find.text(rs.accountAdd));
    await tester.pumpAndSettle();
    expect(find.text(rs.accountNewTitle), findsOneWidget);
    // Ülke seçilmeden banka yok, ad yok.
    expect(find.text(rs.accountBank), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.textContaining(rs.accountCountryAZ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bank-kapital')), findsOneWidget);
    expect(find.byKey(const ValueKey('bank-pasha')), findsOneWidget);
    // Nakit katalogda var ama ızgarada yok; "Diğer banka" kullanıcı dilinde.
    expect(find.byKey(const ValueKey('bank-cash')), findsNothing);
    expect(find.text(rs.accountOtherBank), findsOneWidget);
    // Türk bankaları Azerbaycan listesinde değil.
    expect(find.byKey(const ValueKey('bank-enpara')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bank-kapital')));
    await tester.pumpAndSettle();
    // Ad banka adıyla ön dolu, para birimi ülkeden (AZN) geldi.
    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller!.text, 'Kapital Bank');
    expect(find.text('₼ AZN'), findsOneWidget);
    expect(find.text(rs.accountCurrencyAuto), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Azeri kart');
    await tester.enterText(find.byType(TextField).last, '75,5');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, rs.save));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, rs.save));
    await tester.pumpAndSettle();

    expect(find.text(rs.accountNewTitle), findsNothing, reason: 'sayfa kapandı');
    final snap = await docs(db);
    final added = snap.docs.where((d) => d.id != Account.cashId).toList();
    expect(added, hasLength(1));
    final d = added.single.data();
    expect(d['name'], 'Azeri kart');
    expect(d['currency'], 'AZN');
    expect(d['kind'], 'card');
    expect(d['balance'], 75.5);
    expect(d['archived'], isFalse);
    // Liste yeni kartı kendi biriminde gösterdi.
    expect(find.text('75.5 ₼'), findsOneWidget);
  });

  testWidgets('editör: para birimi değiştirilebilir (yeni kart)', (tester) async {
    final db = await pumpScreen(tester,
        accounts: const [cash], language: AppLanguage.en);
    final rs = RS.en;

    await tester.tap(find.text(rs.accountAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(rs.accountCountryTR));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bank-enpara')));
    await tester.pumpAndSettle();
    // Varsayılan TRY; kullanıcı USD'ye çevirir.
    await tester.ensureVisible(find.text('\$ USD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\$ USD'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, rs.save));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, rs.save));
    await tester.pumpAndSettle();

    final snap = await docs(db);
    final d = snap.docs.firstWhere((x) => x.id != Account.cashId).data();
    expect(d['name'], 'Enpara');
    expect(d['currency'], 'USD');
    expect(d['balance'], 0);
  });

  testWidgets('düzenleme: ad değişir, para birimi kilitli ve korunur',
      (tester) async {
    final db = await pumpScreen(tester);
    final rs = RS.tr;

    await tester.ensureVisible(find.byKey(const ValueKey('menu-kapital')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-kapital')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(rs.accountRename));
    await tester.pumpAndSettle();

    expect(find.text(rs.accountEditTitle), findsOneWidget);
    expect(find.text(rs.accountCurrencyLocked), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    // Ülke/banka seçimi düzenlemede yok.
    expect(find.text(rs.accountCountry), findsNothing);
    expect(find.text(rs.accountStartingBalance), findsNothing);

    await tester.enterText(find.byType(TextField), 'Kapital harçlık');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, rs.save));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, rs.save));
    await tester.pumpAndSettle();

    final snap = await docs(db);
    final d = snap.docs.firstWhere((x) => x.id == 'kapital').data();
    expect(d['name'], 'Kapital harçlık');
    expect(d['currency'], 'AZN');
    expect(d['balance'], 50);
    expect(find.text('Kapital harçlık'), findsOneWidget);
  });

  testWidgets('sürükle-bırak sıralama depoya yazar', (tester) async {
    final db = await pumpScreen(tester);

    // Üçüncü kart listenin görünür alanının altında kalıyor (alttaki
    // "Kart ekle" düğmesi listeyi kısaltıyor); parmakla kaydır, yoksa parmak
    // düğmeye iner. `ensureVisible` BİLEREK kullanılmadı: programatik
    // kaydırma sonrası uzun basma sürüklemesi testte tutmuyor.
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Uzun bas, Enpara'nın üstüne parmak gibi küçük adımlarla sürükle,
    // bırak. Tek sıçrayışlı `moveTo` kaydırılmış listede sürüklemeyi
    // başlatmıyor; adım adım hareket gerçek jeste de daha yakın.
    final from = tester.getCenter(find.byKey(const ValueKey('kapital')));
    final to = tester.getCenter(find.byKey(const ValueKey('enpara')));
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(kPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    final snap = await docs(db);
    final order = {for (final d in snap.docs) d.id: d.data()['sortOrder']};
    expect(order[Account.cashId], 0);
    expect(order['kapital'], 1);
    expect(order['enpara'], 2);
  });

  /// Yerleşim: liste (dolu + boş) ve açık editör (TR: en kalabalık ızgara,
  /// 13 kart) 320/360dp'de üç dilde taşmıyor.
  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('liste · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
        await pumpScreen(tester, language: lang, width: width);
        expect(tester.takeException(), isNull);
        await pumpScreen(tester,
            accounts: const [cash], language: lang, width: width);
        expect(tester.takeException(), isNull);
      });

      testWidgets('menü + silme onayı · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
        final db = FakeFirebaseFirestore();
        await seed(db, const [cash, enpara, kapital]);
        await seedTx(db, 'enpara');
        await pumpBudgyScreen(tester, scoped(db, const ManageAccountsScreen()),
            db: db, language: lang, logicalSize: Size(width, 800));
        final rs = RS.of(lang.code);

        // Soluk satır + "{n} işlem var" notu.
        await openMenu(tester, 'enpara');
        expect(find.text(tpl(rs.accountHasTxTpl, {'n': '1'})), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Aktif satır + onay diyaloğu.
        await openMenu(tester, 'kapital');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(rs.accountDelete));
        await tester.pumpAndSettle();
        expect(find.text(rs.accountDeleteConfirmTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('editör · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
        await pumpScreen(tester,
            accounts: const [cash], language: lang, width: width);
        final rs = RS.of(lang.code);
        await tester.tap(find.text(rs.accountAdd));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining(rs.accountCountryTR));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bank-enpara')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Düzenleme sayfası da.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        // Sayfa kapanana kadar tamamlanmaz; beklemeden pompalıyoruz.
        unawaited(showAccountEditor(
          tester.element(find.byType(ManageAccountsScreen)),
          existing: enpara,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
