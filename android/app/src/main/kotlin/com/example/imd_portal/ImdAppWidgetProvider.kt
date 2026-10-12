package com.example.imd_portal

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ImdAppWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.imd_app_widget)
                
                val coffBalance = widgetData.getString("coff_balance", "--") ?: "--"
                val lastSynced = widgetData.getString("last_synced", "Never") ?: "Never"

                views.setTextViewText(R.id.appwidget_coff_balance, coffBalance)
                views.setTextViewText(R.id.appwidget_last_synced, "Last Synced: $lastSynced")

                // Open app when user taps the widget
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
