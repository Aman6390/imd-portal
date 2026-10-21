import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'update_service.dart';

/// Manages local push notifications on Android.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'imd_portal_updates';
  static const String channelName = 'Meteorological Portal Updates';
  static const String channelDescription =
      'Notifications for departmental circulars, leave reminders, and app updates';

  /// Initializes the local notification plugin and configures Android notification channels
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('ic_stat_notification');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          await handleNotificationPayload(payload);
        }
      },
    );

    // Create high-importance Android notification channel with lights and vibration
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
    }
  }

  /// Explicitly requests notification permission on Android 13+ (when UI is mounted)
  static Future<bool> requestPermission() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (_) {}
    return false;
  }

  /// Checks if the app was launched by tapping an Android notification
  static Future<void> checkAppLaunchNotification() async {
    final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600), () {
          handleNotificationPayload(payload);
        });
      }
    }
  }

  /// Handles action payloads when the user taps on a notification
  static Future<void> handleNotificationPayload(String payload) async {
    try {
      if (payload.startsWith('install_apk:')) {
        final apkPath = payload.substring('install_apk:'.length);
        await UpdateService.installDownloadedApk(apkPath);
      } else if (payload.startsWith('download_update:')) {
        final downloadUrl = payload.substring('download_update:'.length);
        UpdateService.startBackgroundDownload(downloadUrl);
      }
    } catch (_) {}
  }

  /// Displays an immediate local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 101,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: 'ic_stat_notification',
      channelShowBadge: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Notification when a new app version is available
  static Future<void> showUpdateAvailableNotification({
    required String version,
    required String downloadUrl,
  }) async {
    await showNotification(
      id: 201,
      title: '🚨 Update Available: v$version',
      body: 'Tap to download and install the latest Meteorological Portal update now.',
      payload: 'download_update:$downloadUrl',
    );
  }

  /// Notification when the APK download has finished and is ready to install
  static Future<void> showUpdateDownloadedNotification({
    required String filePath,
    String? version,
  }) async {
    final verText = version != null ? ' v$version' : '';
    await showNotification(
      id: 202,
      title: '✅ Update Ready to Install$verText',
      body: 'Download complete! Tap here to install the update now.',
      payload: 'install_apk:$filePath',
    );
  }
}
