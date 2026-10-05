import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/workdays/calendar_screen.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

import '../support/harness.dart';

/// Takvimde gün kaydı/silmesi PATLARSA kullanıcı bunu görmeli.
///
/// setDay/removeDay transaction'dır: çevrimdışıyken Firestore kuyruğa
/// almaz, "unavailable" ile fırlatır. Eskiden ekran bunu yakalamıyordu:
/// diyalog kapanıyor, gün işaretlenmiyor, hiçbir mesaj yoktu ve hata
/// Crashlytics'e "yakalanmamış" olarak düşüyordu.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr');
  });

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayId =
      '${today.year}-${_two(today.month)}-${_two(today.day)}';

  final errorSnack = find.text(Strings.tr.errorSaveFailed);
  // Bugün kartı: işaretsiz günde "+", işaretli günde kalem.
  final todayAdd = find.byIcon(Icons.add_rounded);
  final todayEdit = find.byIcon(Icons.edit_rounded);

  Future<void> openTodayAndSave(WidgetTester tester, String amount) async {
    await tester.tap(todayAdd);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), amount);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.tr.save));
    await tester.pumpAndSettle();
  }

  testWidgets('kayıt patlarsa kırmızı şerit çıkar ve hata raporlanır',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final reported = <String>[];
    await pumpBudgyScreen(
      tester,
      const CalendarScreen(embedded: true),
      db: db,
      workDaysRepository: _OfflineRepository(db),
      onWorkDayError: (error, _, reason) => reported.add(reason),
    );

    await openTodayAndSave(tester, '750');

    // Diyalog kapandı, ama kullanıcı sessizlikle değil mesajla karşılaştı.
    expect(find.byType(AlertDialog), findsNothing);
    expect(errorSnack, findsOneWidget);
    // Hata yutulmadı: rapora düştü.
    expect(reported, ['workDays.setDay']);
    // Hiçbir şey yazılmadı — gün yok, cüzdan yok.
    expect((await db.doc('users/$testUid/workDays/$todayId').get()).exists,
        isFalse);
  });

  testWidgets('silme patlarsa da şerit çıkar', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/$testUid/workDays/$todayId').set({
      'month': monthKeyOf(today),
      'amount': 500.0,
    });
    final reported = <String>[];
    await pumpBudgyScreen(
      tester,
      const CalendarScreen(embedded: true),
      db: db,
      workDaysRepository: _OfflineRepository(db),
      onWorkDayError: (error, _, reason) => reported.add(reason),
    );

    await tester.tap(todayEdit);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.tr.removeWord));
    await tester.pumpAndSettle();

    expect(errorSnack, findsOneWidget);
    expect(reported, ['workDays.removeDay']);
  });

  testWidgets('kayıt başarılıysa şerit yok, gün ve cüzdan yazılır',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final reported = <String>[];
    await pumpBudgyScreen(
      tester,
      const CalendarScreen(embedded: true),
      db: db,
      onWorkDayError: (error, _, reason) => reported.add(reason),
    );

    await openTodayAndSave(tester, '750');

    expect(errorSnack, findsNothing);
    expect(reported, isEmpty);
    final day = (await db.doc('users/$testUid/workDays/$todayId').get()).data();
    expect(day?['amount'], 750);
    final cash =
        (await db.doc('users/$testUid/accounts/cash').get()).data();
    expect(cash?['balance'], 750);
    // Bugün kartı artık "düzenle" halinde.
    expect(todayEdit, findsOneWidget);
  });

  /// Çevrimdışı senaryo: kullanıcı "kaydolmadı" sanıp tekrar dener.
  /// Transaction farkı sunucudaki değere göre hesaplar; ikinci kayıt da
  /// aynı tutarla cüzdanı iki kez şişirmemeli.
  testWidgets('aynı güne iki kez kaydetmek cüzdanı iki kez saymaz',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(
      tester,
      const CalendarScreen(embedded: true),
      db: db,
    );

    await openTodayAndSave(tester, '750');
    await tester.tap(todayEdit);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '750');
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.tr.save));
    await tester.pumpAndSettle();

    final cash =
        (await db.doc('users/$testUid/accounts/cash').get()).data();
    expect(cash?['balance'], 750, reason: '750+750 değil, tek 750');
  });
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Çevrimdışı Firestore'u taklit eder: transaction kuyruğa girmez,
/// "unavailable" ile fırlar — gerçek SDK'nın yaptığı gibi.
class _OfflineRepository extends WorkDaysRepository {
  _OfflineRepository(FakeFirebaseFirestore db) : super(db, testUid);

  FirebaseException get _offline => FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Failed to get document because the client is offline.',
      );

  @override
  Future<void> setDay(DateTime day, {double? amount}) async => throw _offline;

  @override
  Future<void> removeDay(DateTime day) async => throw _offline;
}
