import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/load_error_banner.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/accounts/accounts_repository.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/envelopes/home_screen.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';
import 'package:kopilka_app/features/transactions/journal_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

import '../support/harness.dart';

/// Akış düştüğünde ekran BOŞ görünmemeli.
///
/// `AsyncValue.value` yüklenirken de, akış düştüğünde de null — eskiden
/// her iki hâlde ekran "sıfır ₺ / işlem yok" çiziyordu ve kullanıcı parasını
/// kaybettiğini sanıyordu (DENETIM.md'deki `accounts` kuralı olayı). Burada:
/// düşen akış → insanca mesaj + "Tekrar dene"; ham Firestore kodu ekranda
/// yok; sahte boş-durum metni yok; tekrar deneyince akış yeniden açılıyor;
/// normal yol ve GERÇEK boşluk eskisi gibi.
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
  final unavailable = FirebaseException(
    plugin: 'cloud_firestore',
    code: 'unavailable',
    message: 'The service is currently unavailable.',
  );
  final coffee = Tx(
    id: 't1',
    type: TxType.expense,
    amount: 85,
    date: DateTime.now(),
    note: 'Kahve molası',
  );

  /// Ekranı, düşen akışları veren İÇ bir kapsama sarar. Harness aynı
  /// sağlayıcıları zaten eziyor; aynı kapsamda ikinci override Riverpod'da
  /// assert — iç kapsam hem buna takılmaz hem de "Tekrar dene"nin
  /// `ref.invalidate`'i en yakın kapsamı, yani bunu bulur.
  Widget failing(Widget screen, List<Override> overrides) =>
      ProviderScope(overrides: overrides, child: screen);

  /// Ana ekran tembel bir ListView: şerit eklenince "Son hareketler" 800dp'lik
  /// yüzeyin dışına düşüp hiç kurulmuyor. Bölümü arayan testler uzun yüzey.
  const tallPhone = Size(360, 1400);

  /// Ham hata metninden hiçbir parça ekrana çıkmamalı.
  void expectNoRawError() {
    expect(find.textContaining('cloud_firestore'), findsNothing);
    expect(find.textContaining('permission'), findsNothing);
    expect(find.textContaining('FirebaseException'), findsNothing);
  }

  group('Ana ekran', () {
    testWidgets('akış düşünce insanca mesaj + Tekrar dene görünür', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        failing(const HomeScreen(), [
          recentTxsProvider.overrideWith((ref) => Stream.error(denied)),
        ]),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(Strings.tr.errorGeneric), findsOneWidget);
      expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);
      expect(find.text(RS.tr.retry), findsOneWidget);
      expectNoRawError();
    });

    testWidgets('son hareketler akışı düşünce sahte "henüz hareket yok" '
        'kartı çizilmez', (tester) async {
      await pumpBudgyScreen(
        tester,
        failing(const HomeScreen(), [
          journalProvider.overrideWith((ref) => Stream.error(denied)),
        ]),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(Strings.tr.errorGeneric), findsOneWidget);
      expect(find.text(RS.tr.recentEmpty), findsNothing);
    });

    testWidgets('Tekrar dene akışı yeniden açar; veri gelince şerit kaybolur', (
      tester,
    ) async {
      // Riverpod 3 düşen akışı kendisi de yeniden dener; bu yüzden sayaç
      // değil bayrak: kullanıcı dokunana kadar her deneme düşer.
      var healed = false;
      await pumpBudgyScreen(
        tester,
        failing(const HomeScreen(), [
          journalProvider.overrideWith(
            (ref) => healed
                ? Stream.value([coffee])
                : Stream<List<Tx>>.error(denied),
          ),
        ]),
        db: FakeFirebaseFirestore(),
        logicalSize: tallPhone,
      );
      expect(find.text(Strings.tr.errorGeneric), findsOneWidget);
      expect(find.text('Kahve molası'), findsNothing);

      healed = true;
      await tester.tap(find.byKey(kLoadErrorRetryKey));
      await tester.pumpAndSettle();

      expect(find.text(Strings.tr.errorGeneric), findsNothing);
      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      expect(find.text('Kahve molası'), findsOneWidget);
    });

    testWidgets('önbellekteki veri varken düşme: şerit çıkar, veri KALIR', (
      tester,
    ) async {
      // Firestore'un gerçek davranışı: önce önbellek, sonra sunucu reddi.
      Stream<List<Tx>> cachedThenDenied() async* {
        yield [coffee];
        throw denied;
      }

      await pumpBudgyScreen(
        tester,
        failing(const HomeScreen(), [
          journalProvider.overrideWith((ref) => cachedThenDenied()),
        ]),
        db: FakeFirebaseFirestore(),
        logicalSize: tallPhone,
      );

      expect(find.text(Strings.tr.errorGeneric), findsOneWidget);
      expect(find.text('Kahve molası'), findsOneWidget);
    });

    testWidgets('sunucuya ulaşılamadı → bağlantı metni', (tester) async {
      await pumpBudgyScreen(
        tester,
        failing(const HomeScreen(), [
          recentTxsProvider.overrideWith((ref) => Stream.error(unavailable)),
        ]),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(RS.tr.saveErrOffline), findsOneWidget);
      expect(find.text(Strings.tr.errorGeneric), findsNothing);
    });

    testWidgets('sağlayıcı zincirinde sarılı hata da açılır', (tester) async {
      // Gerçek yapı: accountsProvider → accountsRepositoryProvider. Depo
      // sağlayıcısı fırlatınca Riverpod hatayı ProviderException ile sarar;
      // şerit sarmalı açıp yine bağlantı metnini göstermeli.
      await pumpBudgyScreen(
        tester,
        failing(const HomeScreen(), [
          accountsRepositoryProvider.overrideWith((ref) => throw unavailable),
          accountsProvider.overrideWith(
            (ref) => ref.watch(accountsRepositoryProvider).watchAccounts(),
          ),
        ]),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(RS.tr.saveErrOffline), findsOneWidget);
      expectNoRawError();
    });

    testWidgets('normal yol: şerit yok; gerçek boşluk eskisi gibi', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const HomeScreen(),
        db: FakeFirebaseFirestore(),
      );

      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      expect(find.text(Strings.tr.errorGeneric), findsNothing);
      // Akış boş liste verdi → "henüz hareket yok" dürüst bir boşluk.
      expect(find.text(RS.tr.recentEmpty), findsOneWidget);
    });

    testWidgets('veri varken şerit yok', (tester) async {
      await pumpBudgyScreen(
        tester,
        const HomeScreen(),
        db: FakeFirebaseFirestore(),
        transactions: [coffee],
      );

      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      expect(find.text('Kahve molası'), findsOneWidget);
    });
  });

  group('Günlük', () {
    testWidgets('akış düşünce şerit var, sahte "henüz işlem yok" yok', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        failing(const JournalScreen(), [
          journalFullProvider.overrideWith((ref) => Stream.error(denied)),
        ]),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(Strings.tr.errorGeneric), findsOneWidget);
      expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);
      expect(find.text(Strings.tr.noOperations), findsNothing);
      expectNoRawError();
    });

    testWidgets('normal yol: gerçek boşluk "henüz işlem yok", şerit yok', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const JournalScreen(),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(Strings.tr.noOperations), findsOneWidget);
      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
    });

    testWidgets('Tekrar dene günlüğü yeniden açar', (tester) async {
      var healed = false;
      await pumpBudgyScreen(
        tester,
        failing(const JournalScreen(), [
          journalFullProvider.overrideWith(
            (ref) => healed
                ? Stream.value([coffee])
                : Stream<List<Tx>>.error(denied),
          ),
        ]),
        db: FakeFirebaseFirestore(),
      );
      expect(find.text('Kahve molası'), findsNothing);

      healed = true;
      await tester.tap(find.byKey(kLoadErrorRetryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
      expect(find.text('Kahve molası'), findsOneWidget);
    });
  });

  group('Analiz', () {
    testWidgets('akış düşünce şerit var, sahte "yeterli veri yok" yok', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        failing(const StatsScreen(), [
          recentTxsProvider.overrideWith((ref) => Stream.error(denied)),
        ]),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(Strings.tr.errorGeneric), findsOneWidget);
      expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);
      expect(find.text(RS.tr.notEnoughData), findsNothing);
      expectNoRawError();
    });

    testWidgets('normal yol: boş ay "yeterli veri yok", şerit yok', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const StatsScreen(),
        db: FakeFirebaseFirestore(),
      );

      expect(find.text(RS.tr.notEnoughData), findsOneWidget);
      expect(find.byKey(kLoadErrorRetryKey), findsNothing);
    });
  });

  group('Yerleşim: her akış düşmüş, dar ekran, üç dil', () {
    final screens = <String, Widget>{
      'Ana ekran': const HomeScreen(),
      'Günlük': const JournalScreen(),
      'Analiz': const StatsScreen(),
    };
    for (final width in [320.0, 360.0]) {
      for (final entry in screens.entries) {
        for (final lang in AppLanguage.values) {
          testWidgets(
            '${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
              await pumpBudgyScreen(
                tester,
                failing(entry.value, [
                  recentTxsProvider.overrideWith((ref) => Stream.error(denied)),
                  journalProvider.overrideWith((ref) => Stream.error(denied)),
                  journalFullProvider.overrideWith(
                    (ref) => Stream.error(denied),
                  ),
                  envelopesProvider.overrideWith((ref) => Stream.error(denied)),
                  accountsProvider.overrideWith((ref) => Stream.error(denied)),
                  cashBalanceProvider.overrideWith(
                    (ref) => Stream.error(denied),
                  ),
                  allWorkDaysProvider.overrideWith(
                    (ref) => Stream.error(denied),
                  ),
                ]),
                db: FakeFirebaseFirestore(),
                language: lang,
                logicalSize: Size(width, 800),
              );

              expect(tester.takeException(), isNull);
              expect(find.byKey(kLoadErrorRetryKey), findsOneWidget);
              final str = switch (lang) {
                AppLanguage.en => Strings.en,
                AppLanguage.tr => Strings.tr,
                AppLanguage.ru => Strings.ru,
              };
              expect(find.text(str.errorGeneric), findsOneWidget);
            },
          );
        }
      }
    }
  });
}
