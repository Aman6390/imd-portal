import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../models/dashboard_data.dart';
import 'ai_circular_service.dart';
import 'circular_service.dart';
import 'notification_service.dart';
import 'scraper_engine.dart';
import 'storage_service.dart';
import 'update_service.dart';
import 'widget_service.dart';

const String imdDailySyncTask = 'com.imd.portal.dailySyncTask';

/// Top-level callback dispatcher required by WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      if (taskName == imdDailySyncTask) {
        final (username, password) = await StorageService.loadCredentials();
        if (username.isEmpty || password.isEmpty) {
          return Future.value(true);
        }

        // Fetch previous cached data for comparison
        final previousData = await StorageService.loadDashboardData();

        // Perform scrape
        final (success, _, freshData) = await ScraperEngine.runScraper(
          username: username,
          password: password,
        );

        if (success && freshData != null) {
          // Check for differences in leave balances or circulars
          bool hasChanges = false;

          if (previousData == null) {
            hasChanges = true;
          } else {
            // Check leave balance changes
            if (previousData.clBalance != freshData.clBalance ||
                previousData.rhBalance != freshData.rhBalance ||
                previousData.coffBalance != freshData.coffBalance) {
              hasChanges = true;
            }

            // Check for new VIP circulars
            final prevVipTitles = previousData.vipCirculars.map((c) => c.title).toSet();
            final newVipList = freshData.vipCirculars
                .where((c) => !prevVipTitles.contains(c.title))
                .toList();
            if (newVipList.isNotEmpty) {
              hasChanges = true;
            }
          }

          // Trigger local notification with smart AI summary digest
          if (hasChanges) {
            final prevVipTitles = previousData?.vipCirculars.map((c) => c.title).toSet() ?? {};
            final newVipList = freshData.vipCirculars
                .where((c) => !prevVipTitles.contains(c.title))
                .toList();

            if (newVipList.isNotEmpty) {
              final firstItem = newVipList.first;
              final aiMeta = AiCircularService.getMetadata(firstItem.link, firstItem.title);
              final briefSummary = (aiMeta != null && aiMeta.summaryEn.isNotEmpty)
                  ? aiMeta.summaryEn
                  : firstItem.title;
              final cadre = (aiMeta != null && aiMeta.targetCadre.isNotEmpty && aiMeta.targetCadre != 'General / All')
                  ? aiMeta.targetCadre
                  : 'For You';
              final count = newVipList.length;

              await NotificationService.showNotification(
                id: 101,
                title: count == 1
                    ? '🤖 New Notice: $cadre'
                    : '🤖 $count New Notices For You',
                body: count == 1
                    ? briefSummary
                    : '$briefSummary (+${count - 1} more)',
              );
            } else {
              await NotificationService.showNotification(
                id: 101,
                title: 'Meteorological Portal: Data Updated',
                body: 'Leave balances and notices have been refreshed from MetNet.',
              );
            }
          }

          // Check for Start-of-the-Month Reminder (Day 1, 2, or 3 of any month)
          final now = DateTime.now();
          if (now.day <= 3) {
            final rhCount = int.tryParse(freshData.rhBalance) ?? 0;
            final coffCount = int.tryParse(freshData.coffBalance) ?? 0;
            if (rhCount > 0 || coffCount > 0) {
              await NotificationService.showNotification(
                id: 102,
                title: '📅 Monthly Leave Reminder',
                body: 'You have $coffCount C-Off(s) and $rhCount RH remaining. Plan your leaves before they lapse!',
              );
            }
          }

          // Save new data to storage
          await StorageService.saveDashboardData(freshData);

          // Update Home Screen Widget
          await WidgetService.updateFromDashboard(freshData);
        }

        // Check for app updates in background and notify if a new version is available
        try {
          await UpdateService.checkForUpdate();
        } catch (_) {}

        // 30-Day auto-purge maintenance for downloaded circular files
        try {
          await CircularService.purgeFilesOlderThan30Days();
        } catch (_) {}
      }
      return Future.value(true);
    } catch (_) {
      return Future.value(false);
    }
  });
}

class BackgroundSyncService {
  /// Initializes Workmanager and registers the daily 18:00 sync task
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await scheduleDailySyncAt18();
  }

  /// Calculates initial delay to 18:00 (6:00 PM) and schedules a 24-hour periodic work
  static Future<void> scheduleDailySyncAt18() async {
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, 18, 0, 0);

    // If 18:00 has already passed today, target 18:00 tomorrow
    if (now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }

    final initialDelay = target.difference(now);

    await Workmanager().registerPeriodicTask(
      imdDailySyncTask,
      imdDailySyncTask,
      frequency: const Duration(hours: 24),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
