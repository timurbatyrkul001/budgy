import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/app_date_picker.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/envelopes/add_envelope_sheet.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';
import 'package:kopilka_app/features/transactions/new_transaction_sheet.dart';

import '../support/harness.dart';

/// Apple'ın asgari dokunma alanı: 44×44 pt. Küçük ok/kalem düğmelerinin
/// görünen kutusu küçük kalsa da vuruş alanı bu eşiğin altına inmemeli.
const _minTap = 44.0;

/// [icon] taşıyan her düğmenin en yakın InkWell'i en az 44×44 olmalı.
void expectTapTarget(WidgetTester tester, IconData icon) {
  final icons = find.byIcon(icon);
  expect(icons, findsWidgets, reason: '$icon ekranda yok');
  for (var i = 0; i < icons.evaluate().length; i++) {
    final ink = find.ancestor(of: icons.at(i), matching: find.byType(InkWell));
    expect(ink, findsWidgets, reason: '$icon bir InkWell içinde değil');
    final size = tester.getSize(ink.first);
    expect(size.width, greaterThanOrEqualTo(_minTap),
        reason: '$icon dokunma genişliği ${size.width} < $_minTap');
    expect(size.height, greaterThanOrEqualTo(_minTap),
        reason: '$icon dokunma yüksekliği ${size.height} < $_minTap');
  }
}

/// Alt sayfaları bir düğmeye basarak açar (route ittikleri için doğrudan
/// pump edilemiyorlar).
class _Launcher extends StatelessWidget {
  const _Launcher({required this.onTap});

  final void Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => onTap(context),
          child: const Text('aç'),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  testWidgets('İstatistik: ay okları 44 px dokunma alanı', (tester) async {
    await pumpBudgyScreen(tester, const StatsScreen(),
        db: FakeFirebaseFirestore(), logicalSize: const Size(320, 800));
    expectTapTarget(tester, Icons.chevron_left_rounded);
    expectTapTarget(tester, Icons.chevron_right_rounded);
  });

  testWidgets('Takvim seçici: ay okları 44 px dokunma alanı', (tester) async {
    final now = DateTime.now();
    await pumpBudgyScreen(
      tester,
      _Launcher(
        onTap: (context) => showAppDatePicker(
          context: context,
          initial: now,
          first: DateTime(now.year - 2),
          last: now,
          localeCode: 'tr',
        ),
      ),
      db: FakeFirebaseFirestore(),
      logicalSize: const Size(320, 800),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expectTapTarget(tester, Icons.chevron_left_rounded);
    expectTapTarget(tester, Icons.chevron_right_rounded);
  });

  testWidgets('Yeni işlem: tarih adım okları 44 px dokunma alanı',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final envelopes = [testEnvelope(id: 'e1', name: 'Yemek')];
    for (final e in envelopes) {
      await seedEnvelope(db, e);
    }
    await pumpBudgyScreen(
      tester,
      _Launcher(
        onTap: (context) => showNewTransaction(context, mode: TxMode.expense),
      ),
      db: db,
      envelopes: envelopes,
      logicalSize: const Size(320, 800),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    // Hem üstteki geri dairesi hem tarih adım okları aynı ikonu kullanıyor;
    // hepsi eşiği geçmeli.
    expectTapTarget(tester, Icons.chevron_left);
    expectTapTarget(tester, Icons.chevron_right);
  });

  testWidgets('Kategori düzenleyici: emoji kalemi 44 px dokunma alanı',
      (tester) async {
    await pumpBudgyScreen(
      tester,
      const EnvelopeEditorScreen(sortOrder: 0, previewEmoji: '🥐'),
      db: FakeFirebaseFirestore(),
      logicalSize: const Size(320, 800),
    );
    expectTapTarget(tester, Icons.edit_rounded);
    // Dokunma alanı kalemin görünen dairesinin (34 px) dışına taşsa da
    // kalem fiilen basılabilir olmalı.
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
