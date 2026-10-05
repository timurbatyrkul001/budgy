import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/load_error_banner.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/account_picker.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';

import '../support/harness.dart';

/// Hızlı giriş, dayanağı olmayan kayıt YAZMAZ.
///
/// Kaydın üç dayanağı var: hesap listesi, ana birim, zarflar. Eskiden bu
/// akışlardan biri düşünce `.value ?? []` / `?? 'TRY'` boşluğu dolduruyor
/// ve kayıt yine yazılıyordu — iki kartlı kullanıcının harcaması nakitten,
/// tenge kullanıcısının kart harcaması ₺'ye dondurulmuş hâlde. Buradaki
/// sınamalar ekrana bakmaz, VERİTABANINA bakar: düşen akışta işlem
/// koleksiyonu boş kalmalı, bakiye kıpırdamamalı. Ve en önemlisi: yeni
/// kullanıcı (hiç hesap belgesi yok) eskisi gibi kaydedebilmeli — boş liste
/// bir değerdir, hata değil.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final denied = FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
    message: 'Missing or insufficient permissions.',
  );

  const cash = Account(
    id: Account.cashId,
    name: 'Nakit',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 1000,
    sortOrder: 0,
  );
  const kapital = Account(
    id: 'a2',
    name: 'Kapital Bank',
    currency: 'AZN',
    kind: AccountKind.card,
    balance: 500,
    sortOrder: 2,
  );

  final fx = FxSnapshot(
    base: 'TRY',
    rates: {'AZN': 1 / 1.97},
    fetchedAt: DateTime.now(),
  );

  final food = testEnvelope(id: 'e1', name: 'Yemek', presetKey: 'food');

  Future<void> seed(
    FakeFirebaseFirestore db,
    Iterable<Account> accounts,
  ) async {
    for (final a in accounts) {
      await db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());
    }
  }

  /// Ekranı, düşen/askıdaki akışları veren İÇ bir kapsama sarar. Harness
  /// aynı sağlayıcıları zaten eziyor; iç kapsam en yakın olduğundan hem
  /// ekran hem şeritteki "Tekrar dene" (`ref.invalidate`) bunu görür.
  Widget failing(Widget screen, List<Override> overrides) =>
      ProviderScope(overrides: overrides, child: screen);

  /// [accountsStream]: hesap akışının kaynağı; verilmezse sahte depo.
  /// Aynı sağlayıcı bir kapsamda iki kez ezilemez (Riverpod assert), o
  /// yüzden düşen/askıda akış ayrı bir override değil, bu parametre.
  Future<FakeFirebaseFirestore> pumpEntry(
    WidgetTester tester, {
    required Iterable<Account> accounts,
    Stream<List<Account>> Function(Ref ref, AccountsRepository repo)?
        accountsStream,
    List<Override> overrides = const [],
    FxSnapshot? fxSnapshot,
    List<Envelope> envelopes = const [],
  }) async {
    final db = FakeFirebaseFirestore();
    await seed(db, accounts);
    final repo = AccountsRepository(db, testUid);
    await pumpBudgyScreen(
      tester,
      failing(const QuickEntryScreen(), [
        accountsRepositoryProvider.overrideWithValue(repo),
        accountsProvider.overrideWith(
          (ref) => accountsStream?.call(ref, repo) ?? repo.watchAccounts(),
        ),
        ...overrides,
      ]),
      db: db,
      fxSnapshot: fxSnapshot,
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

  Finder saveButton() => find.widgetWithText(FilledButton, RS.tr.save);

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveButton(), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(saveButton()).onPressed != null;

  Future<List<Map<String, dynamic>>> txs(FakeFirebaseFirestore db) async {
    final snap = await db
        .collection('users')
        .doc(testUid)
        .collection('transactions')
        .get();
    return [for (final d in snap.docs) d.data()];
  }

  Future<double?> balanceOf(FakeFirebaseFirestore db, String id) async {
    final doc = await db.doc('users/$testUid/accounts/$id').get();
    return (doc.data()?['balance'] as num?)?.toDouble();
  }

  group('hesap akışı düştü', () {
    testWidgets('kayıt YAZILMAZ: işlem yok, nakit bakiyesi kıpırdamaz', (
      tester,
    ) async {
      // İki hesaplı kullanıcı — normalde kart çipi çıkar ve kart seçilir.
      // Akış düşünce eski kod "tek kasa" sanıp nakitten düşerdi.
      final db = await pumpEntry(
        tester,
        accounts: const [cash, kapital],
        fxSnapshot: fx,
        accountsStream: (_, _) => Stream.error(denied),
      );

      expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);
      expect(find.text(Strings.tr.errorGeneric), findsOneWidget);

      await type(tester, '2000');
      expect(saveEnabled(tester), isFalse, reason: 'dayanak yok → kapalı');
      await tapSave(tester);

      expect(await txs(db), isEmpty, reason: 'uydurma hesaba kayıt yok');
      expect(await balanceOf(db, Account.cashId), 1000);
      expect(await balanceOf(db, 'a2'), 500);
      expect(find.byType(QuickEntryScreen), findsOneWidget,
          reason: 'form dolu kalır, kullanıcı tekrar dener');
      expect(find.byType(AccountChip), findsNothing);
    });

    testWidgets('Tekrar dene akışı açar → Kaydet açılır → kayıt yazılır', (
      tester,
    ) async {
      // Riverpod 3 düşen akışı kendisi de yeniden dener; o yüzden sayaç
      // değil bayrak: kullanıcı dokunana kadar her deneme düşer.
      var healed = false;
      final db = await pumpEntry(
        tester,
        accounts: const [cash],
        accountsStream: (_, repo) => healed
            ? repo.watchAccounts()
            : Stream<List<Account>>.error(denied),
      );
      await type(tester, '150');
      expect(saveEnabled(tester), isFalse);
      expect(await txs(db), isEmpty);

      healed = true;
      await tester.tap(find.byKey(kLoadErrorRetryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      expect(saveEnabled(tester), isTrue);
      await tapSave(tester);

      final all = await txs(db);
      expect(all, hasLength(1));
      expect(all.single['amount'], 150);
      expect(await balanceOf(db, Account.cashId), 1000 - 150);
    });

    testWidgets('önbellekten gelen eski liste + hata: yine YAZILMAZ', (
      tester,
    ) async {
      // Firestore'un gerçek davranışı: önce önbellek, sonra sunucu reddi.
      // Riverpod eski değeri korur (hasValue && hasError). "Muhtemelen hâlâ
      // öyle" bir kaydın dayanağı olamaz — kur kuralıyla aynı.
      Stream<List<Account>> cachedThenDenied() async* {
        yield const [cash, kapital];
        throw denied;
      }

      final db = await pumpEntry(
        tester,
        accounts: const [cash, kapital],
        fxSnapshot: fx,
        accountsStream: (_, _) => cachedThenDenied(),
      );
      expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);
      await type(tester, '40');
      expect(saveEnabled(tester), isFalse);
      await tapSave(tester);
      expect(await txs(db), isEmpty);
    });
  });

  group('hesap akışı henüz gelmedi', () {
    testWidgets('Kaydet kapalı, şerit YOK (yükleniyor ≠ düştü), kayıt yok', (
      tester,
    ) async {
      final pending = StreamController<List<Account>>();
      addTearDown(pending.close);
      final db = await pumpEntry(
        tester,
        accounts: const [cash, kapital],
        accountsStream: (_, _) => pending.stream,
      );
      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      await type(tester, '2000');
      expect(saveEnabled(tester), isFalse);
      await tapSave(tester);
      expect(await txs(db), isEmpty);
      expect(await balanceOf(db, Account.cashId), 1000);
    });
  });

  group('ana birim akışı düştü', () {
    testWidgets('kart harcaması ₺\'ye dondurulup YAZILMAZ', (tester) async {
      // Tenge kullanıcısı + manat kartı. Eskiden `?? 'TRY'` ile kur ₺'ye
      // dondurulur, baseCurrency 'TRY' yazılır ve ay toplamına ₸ diye
      // girerdi — kalıcı yanlış.
      final db = await pumpEntry(
        tester,
        accounts: const [cash, kapital],
        fxSnapshot: fx,
        overrides: [
          currencyProvider.overrideWith((ref) => Stream.error(denied)),
        ],
      );
      expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);
      await type(tester, '40');
      expect(saveEnabled(tester), isFalse);
      await tapSave(tester);

      expect(await txs(db), isEmpty);
      expect(await balanceOf(db, Account.cashId), 1000);
      expect(await balanceOf(db, 'a2'), 500);
    });

    testWidgets('tek hesaplı kullanıcıda da yazılmaz: nakdin birimi bilinmiyor',
        (tester) async {
      final db = await pumpEntry(
        tester,
        accounts: const [cash],
        overrides: [
          currencyProvider.overrideWith((ref) => Stream.error(denied)),
        ],
      );
      await type(tester, '300');
      expect(saveEnabled(tester), isFalse);
      await tapSave(tester);
      expect(await txs(db), isEmpty);
      expect(await balanceOf(db, Account.cashId), 1000);
    });
  });

  group('zarf akışı düştü', () {
    testWidgets('kategori seçici AÇILMAZ, "silinmedi" denir, kayıt yok', (
      tester,
    ) async {
      // Eskiden seçici "kategorin yok" derdi; kullanıcı yeniden kurup
      // kopya biriktirirdi.
      final db = await pumpEntry(
        tester,
        accounts: const [cash],
        envelopes: [food],
        overrides: [
          envelopesProvider.overrideWith((ref) => Stream.error(denied)),
        ],
      );
      expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);

      await tester.tap(find.text(RS.tr.pickCategory));
      await tester.pumpAndSettle();

      expect(find.text(RS.tr.categoriesUnavailable), findsOneWidget);
      expect(find.text(RS.tr.noCategoriesYet), findsNothing,
          reason: 'sahte "kategori yok" ekranı çizilmez');
      // Katalogdaki hazır kategori kartları da çıkmamalı: seçici hiç
      // açılmadı, tek bir sayfa başlığı yok.
      expect(find.text(RS.tr.pickIncomeSource), findsNothing);

      await type(tester, '90');
      expect(saveEnabled(tester), isFalse);
      await tapSave(tester);
      expect(await txs(db), isEmpty);
      expect(await balanceOf(db, Account.cashId), 1000);
    });
  });

  group('normal yol (regresyon)', () {
    testWidgets('yeni kullanıcı: hiç hesap belgesi yok → eski tek-kasa yolu', (
      tester,
    ) async {
      // Boş liste bir DEĞERDİR, hata değil. Hesap belgesi olmayan yeni
      // kullanıcı eskisi gibi kaydeder; `accounts/cash` ilk yazımda doğar.
      final db = await pumpEntry(tester, accounts: const []);
      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      expect(find.byType(AccountChip), findsNothing);

      await type(tester, '2000');
      expect(saveEnabled(tester), isTrue);
      await tapSave(tester);

      final all = await txs(db);
      expect(all, hasLength(1));
      final tx = all.single;
      expect(tx['amount'], 2000);
      expect(tx['currency'], 'TRY');
      expect(tx.containsKey('accountId'), isFalse);
      expect(tx.containsKey('baseAmount'), isFalse);
      expect(await balanceOf(db, Account.cashId), -2000);
      expect(find.byType(QuickEntryScreen), findsNothing);
    });

    testWidgets('yeni kullanıcı, zarfı da yok: kategori seçici açılır', (
      tester,
    ) async {
      // Zarf akışı boş liste verdi — gerçek boşluk, seçici katalogla açılır.
      await pumpEntry(tester, accounts: const []);
      await tester.tap(find.text(RS.tr.pickCategory));
      await tester.pumpAndSettle();
      expect(find.text(RS.tr.categoriesUnavailable), findsNothing);
      // Seçicinin başlığı (pill'deki yer tutucuyla aynı metin → en az iki).
      expect(find.text(RS.tr.pickCategory), findsAtLeastNWidgets(2));
    });

    testWidgets('iki hesap, akışlar sağlıklı: kart çipi ve kayıt eskisi gibi',
        (tester) async {
      final db = await pumpEntry(
        tester,
        accounts: const [cash, kapital],
        fxSnapshot: fx,
      );
      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      expect(find.byType(AccountChip), findsOneWidget);
      await type(tester, '100');
      expect(saveEnabled(tester), isTrue);
      await tapSave(tester);
      expect(await txs(db), hasLength(1));
    });
  });
}
