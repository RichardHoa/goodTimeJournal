package com.goodtimejournal.good_time_journal_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FinanceWidget4x4Provider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.finance_widget_4x4).apply {
                val totalBalance = widgetData.getString("total_balance", "0.00 k")
                setTextViewText(R.id.widget_balance_text, totalBalance)

                val pendingMoneyIn = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("mixapp://money_in")
                )
                setOnClickPendingIntent(R.id.btn_money_in, pendingMoneyIn)

                val pendingMoneyOut = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("mixapp://money_out")
                )
                setOnClickPendingIntent(R.id.btn_money_out, pendingMoneyOut)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
