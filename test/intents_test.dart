import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/fx.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/accounts/account.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/home/fx_providers.dart';
import 'package:kopilka_app/features/intents/add_expense_intent.dart';
import 'package:kopilka_app/features/intents/intent_channel.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import 'support/harness.dart';

/// Kısayollar/Siri "harcama ekle" intent'inin Dart ucu: argüman ayrıştırma,
/// hızlı girişle aynı yoldan yazma, ada göre kategori/hesap, tutmayan adın
/// mesajda söylenmesi, kur yokken ret, dayanak akışı düşünce/gelmeyince ret
/// (VERİTABANINA bakarak: işlem yok, bakiye kıpırdamaz) ve kanal tesisatı.
void main() {
  final denied = FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
    message: 'Missing or insufficient permissions.',
  );

  const cash = Account(
    id: Account.cashId,
    name: '',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 0,
  );
  const enpara = Account(
    id: 'enpara',
    name: 'Enpara',
    currency: 'TRY',
    kind: AccountKind.card,
    balance: 1000,
    sortOrder: 1,
  );
  const kapital = Account(
    id: 'kapital',
    name: 'Kapital Bank',
    currency: 'USD',
    kind: AccountKind.card,
    balance: 500,
    sortOrder: 2,
  );

  Future<void> seedAccount(FakeFirebaseFirestore db, Account a) =>
      db.doc('users/$testUid/accounts/${a.id}').set(a.toMap());

  /// Handler `WidgetRef` istiyor; gerçek uygulamada host widget'tan gelir.
  /// Burada tek bir Consumer ile yakalıyoruz, ekran yok.
  ///
  /// [accountsStream] / [currencyStream] / [envelopesStream]: akışın
  /// kaynağı (düşen, askıda, gecikmeli); verilmezse sabit değer. Akış
  /// kurucuları handler'ın İÇİNDE, `runAsync` altında koşar — gecikmeli
  /// akışın zamanlayıcısı gerçek saatte işler. [warm]: akışları handler'dan
  /// ÖNCE bir izleyiciyle kurup oturtur — "uygulama zaten açık, akış çoktan
  /// değer verip sonra düştü" hâli (önbellek + hata).
  Future<WidgetRef> pumpRef(
    WidgetTester tester, {
    required FakeFirebaseFirestore db,
    List<Envelope> envelopes = const [],
    List<Account> accounts = const [cash],
    List<Tx> transactions = const [],
    AppLanguage language = AppLanguage.tr,
    String currency = 'TRY',
    FxSnapshot? fxSnapshot,
    Stream<List<Account>> Function()? accountsStream,
    Stream<String> Function()? currencyStream,
    Stream<List<Envelope>> Function()? envelopesStream,
    bool warm = false,
  }) async {
    late WidgetRef captured;
    await pumpBudgyScreen(
      tester,
      Consumer(
        builder: (_, ref, _) {
          captured = ref;
          if (warm) {
            ref.watch(accountsProvider);
            ref.watch(currencyProvider);
            ref.watch(envelopesProvider);
          }
          return const SizedBox();
        },
      ),
      db: db,
      envelopes: envelopes,
      transactions: transactions,
      language: language,
      currency: currency,
      fxSnapshot: fxSnapshot,
      currencyStream: currencyStream == null ? null : (_) => currencyStream(),
      envelopesStream:
          envelopesStream == null ? null : (_) => envelopesStream(),
      overrideAccounts: false,
      extraOverrides: [
        accountsProvider.overrideWith(
          (ref) => accountsStream?.call() ?? Stream.value(accounts),
        ),
      ],
    );
    return captured;
  }

  Future<List<Map<String, dynamic>>> txs(FakeFirebaseFirestore db) async {
    final snap = await db
        .collection('users')
        .doc(testUid)
        .collection('transactions')
        .get();
    return [for (final d in snap.docs) d.data()];
  }

  Future<double> balance(FakeFirebaseFirestore db, String accountId) async {
    final doc = await db.doc('users/$testUid/accounts/$accountId').get();
    return (doc.data()?['balance'] as num?)?.toDouble() ?? 0;
  }

  /// Handler'ı GERÇEK zaman diliminde koştur: testWidgets'ın sahte saati
  /// pump edilmeden ilerlemez; Firestore taklidi ve Riverpod zamanlayıcısı
  /// sıfır süreli Timer kullanıyor, sahte saatte sonsuza kadar beklerdi.
  Future<Map<String, Object?>> run(
    WidgetTester tester,
    WidgetRef ref,
    Map<String, Object?> args, {
    Duration dataTimeout = const Duration(seconds: 10),
  }) async {
    final reply = await tester.runAsync(
      () => AddExpenseIntentHandler(ref, dataTimeout: dataTimeout).handle(args),
    );
    return reply!;
  }

  /// [value]'yu [delay] sonra bir kez yayan akış — soğuk başlatma taklidi:
  /// Firestore henüz cevap vermedi ama verecek.
  Stream<T> late<T>(
    T value, [
    Duration delay = const Duration(milliseconds: 250),
  ]) =>
      Stream.fromFuture(Future.delayed(delay, () => value));

  group('argüman ayrıştırma', () {
    test('eksik ya da bozuk alanlar null döner', () {
      expect(AddExpenseIntentRequest.tryParse(null), isNull);
      expect(AddExpenseIntentRequest.tryParse('250'), isNull);
      expect(AddExpenseIntentRequest.tryParse({'source': 'siri'}), isNull);
      expect(
        AddExpenseIntentRequest.tryParse({'amount': '250', 'source': 'siri'}),
        isNull,
        reason: 'tutar sayı olmalı, metin değil',
      );
      expect(
        AddExpenseIntentRequest.tryParse({'amount': 250, 'source': 'widget'}),
        isNull,
        reason: 'source yalnız siri | shortcut',
      );
      expect(AddExpenseIntentRequest.tryParse({'amount': 250}), isNull);
    });

    test('tam sözlük okunur, boş metinler null olur', () {
      final r = AddExpenseIntentRequest.tryParse({
        'amount': 250,
        'note': '  Migros ',
        'categoryName': '',
        'accountName': '   ',
        'source': 'shortcut',
      })!;
      expect(r.amount, 250.0);
      expect(r.note, 'Migros');
      expect(r.categoryName, isNull);
      expect(r.accountName, isNull);
      expect(r.source, 'shortcut');
    });
  });

  testWidgets('bozuk istek ve sıfır tutar: ok=false, anlaşılır metin',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final ref = await pumpRef(tester, db: db, language: AppLanguage.ru);

    final bad = await run(tester, ref, {'note': 'x'});
    expect(bad['ok'], false);
    expect(bad['message'], RS.ru.intentBadRequest);

    final zero = await run(tester, ref, {'amount': 0, 'source': 'siri'});
    expect(zero['ok'], false);
    expect(zero['message'], RS.ru.intentInvalidAmount);

    final negative = await run(tester, ref, {'amount': -5, 'source': 'siri'});
    expect(negative['ok'], false);
    expect(negative['message'], RS.ru.intentInvalidAmount);

    expect(await txs(db), isEmpty, reason: 'hiçbir şey yazılmadı');
  });

  testWidgets('sade harcama: cüzdandan düşer, kategorisiz mesaj',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final ref = await pumpRef(tester, db: db, language: AppLanguage.ru);

    final reply = await run(tester, ref, {'amount': 250.0, 'source': 'siri'});
    expect(reply['ok'], true);
    expect(reply['message'], 'Записал 250 ₺ без категории.');

    final list = await txs(db);
    expect(list, hasLength(1));
    final tx = list.single;
    expect(tx['type'], 'expense');
    expect(tx['amount'], 250.0);
    expect(tx['envelopeId'], isNull);
    expect(tx['accountId'], isNull, reason: 'tek hesap: eski tek-kasa yolu');
    expect(await balance(db, 'cash'), -250.0);
  });

  testWidgets('kategori adı tutar: zarfa yazılır, not saklanır',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final market = testEnvelope(id: 'market', name: 'Market', emoji: '🛒');
    await seedEnvelope(db, market);
    final ref = await pumpRef(
      tester,
      db: db,
      envelopes: [market],
      language: AppLanguage.tr,
    );

    final reply = await run(tester, ref, {
      'amount': 180,
      'note': 'Haftalık alışveriş',
      'categoryName': 'MARKET',
      'source': 'shortcut',
    });
    expect(reply['ok'], true);
    expect(reply['message'], '180 ₺ Market kategorisine kaydedildi.');

    final tx = (await txs(db)).single;
    expect(tx['envelopeId'], 'market');
    expect(tx['envelopeName'], 'Market');
    expect(tx['note'], 'Haftalık alışveriş');
  });

  testWidgets('preset zarf çevrili adıyla da tutar', (tester) async {
    final db = FakeFirebaseFirestore();
    final food = testEnvelope(id: 'food', name: 'Food', presetKey: 'food');
    await seedEnvelope(db, food);
    final ref = await pumpRef(
      tester,
      db: db,
      envelopes: [food],
      language: AppLanguage.ru,
    );

    final reply = await run(tester, ref, {
      'amount': 40,
      'categoryName': 'еда',
      'source': 'siri',
    });
    expect(reply['ok'], true);
    expect(reply['message'], 'Записал 40 ₺ в «Еда».');
    expect((await txs(db)).single['envelopeId'], 'food');
  });

  testWidgets('kategori adı tutmaz: kategorisiz yazılır ve mesaj söyler',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final market = testEnvelope(id: 'market', name: 'Market');
    await seedEnvelope(db, market);
    final ref = await pumpRef(
      tester,
      db: db,
      envelopes: [market],
      language: AppLanguage.en,
    );

    final reply = await run(tester, ref, {
      'amount': 99,
      'categoryName': 'Unicorns',
      'source': 'shortcut',
    });
    expect(reply['ok'], true);
    expect(
      reply['message'],
      'Recorded 99 ₺ without a category. Category “Unicorns” wasn\'t found.',
    );
    expect((await txs(db)).single['envelopeId'], isNull);
  });

  testWidgets('kategori verilmedi: nottaki anahtar kelime var olan zarfı seçer',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final groceries =
        testEnvelope(id: 'g1', name: 'Market', presetKey: 'groceries');
    await seedEnvelope(db, groceries);
    final ref = await pumpRef(
      tester,
      db: db,
      envelopes: [groceries],
      language: AppLanguage.tr,
    );

    final reply = await run(tester, ref, {
      'amount': 320,
      'note': 'Migros Beşiktaş',
      'source': 'shortcut',
    });
    expect(reply['ok'], true);
    expect((await txs(db)).single['envelopeId'], 'g1');
    expect(reply['message'], contains('Market'));
  });

  testWidgets('hesap adı tutar: o karttan düşer, kur 1 ile dondurulur',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await seedAccount(db, enpara);
    final ref = await pumpRef(
      tester,
      db: db,
      accounts: const [cash, enpara],
      language: AppLanguage.tr,
    );

    final reply = await run(tester, ref, {
      'amount': 250,
      'accountName': 'enpara',
      'source': 'siri',
    });
    expect(reply['ok'], true);
    expect(reply['message'], '250 ₺ kategorisiz kaydedildi.');

    final tx = (await txs(db)).single;
    expect(tx['accountId'], 'enpara');
    expect(tx['currency'], 'TRY');
    expect(tx['baseAmount'], 250.0);
    expect(tx['baseCurrency'], 'TRY');
    expect(tx['fxRate'], 1);
    expect(await balance(db, 'enpara'), 750.0);
    expect(await balance(db, 'cash'), 0, reason: 'nakit dokunulmadı');
  });

  testWidgets('hesap adı tutmaz: öneriye düşer ve mesaj hangisini söyler',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await seedAccount(db, enpara);
    final ref = await pumpRef(
      tester,
      db: db,
      accounts: const [cash, enpara],
      language: AppLanguage.ru,
    );

    final reply = await run(tester, ref, {
      'amount': 75,
      'accountName': 'Garanti',
      'source': 'shortcut',
    });
    expect(reply['ok'], true);
    // Geçmiş yok → listedeki ilk hesap (nakit); adsız nakit RS.cash ile.
    expect(
      reply['message'],
      'Записал 75 ₺ без категории. Счёт «Garanti» не найден — записал на '
      '${RS.ru.cash}.',
    );
    final tx = (await txs(db)).single;
    expect(tx['accountId'], 'cash');
    expect(await balance(db, 'cash'), -75.0);
  });

  testWidgets('yabancı birimli kart + kur yok: yazmaz, ok=false',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await seedAccount(db, kapital);
    final ref = await pumpRef(
      tester,
      db: db,
      accounts: const [cash, kapital],
      language: AppLanguage.tr,
      fxSnapshot: null,
    );

    final reply = await run(tester, ref, {
      'amount': 12,
      'accountName': 'Kapital Bank',
      'source': 'siri',
    });
    expect(reply['ok'], false);
    expect(reply['message'], RS.tr.fxFreezeUnavailable);
    expect(await txs(db), isEmpty, reason: 'kursuz kayıt YASAK');
    expect(await balance(db, 'kapital'), 500.0);
  });

  testWidgets('yabancı birimli kart + kur var: kur dondurulur',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await seedAccount(db, kapital);
    final ref = await pumpRef(
      tester,
      db: db,
      accounts: const [cash, kapital],
      language: AppLanguage.tr,
      // 1 TRY = 0.05 USD → 1 USD = 20 TRY.
      fxSnapshot: FxSnapshot(
        base: 'TRY',
        rates: const {'USD': 0.05},
        fetchedAt: DateTime(2026, 10, 5),
      ),
    );

    final reply = await run(tester, ref, {
      'amount': 12,
      'accountName': 'kapital bank',
      'source': 'shortcut',
    });
    expect(reply['ok'], true);
    expect(reply['message'], '12 \$ kategorisiz kaydedildi.');

    final tx = (await txs(db)).single;
    expect(tx['accountId'], 'kapital');
    expect(tx['currency'], 'USD');
    expect(tx['amount'], 12.0);
    expect(tx['baseAmount'], 240.0);
    expect(tx['baseCurrency'], 'TRY');
    expect((tx['fxRate'] as num).toDouble(), closeTo(20, 1e-9));
    expect(await balance(db, 'kapital'), 488.0);
  });

  group('dayanak yoksa yazma', () {
    // Ekran yok: burada ret, kullanıcının duyacağı TEK şey. Sınamalar
    // mesaja değil veritabanına bakar — işlem koleksiyonu boş, bakiyeler
    // yerinde. Hızlı girişteki quick_entry_sources_test ile aynı ilke.

    testWidgets('hesap akışı düştü: yazmaz, ok=false, anlaşılır metin',
        (tester) async {
      // İki kartlı kullanıcı. Eskiden `?? []` ile "tek kasa" sanılır, 250
      // nakitten düşer ve Siri "kaydettim" derdi.
      final db = FakeFirebaseFirestore();
      await seedAccount(db, cash);
      await seedAccount(db, enpara);
      final ref = await pumpRef(
        tester,
        db: db,
        language: AppLanguage.ru,
        accountsStream: () => Stream.error(denied),
      );

      final reply = await run(tester, ref, {
        'amount': 250,
        'accountName': 'Enpara',
        'source': 'siri',
      });
      expect(reply['ok'], false);
      expect(reply['message'], RS.ru.intentAccountsUnavailable);
      expect(await txs(db), isEmpty, reason: 'uydurma hesaba kayıt yok');
      expect(await balance(db, 'cash'), 0);
      expect(await balance(db, 'enpara'), 1000);
    });

    testWidgets('önbellekten eski liste + hata (uygulama açık): yine yazmaz',
        (tester) async {
      // Firestore'un gerçek davranışı: önce önbellek, sonra sunucu reddi.
      // Riverpod eski değeri korur (hasValue && hasError). "Muhtemelen hâlâ
      // öyle" bir kaydın dayanağı olamaz — kur kuralıyla aynı.
      Stream<List<Account>> cachedThenDenied() async* {
        yield const [cash, enpara];
        throw denied;
      }

      final db = FakeFirebaseFirestore();
      await seedAccount(db, enpara);
      final ref = await pumpRef(
        tester,
        db: db,
        language: AppLanguage.tr,
        accountsStream: cachedThenDenied,
        warm: true,
      );
      expect(ref.read(accountsProvider).hasError, isTrue,
          reason: 'sahne: değer geldi, sonra düştü');
      expect(ref.read(accountsProvider).hasValue, isTrue);

      final reply = await run(tester, ref, {
        'amount': 40,
        'accountName': 'Enpara',
        'source': 'shortcut',
      });
      expect(reply['ok'], false);
      expect(reply['message'], RS.tr.intentAccountsUnavailable);
      expect(await txs(db), isEmpty);
      expect(await balance(db, 'enpara'), 1000);
    });

    testWidgets('hesap akışı süresinde gelmedi: bekler, sonra reddeder',
        (tester) async {
      // Akış ne değer veriyor ne düşüyor. Soğuk başlatma gibi görünür ama
      // süre dolunca beklemenin anlamı kalmaz: ret, kayıt yok.
      final pending = StreamController<List<Account>>();
      addTearDown(pending.close);
      final db = FakeFirebaseFirestore();
      final ref = await pumpRef(
        tester,
        db: db,
        language: AppLanguage.en,
        accountsStream: () => pending.stream,
      );

      final reply = await run(
        tester,
        ref,
        {'amount': 250, 'source': 'siri'},
        dataTimeout: const Duration(milliseconds: 300),
      );
      expect(reply['ok'], false);
      expect(reply['message'], RS.en.intentAccountsUnavailable);
      expect(await txs(db), isEmpty);
    });

    testWidgets('ana birim akışı düştü: kart harcaması ₺\'ye dondurulup YAZILMAZ',
        (tester) async {
      // Eskiden `?? 'TRY'`: tenge kullanıcısının kart harcaması ₺'ye
      // dondurulur, baseCurrency 'TRY' yazılır, ay toplamı kalıcı bozulurdu.
      final db = FakeFirebaseFirestore();
      await seedAccount(db, enpara);
      final ref = await pumpRef(
        tester,
        db: db,
        accounts: const [cash, enpara],
        language: AppLanguage.tr,
        currencyStream: () => Stream.error(denied),
      );
      expect(ref.read(knownCurrencyCodeProvider), isNull,
          reason: 'yazan tarafların ortak kaynağı null demeli');

      final reply = await run(tester, ref, {
        'amount': 250,
        'accountName': 'Enpara',
        'source': 'siri',
      });
      expect(reply['ok'], false);
      expect(reply['message'], RS.tr.intentCurrencyUnavailable);
      expect(await txs(db), isEmpty);
      expect(await balance(db, 'enpara'), 1000);
      expect(await balance(db, 'cash'), 0);
    });

    testWidgets('ana birim akışı düştü, tek kasa: o da yazmaz', (tester) async {
      // Nakdin birimi bilinmiyor; cevapta okunacak tutar da ("250 ₺") ana
      // birime dayanır. Hızlı girişle aynı karar.
      final db = FakeFirebaseFirestore();
      final ref = await pumpRef(
        tester,
        db: db,
        language: AppLanguage.ru,
        currencyStream: () => Stream.error(denied),
      );
      final reply = await run(tester, ref, {'amount': 250, 'source': 'siri'});
      expect(reply['ok'], false);
      expect(reply['message'], RS.ru.intentCurrencyUnavailable);
      expect(await txs(db), isEmpty);
      expect(await balance(db, 'cash'), 0);
    });

    testWidgets('zarf akışı düştü + kategori adı: "bulunamadı" demez, yazmaz',
        (tester) async {
      // Eskiden kategorisiz yazılır ve "Market kategorisi bulunamadı" denirdi
      // — yalan: liste gelmedi, kategori duruyor. Kullanıcı yeniden kurup
      // kopya biriktirmesin.
      final db = FakeFirebaseFirestore();
      final market = testEnvelope(id: 'market', name: 'Market');
      await seedEnvelope(db, market);
      final ref = await pumpRef(
        tester,
        db: db,
        language: AppLanguage.tr,
        envelopesStream: () => Stream.error(denied),
      );
      final reply = await run(tester, ref, {
        'amount': 180,
        'categoryName': 'Market',
        'source': 'shortcut',
      });
      expect(reply['ok'], false);
      expect(reply['message'], RS.tr.intentCategoriesUnavailable);
      expect(await txs(db), isEmpty);
      expect(await balance(db, 'cash'), 0);
    });

    testWidgets('zarf akışı düştü ama kategori istenmedi: kayıt geçer',
        (tester) async {
      // Gereksiz katılık da kötü: sade "250 lira" kategoriye hiç bakmaz,
      // kategori listesi yüzünden reddedilmemeli.
      final db = FakeFirebaseFirestore();
      final ref = await pumpRef(
        tester,
        db: db,
        language: AppLanguage.ru,
        envelopesStream: () => Stream.error(denied),
      );
      final reply = await run(tester, ref, {'amount': 250, 'source': 'siri'});
      expect(reply['ok'], true);
      expect(reply['message'], 'Записал 250 ₺ без категории.');
      expect((await txs(db)).single['envelopeId'], isNull);
      expect(await balance(db, 'cash'), -250.0);
    });

    testWidgets('soğuk başlatma: akışlar gecikmeli gelir → bekler, YAZAR',
        (tester) async {
      // Uygulama intent için ayağa kalkıyor, Firestore henüz cevap vermedi.
      // Bu hata değil; gelmesi beklenir ve kayıt doğru karta, doğru birimde
      // düşer — zaman aşımıyla boşuna reddedilmez.
      final db = FakeFirebaseFirestore();
      await seedAccount(db, enpara);
      final market = testEnvelope(id: 'market', name: 'Market');
      await seedEnvelope(db, market);
      final ref = await pumpRef(
        tester,
        db: db,
        language: AppLanguage.tr,
        accountsStream: () => late(const [cash, enpara]),
        currencyStream: () => late('TRY'),
        envelopesStream: () => late([market]),
      );

      final reply = await run(tester, ref, {
        'amount': 250,
        'categoryName': 'Market',
        'accountName': 'Enpara',
        'source': 'siri',
      });
      expect(reply['ok'], true);
      expect(reply['message'], '250 ₺ Market kategorisine kaydedildi.');
      final tx = (await txs(db)).single;
      expect(tx['accountId'], 'enpara');
      expect(tx['envelopeId'], 'market');
      expect(tx['currency'], 'TRY');
      expect(await balance(db, 'enpara'), 750.0);
      expect(await balance(db, 'cash'), 0);
    });

    testWidgets('REGRESYON — yeni kullanıcı: hesap belgesi yok, yine yazar',
        (tester) async {
      // Boş liste bir DEĞERDİR, hata değil. Hiç hesap kurmamış kullanıcı
      // eskisi gibi tek-kasa yoluyla kaydeder; `accounts/cash` ilk yazımda
      // doğar. Burası bozulursa yeni kullanıcı Siri'den hiç yazamaz.
      final db = FakeFirebaseFirestore();
      final ref = await pumpRef(
        tester,
        db: db,
        accounts: const [],
        language: AppLanguage.ru,
      );
      // Not kural tutmayan bir ad: kategori otomasyonu ("kahve" → Kafe)
      // bu testin konusu değil, zarf listesinin boş gelmesi de bir değer.
      final reply = await run(tester, ref, {
        'amount': 250,
        'note': 'Ali',
        'source': 'siri',
      });
      expect(reply['ok'], true);
      expect(reply['message'], 'Записал 250 ₺ без категории.');
      final tx = (await txs(db)).single;
      expect(tx['note'], 'Ali');
      expect(tx['amount'], 250.0);
      expect(tx['currency'], 'TRY', reason: 'eski tek-kasa işareti');
      expect(tx['accountId'], isNull);
      expect(tx.containsKey('baseAmount'), isFalse, reason: 'kur dondurma yok');
      expect(await balance(db, 'cash'), -250.0);
    });
  });

  testWidgets('kanal: host ready der, natifin addExpense çağrısı cevaplanır',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final outgoing = <MethodCall>[];
    messenger.setMockMethodCallHandler(intentChannel, (call) async {
      outgoing.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(intentChannel, null));

    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(
      tester,
      const IntentChannelHost(child: SizedBox()),
      db: db,
      language: AppLanguage.en,
      overrideAccounts: false,
      extraOverrides: [
        accountsProvider.overrideWith((ref) => Stream.value(const [cash])),
      ],
    );
    expect(outgoing.map((c) => c.method), ['ready']);

    // Natif → Flutter: platform mesajını elle teslim et, zarfı çöz.
    const codec = StandardMethodCodec();
    ByteData? replyBytes;
    await tester.runAsync(
      () => messenger.handlePlatformMessage(
        intentChannelName,
        codec.encodeMethodCall(const MethodCall('addExpense', {
          'amount': 250.0,
          'note': 'Ali',
          'source': 'siri',
        })),
        (data) => replyBytes = data,
      ),
    );
    final reply = codec.decodeEnvelope(replyBytes!) as Map;
    expect(reply['ok'], true);
    expect(reply['message'], 'Recorded 250 ₺ without a category.');
    expect((await txs(db)).single['note'], 'Ali');

    // Bilinmeyen metot: natif FlutterMethodNotImplemented görür.
    ByteData? unknown;
    await tester.runAsync(
      () => messenger.handlePlatformMessage(
        intentChannelName,
        codec.encodeMethodCall(const MethodCall('nope')),
        (data) => unknown = data,
      ),
    );
    expect(unknown, isNull, reason: 'null zarf = not implemented');
  });
}
