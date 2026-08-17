package com.goodtimejournal.good_time_journal_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FinanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.finance_widget_2x2).apply {
                // Money In PendingIntent via HomeWidgetLaunchIntent
                val pendingMoneyIn = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("mixapp://money_in")
                )
                setOnClickPendingIntent(R.id.btn_money_in, pendingMoneyIn)

                // Money Out PendingIntent via HomeWidgetLaunchIntent
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
