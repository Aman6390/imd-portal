import 'package:home_widget/home_widget.dart';

/// Helper service to update the native Android 2x2 home screen widget.
class WidgetService {
  static const String appWidgetProviderName = 'ImdAppWidgetProvider';

  /// Sends updated C-Off balance and sync timestamp to the native Android widget
  static Future<void> update({
    required String coffBalance,
    required String lastSynced,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('coff_balance', coffBalance);
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
