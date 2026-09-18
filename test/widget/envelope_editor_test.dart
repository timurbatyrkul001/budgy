import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/envelopes/add_envelope_sheet.dart';
import 'package:kopilka_app/features/transactions/category_sheet.dart';

import '../support/harness.dart';

/// Kategori düzenleyici: dar ekranda taşmaz (uzun ad, emoji/baş harf),
/// Oluştur boş adda kilitli, kayıt bölüm + rengi yazar; seçici bölümlü
/// kullanıcı kategorisini bölüm kartında gösterir.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final variants = <String, Widget>{
    'Yeni (boş)': const EnvelopeEditorScreen(sortOrder: 0),
    'Yeni (uzun ad, baş harf)': const EnvelopeEditorScreen(
        sortOrder: 0,
        previewName: 'Çok uzun bir kategori adı deneme yazısı',
        previewEmoji: '',
        previewSection: 'subscriptions'),
    'Yeni (emoji + renk)': const EnvelopeEditorScreen(
        sortOrder: 0, previewName: 'Kahvaltı', previewEmoji: '🥐', previewColorIndex: 3),
  };

  for (final width in [320.0, 360.0]) {
    for (final entry in variants.entries) {
      for (final lang in AppLanguage.values) {
        testWidgets('${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
          await pumpBudgyScreen(tester, entry.value,
              db: FakeFirebaseFirestore(), language: lang, logicalSize: Size(width, 800));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('boş adda Oluştur kapalı; kayıt bölüm + renk yazar', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpBudgyScreen(
      tester,
      const EnvelopeEditorScreen(
          sortOrder: 3, previewEmoji: '', previewColorIndex: 4, previewSection: 'health'),
      db: db,
      language: AppLanguage.en,
    );
    FilledButton button() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.en.create));
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Vitamins');
    await tester.pumpAndSettle();
    expect(find.text('Vitamins'), findsNWidgets(2), reason: 'alan + canlı ad');
    expect(find.text('V'), findsOneWidget, reason: 'emojisiz → baş harf avatarı');
    await tester.tap(find.widgetWithText(FilledButton, Strings.en.create));
    await tester.pumpAndSettle();

    final docs = (await db.collection('users').doc(testUid).collection('envelopes').get()).docs;
    expect(docs, hasLength(1));
    final d = docs.single.data();
    expect(d['name'], 'Vitamins');
    expect(d['emoji'], '');
    expect(d['section'], 'health');
    expect(d['color'], 4);
    expect(d['currency'], 'TRY');
    expect(d['sortOrder'], 3);
  });

  testWidgets('düzenleme: döviz cüzdanında bölüm satırı yok, para birimi korunur',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final usd = testEnvelope(id: 'usd', name: 'USD cüzdanı', emoji: '💵', currency: 'USD');
    await seedEnvelope(db, usd);
    await pumpBudgyScreen(
      tester,
      EnvelopeEditorScreen(sortOrder: 0, envelope: usd),
      db: db,
      envelopes: [usd],
      language: AppLanguage.tr,
    );
    expect(find.text(RS.tr.sectionLabel), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, RS.tr.save));
    await tester.pumpAndSettle();
    final d = (await db.doc('users/$testUid/envelopes/usd').get()).data()!;
    expect(d['currency'], 'USD');
    expect(d['name'], 'USD cüzdanı');
  });

  testWidgets('seçici: bölümlü kullanıcı kategorisi bölüm kartında, bölümsüz "Kendi kategorilerin"de',
      (tester) async {
    final envelopes = [
      testEnvelope(id: 'k', name: 'Kahvaltı', emoji: '', section: 'everyday', colorIndex: 1),
      testEnvelope(id: 'o', name: 'Özel', emoji: '🎯'),
    ];
    await pumpBudgyScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
                onPressed: () => showCategorySheet(context), child: const Text('open')),
          ),
        ),
      ),
      db: FakeFirebaseFirestore(),
      envelopes: envelopes,
      language: AppLanguage.en,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // "Your categories" kartı yalnız Özel'i, Everyday kartı Kahvaltı'yı içerir.
    expect(find.text('Özel'), findsOneWidget);
    expect(find.text('Kahvaltı'), findsOneWidget);
    // Kahvaltı, Groceries ile aynı bölümde ve ondan önce gelir.
    final kahvalti = tester.getTopLeft(find.text('Kahvaltı'));
    final groceries = tester.getTopLeft(find.text('Groceries'));
    final ozel = tester.getTopLeft(find.text('Özel'));
    expect(ozel.dy, lessThan(kahvalti.dy));
    expect(kahvalti.dy <= groceries.dy, isTrue);
  });
}
