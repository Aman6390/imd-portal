import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../services/auth_service.dart';
import '../services/scraper_engine.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'widgets/alert_grid.dart';
import 'widgets/circular_tabs.dart';
import 'widgets/leave_card.dart';
import 'widgets/settings_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const DashboardScreen({
    Key? key,
    required this.onToggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  DashboardData? _data;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isAppUnlocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCachedData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateAppLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_isAuthenticating) {
        setState(() {
          _isAppUnlocked = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isAppUnlocked && !_isAuthenticating) {
        _authenticateAppLaunch();
      }
    }
  }

  Future<void> _authenticateAppLaunch() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    final authenticated = await AuthService.authenticate(
      localizedReason: 'Authenticate with Fingerprint, Face, or PIN to open IMD Portal',
    );
    _isAuthenticating = false;

    if (mounted) {
      setState(() {
        _isAppUnlocked = authenticated;
      });
    }
  }

  Future<void> _loadCachedData() async {
    final cached = await StorageService.loadDashboardData();
    if (mounted) {
      setState(() {
        _data = cached;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;

    final (user, pass) = await StorageService.loadCredentials();
    if (user.isEmpty || pass.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save your credentials in Settings (⚙️) first!'),
          backgroundColor: Colors.orange,
        ),
      );
      _openSettings();
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    final (success, message, freshData) = await ScraperEngine.runScraper(
      username: user,
      password: pass,
    );

    if (mounted) {
      setState(() {
        _isSyncing = false;
        if (success && freshData != null) {
          _data = freshData;
        }
      });

      if (success && freshData != null) {
        await StorageService.saveDashboardData(freshData);
        await WidgetService.updateFromDashboard(freshData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    _isAuthenticating = true;
    final authenticated = await AuthService.authenticate(
      localizedReason: 'Authenticate with Fingerprint, Face, or PIN to access portal credentials',
    );
    _isAuthenticating = false;

    if (!authenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required to change credentials.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(onSaved: () {
        // Automatically sync after saving credentials if no data exists
        if (_data == null) {
          _triggerSync();
        }
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sync_problem_rounded,
                  size: 64,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 18),
                const Text(
                  'No Data Yet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap the sync button below to fetch your leave balances and departmental circulars.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure you have saved your credentials in Settings (⚙️) first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Configure Credentials'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final data = _data!;

    return RefreshIndicator(
      onRefresh: _triggerSync,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.update,
                    size: 15,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Last synced: ${data.lastUpdated}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Leave Balances section
            const Row(
              children: [
                Text(
                  '📅 Leave Balances',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LeaveCardsRow(leavesData: data.leaves),
            const SizedBox(height: 24),

            // C-Off Expiry Alerts section
            const Row(
              children: [
                Text(
                  '⚠️ C-Off Expiry Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AlertGrid(alerts: data.alerts),
            const SizedBox(height: 24),

            // Departmental Circulars section
            const Row(
              children: [
                Text(
                  '📄 Departmental Circulars',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CircularTabs(
              vipCirculars: data.vipCirculars,
              fomoCirculars: data.fomoCirculars,
            ),
            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildLockScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent.shade400, Colors.tealAccent.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 56,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '🌤️ IMD Portal',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'App is locked for your security',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: _authenticateAppLaunch,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Unlock with Biometrics / PIN'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAppUnlocked) {
      return _buildLockScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🌤️ IMD Portal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_data == null ? _buildEmptyState() : _buildDashboard()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSyncing ? null : _triggerSync,
        tooltip: 'Sync Data',
        icon: _isSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.sync),
        label: Text(_isSyncing ? 'Syncing...' : 'Sync Portal'),
      ),
    );
  }
}
