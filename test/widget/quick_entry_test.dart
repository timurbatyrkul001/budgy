import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/transactions/category_sheet.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';

import '../support/harness.dart';

/// Hızlı giriş ("+") ekranı: klavye + ifade, Kaydet kilidi, kategorisiz
/// kayıt; kategori sayfası dar ekranda taşmaz.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  Future<Map<String, dynamic>> singleTx(FakeFirebaseFirestore db) async {
    final snap =
        await db.collection('users').doc(testUid).collection('transactions').get();
    expect(snap.docs, hasLength(1));
    return snap.docs.single.data();
  }

  testWidgets('tuşlar ifadeyi kurar, sonuç hesaplanır', (tester) async {
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: FakeFirebaseFirestore(), language: AppLanguage.en);

    for (final k in ['1', '2', '0', '0', '+', '8', '0', '0']) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // "= 2,000 ₺" sonuç satırı.
    expect(find.textContaining('= 2,000'), findsOneWidget);
  });

  testWidgets('her yeni rakam kayarak girer, önceki rakamlar tekrar oynamaz',
      (tester) async {
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: FakeFirebaseFirestore(), language: AppLanguage.en);

    // Bir metnin atalarındaki en düşük FadeTransition opaklığı (sayfa geçişi
    // de FadeTransition kullanır; o 1'dir, rakamın kendi girişi 1'in altında).
    double minFade(String text) {
      var min = 1.0;
      for (final el in find.text(text).evaluate()) {
        el.visitAncestorElements((a) {
          final w = a.widget;
          if (w is FadeTransition && w.opacity.value < min) {
            min = w.opacity.value;
          }
          return true;
        });
      }
      return min;
    }

    for (final k in ['1', '2']) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pumpAndSettle();
    }
    // Üçüncü rakam: ilki değil, yine de animasyonla girmeli.
    await tester.tap(find.widgetWithText(InkWell, '3').last);
    await tester.pump(const Duration(milliseconds: 60));
    expect(minFade('3'), lessThan(1.0), reason: 'yeni rakam belirerek girer');
    expect(minFade('1'), 1.0, reason: 'yerindeki rakam yeniden oynamaz');

    await tester.pumpAndSettle();
    expect(minFade('3'), 1.0);
  });

  testWidgets('tutar 0 iken Kaydet kapalı', (tester) async {
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: FakeFirebaseFirestore(), language: AppLanguage.tr);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, RS.tr.save));
    expect(button.onPressed, isNull);
  });

  testWidgets('kategorisiz kayıt cüzdandan düşer ve ekranı kapatır',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: db, language: AppLanguage.tr);

    for (final k in ['2', '0', '0', '0']) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, RS.tr.save));
    await tester.pumpAndSettle();

    final tx = await singleTx(db);
    expect(tx['type'], 'expense');
    expect(tx['amount'], 2000);
    expect(tx['envelopeId'], isNull, reason: 'kategori zorunlu değil');
    final cash = await db
        .collection('users')
        .doc(testUid)
        .collection('accounts')
        .doc('cash')
        .get();
    expect(cash.data()!['balance'], -2000);
    expect(find.byType(QuickEntryScreen), findsNothing);
  });

  testWidgets('gelir modu cüzdana ekler', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: db, language: AppLanguage.en);
    // Gider/gelir seçimi "…" menüsünde.
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RS.en.income));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, '5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, RS.en.save));
    await tester.pumpAndSettle();
    final tx = await singleTx(db);
    expect(tx['type'], 'income');
    expect(tx['amount'], 5);
  });

  testWidgets('geri tuşuna uzun basınca temizler', (tester) async {
    await pumpBudgyScreen(tester, const QuickEntryScreen(),
        db: FakeFirebaseFirestore(), language: AppLanguage.en);
    for (final k in ['7', '7']) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pump();
    }
    await tester.longPress(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, RS.en.save));
    expect(button.onPressed, isNull);
  });

  for (final width in [320.0, 360.0]) {
    for (final lang in AppLanguage.values) {
      testWidgets('hızlı giriş · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
        await pumpBudgyScreen(
          tester,
          const QuickEntryScreen(initialExpression: '1250.5+300'),
          db: FakeFirebaseFirestore(),
          language: lang,
          logicalSize: Size(width, 800),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('kategori sayfası · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
        final db = FakeFirebaseFirestore();
        final envelopes = [
          testEnvelope(id: 'e1', name: 'Market ve Temel Gıda'),
          testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', sortOrder: 1),
        ];
        await pumpBudgyScreen(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showCategorySheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          db: db,
          envelopes: envelopes,
          language: lang,
          logicalSize: Size(width, 800),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text(RS.of(lang.code).yourCategories), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
