package co.ggtech.kopilka_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Budgy ana ekran widget'ı (Android).
 *
 * Veriyi Flutter tarafı yazar (lib/core/widget_service.dart → home_widget);
 * burada yalnız okunup gösterilir. Anahtarlar iOS widget'ıyla aynı:
 * today / moneyLeft / streak ve etiketleri — etiketler uygulamanın
 * dilinde geldiği için widget da üç dilli olur.
 *
 * Sınıf adı `widget_service.dart` içindeki [androidWidgetName] ile
 * BİREBİR aynı olmalı, yoksa güncelleme yayını bu alıcıya ulaşmaz.
 */
class BudgyWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.budgy_widget).apply {
                val today = widgetData.getString("today", null) ?: "—"
                val moneyLeft = widgetData.getString("moneyLeft", null) ?: "—"
                val todayLabel = widgetData.getString("todayLabel", null) ?: "Bugün"
                val moneyLeftLabel =
                    widgetData.getString("moneyLeftLabel", null) ?: "Kalan"
                val streak = widgetData.getInt("streak", 0)

                setTextViewText(R.id.widget_today_label, todayLabel.uppercase())
                setTextViewText(R.id.widget_today_value, today)
                setTextViewText(R.id.widget_money_left, "$moneyLeftLabel: $moneyLeft")

                // Seri yalnız devam ediyorken görünür.
                if (streak > 0) {
                    setTextViewText(R.id.widget_streak, "🔥$streak")
                    setViewVisibility(R.id.widget_streak, android.view.View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_streak, android.view.View.GONE)
                }

                // Widget'a dokunulunca uygulamayı aç.
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
