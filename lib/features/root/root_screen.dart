import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preview.dart';
import '../../core/widget_service.dart';
import '../envelopes/budget_repository.dart';
import '../budget/budget_period.dart';
import '../budget/budget_screen.dart';
import '../automation/automation_screen.dart';
import '../categories/categories_screen.dart';
import '../envelopes/add_envelope_sheet.dart';
import '../converter/converter_screen.dart';
import '../converter/currency_picker_screen.dart';
import '../envelopes/home_screen.dart';
import '../settings/data_management_screen.dart';
import '../settings/settings_hub.dart';
import '../space/space.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../transactions/quick_entry_screen.dart';
import '../workdays/calendar_screen.dart';

/// Kök ekran: alt sekme çubuğu yok — Takvim/Hedefler/İstatistik artık ana
/// ekranın menüsünden push edilen rotalar. Burada yalnız ana ekran ve
/// widget senkronu var.
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  @override
  void initState() {
    super.initState();
    // Debug önizlemesi: "+" ekranını (ve istenen alt sayfayı) otomatik aç.
    if (kPreviewQuickEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showQuickEntry(
            context,
            initialExpression: kPreviewQuickEntryAmount,
            autoSheet:
                kPreviewQuickEntrySheet.isEmpty ? null : kPreviewQuickEntrySheet,
          ));
    }
    final preview = switch (kPreviewBudget) {
      'empty' => const BudgetScreen(),
      'amount' => const BudgetAmountStep(initialPeriod: BudgetPeriod.weekly),
      'amountMonthly' =>
        const BudgetAmountStep(initialPeriod: BudgetPeriod.monthly),
      'categories' => const BudgetCategoriesStep(
          settings: BudgetSettings(amount: 15000, period: BudgetPeriod.monthly),
          autoSuggest: true),
      _ => switch (kPreviewConverter) {
          'two' => const CurrencyConverterScreen(
              initialRows: ['USD', 'TRY'], initialExpression: '100'),
          'four' => const CurrencyConverterScreen(
              initialRows: ['USD', 'TRY', 'EUR', 'KZT'], initialExpression: '250'),
          'picker' => const CurrencyPickerScreen(exclude: {'TRY'}),
          'pickerScrolled' => const CurrencyPickerScreen(
              exclude: {'TRY'}, initialScroll: 1500),
          _ => switch (kPreviewSettings) {
          'hub' => const SettingsHubScreen(),
          'hubScrolled' => const SettingsHubScreen(initialScroll: 620),
          'categories' => const CategoriesScreen(),
          'automation' => const AutomationScreen(),
          'automationCat' => const RuleKeywordsScreen(
              title: 'Groceries', catalogKey: 'groceries'),
          'calendar' => const CalendarScreen(),
          'tags' => const TagsScreen(),
          'data' => const DataManagementScreen(),
          'newCategory' => const EnvelopeEditorScreen(sortOrder: 0),
          'newCategoryFilled' => const EnvelopeEditorScreen(
              sortOrder: 0,
              previewName: 'Kahvaltı',
              previewEmoji: '🥐',
              previewColorIndex: 1,
              previewSection: 'everyday'),
          'sectionPicker' => const EnvelopeEditorScreen(
              sortOrder: 0, previewName: 'Kahvaltı', autoOpenSection: true),
          _ => kPreviewAnalytics
              ? StatsScreen(initialMonthOffset: kPreviewAnalyticsOffset)
              : null,
        },
      },
    };
    if (preview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => preview)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ana ekran widget'ını güncel tut (App Group yoksa güvenle no-op).
    ref.watch(widgetSyncProvider);
    // Vadesi gelen tekrarlayan işlemleri açılışta işle (yetişme).
    ref.watch(recurringMaterializerProvider);
    // Eski varsayılan cüzdan adını ("Cüzdanım") yeni varsayılana taşı.
    ref.watch(spaceNameMigrationProvider);
    return const HomeScreen();
  }
}
