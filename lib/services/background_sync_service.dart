import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/dashboard_data.dart';
import 'ai_circular_service.dart';
import 'circular_service.dart';
import 'notification_service.dart';
import 'scraper_engine.dart';
import 'storage_service.dart';
import 'update_service.dart';

const String imdPeriodicSyncTask = 'com.imd.portal.periodicSyncTask';
const String imdDailySyncTask = 'com.imd.portal.dailySyncTask';

/// Top-level callback dispatcher required by WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      if (taskName == imdPeriodicSyncTask || taskName == imdDailySyncTask) {
        final now = DateTime.now();

        // Safe Working-Hours Guard (9:00 AM to 7:30 PM, Monday - Saturday):
        // MetNet never issues circulars late at night or on Sundays.
        // Immediately exit in 2ms to conserve 100% battery and avoid unnatural pings!
        if (now.weekday == DateTime.sunday || now.hour < 9 || now.hour >= 20) {
          return Future.value(true);
        }

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
          // 1. Check for new VIP circulars
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

            // Check if any circular has an active deadline / action required
            for (final item in newVipList) {
              final itemMeta = AiCircularService.getMetadata(item.link, item.title);
              if (itemMeta != null && itemMeta.actionRequired) {
                await NotificationService.showDeadlineNotification(
                  title: 'Action Required: ${item.title}',
                  body: 'Official representation / objection window active. Tap to view notice.',
                  id: 105,
                );
                break;
              }
            }
          }

          // 2. Check for leave balance updates
          if (previousData != null) {
            final bool clChanged = previousData.clBalance != freshData.clBalance;
            final bool rhChanged = previousData.rhBalance != freshData.rhBalance;
            final bool coffChanged = previousData.coffBalance != freshData.coffBalance;

            if (clChanged || rhChanged || coffChanged) {
              await NotificationService.showLeaveBalanceNotification(
                cl: freshData.clBalance,
                rh: freshData.rhBalance,
                coff: freshData.coffBalance,
                id: 103,
              );
            }
          }

          // 3. Check for expiring C-Offs in freshData.alerts
          if (freshData.alerts.isNotEmpty) {
            final urgentAlert = freshData.alerts.first;
            await NotificationService.showLapsingAlertNotification(
              message: urgentAlert.message,
              id: 104,
            );
          }

          // 4. Start-of-the-Month Reminder (Day 1, 2, or 3 of any month)
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

          // Save fresh data to local storage
          await StorageService.saveDashboardData(freshData);
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
  /// Initializes Workmanager and registers the periodic background sync
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await schedulePeriodicSync();
  }

  /// Schedules gentle periodic background sync every 90 minutes (1.5 hours) with ExistingWorkPolicy.keep
  /// so opening the app never delays or pushes back the background notification timer!
  static Future<void> schedulePeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      imdPeriodicSyncTask,
      imdPeriodicSyncTask,
      frequency: const Duration(minutes: 90),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }
}
