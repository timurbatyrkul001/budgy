import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/automation/automation_screen.dart';
import 'package:kopilka_app/features/budget/budget_screen.dart';
import 'package:kopilka_app/features/categories/categories_screen.dart';
import 'package:kopilka_app/features/settings/data_management_screen.dart';
import 'package:kopilka_app/features/settings/settings_hub.dart';
import 'package:kopilka_app/features/tags/tags_screen.dart';
import 'package:kopilka_app/features/transactions/quick_entry_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

import '../support/harness.dart';

/// Ayarlar merkezi ve alt ekranları dar ekranda taşmaz; tuş takımı düzeni
/// ayarı iki klavyeyi de etkiler; etiket ekranı boş durumu gösterir.
///
/// Not: FirebaseAuth.instance testte kurulu değil → hub "Hesap" bölümü
/// currentUser=null ile (anonim gibi) çizilir; bu widget testi için yeterli.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  final now = DateTime.now();
  final envelopes = [
    testEnvelope(id: 'e1', name: 'Market ve Temel Gıda'),
    testEnvelope(id: 'e2', name: 'Ulaşım', emoji: '🚗', sortOrder: 1),
    testEnvelope(id: 'e3', name: 'Eski', emoji: '📦', sortOrder: 2, archived: true),
  ];
  final txs = [
    Tx(id: 't1', type: TxType.expense, amount: 120, date: now, envelopeId: 'e1',
        note: 'market #ev #haftalık'),
    Tx(id: 't2', type: TxType.expense, amount: 40, date: now, note: 'kahve #ev'),
  ];

  final screens = <String, Widget>{
    'Ayarlar merkezi': const SettingsHubScreen(),
    'Kategoriler': const CategoriesScreen(),
    'Etiketler': const TagsScreen(),
    'Otomasyon': const AutomationScreen(),
    'Otomasyon · kategori': const RuleKeywordsScreen(
        title: 'Groceries', catalogKey: 'groceries'),
    'Veri yönetimi': const DataManagementScreen(),
  };

  for (final width in [320.0, 360.0]) {
    for (final entry in screens.entries) {
      for (final lang in AppLanguage.values) {
        testWidgets('${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
          await pumpBudgyScreen(
            tester,
            entry.value,
            db: FakeFirebaseFirestore(),
            envelopes: envelopes,
            transactions: txs,
            language: lang,
            logicalSize: Size(width, 800),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('hub: varsayılan ad Personal, kategori sayısı aktifleri sayar',
      (tester) async {
    await pumpBudgyScreen(tester, const SettingsHubScreen(),
        db: FakeFirebaseFirestore(), envelopes: envelopes, language: AppLanguage.en);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text(RS.en.spaceSubtitle), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'arşivdeki sayılmaz');
  });

  testWidgets('etiketler: boş durum', (tester) async {
    await pumpBudgyScreen(tester, const TagsScreen(),
        db: FakeFirebaseFirestore(), language: AppLanguage.tr);
    expect(find.text(RS.tr.tagsEmpty), findsOneWidget);
  });

  testWidgets('etiketler: notlardan liste', (tester) async {
    await pumpBudgyScreen(tester, const TagsScreen(),
        db: FakeFirebaseFirestore(), transactions: txs, language: AppLanguage.tr);
    expect(find.text('ev'), findsOneWidget);
    expect(find.text('haftalık'), findsOneWidget);
  });

  group('tuş takımı düzeni', () {
    Future<List<String>> firstRowLabels(WidgetTester tester) async {
      // İlk üç rakam tuşu: görsel sıraya göre (y sonra x).
      final texts = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(InkWell), matching: find.byType(Text)))
          .map((t) => t.data ?? '')
          .where((d) => RegExp(r'^\d$').hasMatch(d))
          .toList();
      return texts.take(3).toList();
    }

    // Her ekran ayrı testte: aynı testte ikinci ProviderScope override'ları
    // değiştiremez (Riverpod ilk container'ı tutar).
    testWidgets('varsayılan: 7-8-9 üstte (hızlı giriş)', (tester) async {
      await pumpBudgyScreen(tester, const QuickEntryScreen(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      expect(await firstRowLabels(tester), ['7', '8', '9']);
    });

    testWidgets('varsayılan: 7-8-9 üstte (bütçe)', (tester) async {
      await pumpBudgyScreen(tester, const BudgetAmountStep(),
          db: FakeFirebaseFirestore(), language: AppLanguage.en);
      expect(await firstRowLabels(tester), ['7', '8', '9']);
    });

    testWidgets('ayar "top": 1-2-3 üstte (hızlı giriş)', (tester) async {
      await pumpBudgyScreen(tester, const QuickEntryScreen(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.en,
          profile: const {'keypadLayout': 'top'});
      expect(await firstRowLabels(tester), ['1', '2', '3']);
    });

    testWidgets('ayar "top": 1-2-3 üstte (bütçe)', (tester) async {
      await pumpBudgyScreen(tester, const BudgetAmountStep(),
          db: FakeFirebaseFirestore(),
          language: AppLanguage.en,
          profile: const {'keypadLayout': 'top'});
      expect(await firstRowLabels(tester), ['1', '2', '3']);
    });
  });

  testWidgets('kategoriler: arşivdeki ayrı bölümde, katalog maddesi soluk',
      (tester) async {
    await pumpBudgyScreen(tester, const CategoriesScreen(),
        db: FakeFirebaseFirestore(), envelopes: envelopes, language: AppLanguage.tr);
    expect(find.text(RS.tr.tapToAdd), findsWidgets);
    // Arşiv bölümü listenin sonunda (tembel ListView) — kaydırarak bul.
    await tester.scrollUntilVisible(
      find.text('Eski'),
      200,
      scrollable: find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable)),
      maxScrolls: 100,
    );
    expect(find.text(RS.tr.archived), findsOneWidget);
    expect(find.text('Eski'), findsOneWidget);
  });
}
