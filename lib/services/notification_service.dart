import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages local push notifications on Android.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'imd_portal_updates';
  static const String channelName = 'IMD Portal Updates';
  static const String channelDescription =
      'Notifications for new departmental circulars and leave balance updates';

  /// Initializes the local notification plugin and configures Android notification channels
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@android:drawable/sym_def_app_icon');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // Create high-importance Android notification channel
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      // Request notification permission for Android 13+
      await androidPlugin.requestNotificationsPermission();
    }
  }

  /// Displays an immediate local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 101,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@android:drawable/sym_def_app_icon',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }
}
