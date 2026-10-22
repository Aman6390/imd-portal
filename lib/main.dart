import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/background_sync_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/ai_circular_service.dart';
import 'ui/dashboard_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Local Notifications & notification tap handlers
  await NotificationService.initialize();
  await NotificationService.checkAppLaunchNotification();

  // Initialize WorkManager background sync (18:00 hrs daily schedule)
  await BackgroundSyncService.initialize();

  // Initialize AI Circular metadata engine
  await AiCircularService.initialize();

  final isDark = await StorageService.loadThemeMode();
  runApp(ImdPortalApp(initialDark: isDark));
}

class ImdPortalApp extends StatefulWidget {
  final bool initialDark;

  const ImdPortalApp({Key? key, required this.initialDark}) : super(key: key);

  @override
  State<ImdPortalApp> createState() => _ImdPortalAppState();
}

class _ImdPortalAppState extends State<ImdPortalApp> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.initialDark;
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
    });
    StorageService.saveThemeMode(_isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Meteorological Portal',
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardTheme(
          color: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
        ),
      ),
      home: DashboardScreen(
        isDarkMode: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
