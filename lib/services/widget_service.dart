import 'package:home_widget/home_widget.dart';
import '../models/dashboard_data.dart';

/// Helper service to update the native Android 2x2 home screen widget.
class WidgetService {
  static const String appWidgetProviderName = 'ImdAppWidgetProvider';

  /// Sends updated leave balances, expiry alerts, and sync timestamp to the native Android widget
  static Future<void> updateFromDashboard(DashboardData data) async {
    // Determine the closest expiring C-Off alert
    String alertText = "No active C-Off expiring";
    if (data.alerts.isNotEmpty) {
      // Find the alert with minimum days left
      LapsingAlert? nearestAlert;
      for (final a in data.alerts) {
        if (a.daysLeft > 0) {
          if (nearestAlert == null || a.daysLeft < nearestAlert.daysLeft) {
            nearestAlert = a;
          }
        }
      }

      if (nearestAlert != null) {
        alertText = '⚠️ ${nearestAlert.daysLeft}d left (Exp: ${nearestAlert.expiryDate})';
      }
    }

    await update(
      clBalance: data.clBalance,
      rhBalance: data.rhBalance,
      coffBalance: data.coffBalance,
      expiryAlert: alertText,
      lastSynced: data.lastUpdated,
    );
  }

  /// Sends updated data fields to the native Android widget
  static Future<void> update({
    required String clBalance,
    required String rhBalance,
    required String coffBalance,
    required String expiryAlert,
    required String lastSynced,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('cl_balance', clBalance);
      await HomeWidget.saveWidgetData<String>('rh_balance', rhBalance);
      await HomeWidget.saveWidgetData<String>('coff_balance', coffBalance);
      await HomeWidget.saveWidgetData<String>('expiry_alert', expiryAlert);
      await HomeWidget.saveWidgetData<String>('last_synced', lastSynced);

      await HomeWidget.updateWidget(
        name: appWidgetProviderName,
        androidName: appWidgetProviderName,
      );
    } catch (_) {
      // Gracefully ignore widget update issues on unsupported hosts
    }
  }
}
