import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../features/envelopes/budget_repository.dart';
import '../features/insights/analytics.dart';
import '../features/workdays/work_days_repository.dart';
import 'formatters.dart';
import 'l10n.dart';

/// Ana ekran widget'ı köprüsü. Bugünkü kazanç / cepte kalan / kazanç serisini
/// widget'a yazar. App Group ve native target Xcode'da kurulmadan da güvenli:
/// tüm çağrılar try/catch içinde, hata uygulamayı etkilemez.
class BudgyWidget {
  /// Xcode'da oluşturulacak App Group ile BİREBİR aynı olmalı.
  static const appGroupId = 'group.co.ggtech.kopilkaApp';

  /// iOS Widget Extension target adı (Xcode'da bu isimle oluştur).
  static const iOSWidgetName = 'BudgyWidget';

  /// Android AppWidgetProvider sınıf adı.
  static const androidWidgetName = 'BudgyWidgetProvider';

  static Future<void> push({
    required double todayEarnings,
    required double moneyLeft,
    required int streak,
    required String todayLabel,
    required String moneyLeftLabel,
  }) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>(
          'today', formatMoney(todayEarnings));
      await HomeWidget.saveWidgetData<String>(
          'moneyLeft', formatMoney(moneyLeft));
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.saveWidgetData<String>('todayLabel', todayLabel);
      await HomeWidget.saveWidgetData<String>(
          'moneyLeftLabel', moneyLeftLabel);
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        name: androidWidgetName,
      );
    } catch (_) {
      // Widget henüz kurulmamış / desteklenmiyor — sessizce geç.
    }
  }
}

/// Widget'ı ilgili veriler değiştikçe güncel tutar. Kök ekranda bir kez
/// izlenmesi yeterli (root_screen).
final widgetSyncProvider = Provider<void>((ref) {
  final inEnvelopes = ref.watch(totalBalanceProvider);
  final days = ref.watch(unallocatedWorkDaysProvider).value ?? const [];
  final freeInc = ref.watch(unallocatedFreeIncomeProvider).value ?? const [];
  final freeExp = ref.watch(unallocatedFreeExpensesProvider).value ?? const [];
  final earned = ref.watch(allWorkDaysProvider).value ?? const [];
  final streak = ref.watch(earningStreakProvider);
  final str = ref.watch(strProvider);
  // Para birimi sembolü değişince de yeniden yazsın.
  ref.watch(currencySymbolProvider);

  final toDistribute = days.fold<double>(0, (a, d) => a + (d.amount ?? 0)) +
      freeInc.fold<double>(0, (a, e) => a + e.amount);
  final moneyLeft = inEnvelopes +
      toDistribute -
      freeExp.fold<double>(0, (a, e) => a + e.amount);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayEarnings = earned
      .where((d) =>
          DateTime(d.date.year, d.date.month, d.date.day) == today)
      .fold<double>(0, (a, d) => a + (d.amount ?? 0));

  BudgyWidget.push(
    todayEarnings: todayEarnings,
    moneyLeft: moneyLeft,
    streak: streak,
    todayLabel: str.today,
    moneyLeftLabel: str.moneyLeft,
  );
});
