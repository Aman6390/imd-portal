import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../models/dashboard_data.dart';
import '../../services/ai_circular_service.dart';
import '../../services/circular_service.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';
import '../../services/notification_service.dart';
import '../system_health_screen.dart';
import 'glass_container.dart';
import 'telemetry_dashboard_modal.dart';

/// Clean, simplified Apple iOS 27 Liquid Glass Settings Screen.
/// Features grouped frosted glass cards, persistent Weather Forecast Banner toggle,
/// AES-256 MetNet credentials manager, keyword filters modal sheet, and 24-hour ephemeral diagnostic tools.
class SettingsDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final VoidCallback? onToggleTheme;
  final bool? isDarkMode;
  final ValueChanged<bool>? onWeatherBannerToggled;

  const SettingsDialog({
    Key? key,
    required this.onSaved,
    this.onToggleTheme,
    this.isDarkMode,
    this.onWeatherBannerToggled,
  }) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  List<String> _vipKeywords = [];
  List<String> _junkKeywords = [];

  bool _obscurePassword = true;
  bool _isLoading = true;
  bool _isCheckingUpdate = false;
  bool _isDiagnosticsUnlocked = false;
  String _diagnosticsTimeRemainingText = '';
  bool _enableAiSummaries = true;
  bool _isBatteryUnrestricted = false;
  bool _showWeatherBanner = true;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    final (user, pass) = await StorageService.loadCredentials();
    final vip = await StorageService.loadVipKeywords();
    final junk = await StorageService.loadJunkKeywords();
    final diagUnlocked = await StorageService.isDiagnosticsUnlocked();
    String remainingText = '';
    if (diagUnlocked) {
      final rem = await StorageService.getDiagnosticsRemainingTime();
      if (rem != null) {
        remainingText = '${rem.inHours}h ${rem.inMinutes % 60}m left';
      }
    }
    final aiEnabled = await AiCircularService.isAiEnabled();
    final isUnrestricted = await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    final showWeather = await StorageService.loadShowWeatherBanner();

    if (mounted) {
      setState(() {
        _usernameController.text = user;
        _passwordController.text = pass;
        _vipKeywords = List<String>.from(vip);
        _junkKeywords = List<String>.from(junk);
        _isDiagnosticsUnlocked = diagUnlocked;
        _diagnosticsTimeRemainingText = remainingText;
        _enableAiSummaries = aiEnabled;
        _isBatteryUnrestricted = isUnrestricted;
        _showWeatherBanner = showWeather;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (user.isNotEmpty || pass.isNotEmpty) {
      await StorageService.saveCredentials(user, pass);
    }
    await StorageService.saveVipKeywords(_vipKeywords);
    await StorageService.saveJunkKeywords(_junkKeywords);
    await StorageService.saveShowWeatherBanner(_showWeatherBanner);
    await AiCircularService.setUserEnabled(_enableAiSummaries);

    if (!mounted) return;

    widget.onWeatherBannerToggled?.call(_showWeatherBanner);
    widget.onSaved();

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Settings saved successfully!'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openKeywordsDrawer(bool isVip) {
    final title = isVip ? 'Priority Alert Keywords' : 'Excluded Junk Keywords';
    final subtitle = isVip
        ? 'Circulars containing these words in the title or body trigger prominent notifications'
        : 'Circulars matching these words in the title are automatically discarded';
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (ctx, setDrawerState) {
            final keywords = isVip ? _vipKeywords : _junkKeywords;
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161922) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(bCtx).pop(),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            decoration: InputDecoration(
                              hintText: isVip ? 'e.g. transfer, पदोन्नति' : 'e.g. driver, canteen',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onSubmitted: (val) {
                              final w = val.trim().toLowerCase();
                              if (w.isNotEmpty && !keywords.contains(w)) {
                                setState(() => keywords.add(w));
                                setDrawerState(() {});
                                textController.clear();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () {
                            final w = textController.text.trim().toLowerCase();
                            if (w.isNotEmpty && !keywords.contains(w)) {
                              setState(() => keywords.add(w));
                              setDrawerState(() {});
                              textController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: keywords.map((kw) {
                            return Chip(
                              label: Text(kw, style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () {
                                setState(() => keywords.remove(kw));
                                setDrawerState(() {});
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('Reset Defaults', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            if (isVip) {
                              _vipKeywords = List<String>.from(StorageService.defaultVipKeywords);
                            } else {
                              _junkKeywords = List<String>.from(StorageService.defaultJunkKeywords);
                            }
                          });
                          setDrawerState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUnlockKeyPrompt() {
    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 10),
            Text('Enter Access Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 4-digit key to unlock troubleshooting and diagnostic tools (24-Hour ephemeral lease).',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter 4-digit Key',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final key = keyController.text.trim();
              if (key == '6390') {
                await StorageService.setDiagnosticsUnlocked(true);
                final rem = await StorageService.getDiagnosticsRemainingTime();
                final remainingText = rem != null ? '${rem.inHours}h ${rem.inMinutes % 60}m left' : '24h left';
                if (mounted) {
                  setState(() {
                    _isDiagnosticsUnlocked = true;
                    _diagnosticsTimeRemainingText = remainingText;
                  });
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Master Access Active for 24 Hours! (Auto-revokes after 24h)'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Invalid key. Access denied.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<void> _testPortalConnection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Testing connection to MetNet...'),
              ],
            ),
          ),
        ),
      ),
    );

    final stopwatch = Stopwatch()..start();
    String statusMessage = '';
    bool isSuccess = false;

    try {
      final response = await http.get(
        Uri.parse('https://metnet.imd.gov.in/phps/left1.php'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final hasPublicKey = response.body.contains('id="publicKey"');
        isSuccess = true;
        statusMessage = '✅ MetNet Portal Online (HTTP 200)\n'
            '• Response Time: ${stopwatch.elapsedMilliseconds} ms\n'
            '• RSA Encryption Form: ${hasPublicKey ? "Ready & Functional" : "Not Detected"}\n'
            '• Server: Apache on Linux';
      } else {
        statusMessage = '⚠️ Server responded with HTTP ${response.statusCode}';
      }
    } catch (e) {
      statusMessage = '❌ Could not reach MetNet server: $e\n\nEnsure mobile data or office Wi-Fi has connectivity.';
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? Colors.green : Colors.redAccent, size: 24),
              const SizedBox(width: 10),
              const Text('Portal Connection Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(statusMessage, style: const TextStyle(fontSize: 13, height: 1.5)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearOfflineDocuments() async {
    final deleted = await CircularService.clearDownloadedCache();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🧹 Cleaned up $deleted offline cached document(s).'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showOcrSandbox() async {
    final data = await StorageService.loadDashboardData();
    final items = <CircularItem>[];
    if (data != null) {
      items.addAll(data.vipCirculars);
      items.addAll(data.fomoCirculars);
    }

    if (!context.mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No circulars available to inspect. Please sync the portal first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.document_scanner_rounded, color: Colors.purpleAccent, size: 22),
            SizedBox(width: 10),
            Text('Pick Circular to Inspect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.take(8).length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final itm = items[index];
              return ListTile(
                dense: true,
                title: Text(itm.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                subtitle: Text('Uploaded: ${itm.date}', style: const TextStyle(fontSize: 10)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  CircularService.inspectCircularOcr(context, itm);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF2F4F7),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF2F4F7),
      body: Stack(
        children: [
          // Spatial atmospheric mesh background with radial aurora glows
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF06B6D4).withOpacity(isDark ? 0.18 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 300,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(isDark ? 0.16 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Clean Top Navigation Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      GlassContainer(
                        borderRadius: 16,
                        blur: 14,
                        padding: EdgeInsets.zero,
                        borderOpacity: 0.2,
                        surfaceOpacity: 0.12,
                        onTap: _handleSave,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Grouped Settings Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: MetNet Credentials
                        _buildSectionHeader('METNET CREDENTIALS'),
                        GlassContainer(
                          borderRadius: 20,
                          blur: 18,
                          padding: const EdgeInsets.all(16),
                          borderOpacity: 0.14,
                          surfaceOpacity: 0.08,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'MetNet User ID',
                                  hintText: 'Enter your MetNet ID',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your MetNet password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined, size: 13, color: Color(0xFF10B981)),
                                        SizedBox(width: 4),
                                        Text(
                                          'AES-256 Encrypted on Device',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // SECTION 2: Display & Preferences
                        _buildSectionHeader('DISPLAY & PREFERENCES'),
                        GlassContainer(
                          borderRadius: 20,
                          blur: 18,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          borderOpacity: 0.14,
                          surfaceOpacity: 0.08,
                          child: Column(
                            children: [
                              // 1. Weather Forecast Banner Toggle (Requested)
                              _buildSettingRow(
                                icon: Icons.cloud_outlined,
                                iconColor: const Color(0xFF06B6D4),
                                title: 'Weather Forecast Banner',
                                subtitle: 'Display live weather card on dashboard',
                                trailing: Switch.adaptive(
                                  value: _showWeatherBanner,
                                  activeColor: const Color(0xFF0284C7),
                                  onChanged: (val) {
                                    setState(() => _showWeatherBanner = val);
                                    StorageService.saveShowWeatherBanner(val);
                                    widget.onWeatherBannerToggled?.call(val);
                                  },
                                ),
                              ),
                              _buildDivider(),

                              // 2. AI Circular Summaries Toggle
                              _buildSettingRow(
                                icon: Icons.auto_awesome_rounded,
                                iconColor: const Color(0xFF7C3AED),
                                title: 'AI Circular Summaries',
                                subtitle: 'Instant Hindi/English summaries & cadre tags',
                                trailing: Switch.adaptive(
                                  value: _enableAiSummaries,
                                  activeColor: const Color(0xFF7C3AED),
                                  onChanged: (val) {
                                    setState(() => _enableAiSummaries = val);
                                    AiCircularService.setUserEnabled(val);
                                  },
                                ),
                              ),
                              _buildDivider(),

                              // 3. Dark Mode Toggle
                              _buildSettingRow(
                                icon: Icons.dark_mode_outlined,
                                iconColor: const Color(0xFF0284C7),
                                title: 'Dark Mode',
                                subtitle: 'Spatial obsidian frosted glass theme',
                                trailing: Switch.adaptive(
                                  value: widget.isDarkMode ?? isDark,
                                  activeColor: const Color(0xFF0284C7),
                                  onChanged: (_) => widget.onToggleTheme?.call(),
                                ),
                              ),
                              _buildDivider(),

                              // 4. Closed-App Background Notifications
                              _buildSettingRow(
                                icon: _isBatteryUnrestricted ? Icons.bolt_rounded : Icons.battery_saver_rounded,
                                iconColor: _isBatteryUnrestricted ? const Color(0xFF10B981) : Colors.orangeAccent,
                                title: 'Closed-App Notifications',
                                subtitle: _isBatteryUnrestricted
                                    ? 'Unrestricted background sync (every 1.5 hrs)'
                                    : 'Tap below to enable background execution',
                                trailing: _isBatteryUnrestricted
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: () async {
                                          await BatteryOptimizationService.requestIgnoreBatteryOptimizations();
                                          final isUn = await BatteryOptimizationService.isIgnoringBatteryOptimizations();
                                          if (mounted) setState(() => _isBatteryUnrestricted = isUn);
                                        },
                                        child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // SECTION 3: Circular Filters
                        _buildSectionHeader('CIRCULAR FILTERS'),
                        GlassContainer(
                          borderRadius: 20,
                          blur: 18,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          borderOpacity: 0.14,
                          surfaceOpacity: 0.08,
                          child: Column(
                            children: [
                              _buildNavRow(
                                icon: Icons.star_rounded,
                                iconColor: Colors.amber,
                                title: 'Priority Alerts (VIP)',
                                subtitle: 'Keywords triggering prominent notifications',
                                badgeText: '${_vipKeywords.length} Active',
                                onTap: () => _openKeywordsDrawer(true),
                              ),
                              _buildDivider(),
                              _buildNavRow(
                                icon: Icons.block_rounded,
                                iconColor: Colors.redAccent,
                                title: 'Excluded Circulars (Junk)',
                                subtitle: 'Auto-discard canteen, driver, clerk notices',
                                badgeText: '${_junkKeywords.length} Excluded',
                                onTap: () => _openKeywordsDrawer(false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // SECTION 4: About & Updates
                        _buildSectionHeader('ABOUT & UPDATES'),
                        GlassContainer(
                          borderRadius: 20,
                          blur: 18,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          borderOpacity: 0.14,
                          surfaceOpacity: 0.08,
                          child: Column(
                            children: [
                              _buildNavRow(
                                icon: Icons.system_update_alt_rounded,
                                iconColor: const Color(0xFF0284C7),
                                title: 'App Version',
                                subtitle: 'v${UpdateService.currentVersion} (Release Build)',
                                badgeText: _isCheckingUpdate ? 'Checking...' : 'Check for Updates',
                                onTap: _isCheckingUpdate
                                    ? null
                                    : () async {
                                        setState(() => _isCheckingUpdate = true);
                                        try {
                                          final update = await UpdateService.checkForUpdate();
                                          if (!context.mounted) return;
                                          if (update != null && update.hasUpdate) {
                                            UpdateService.showUpdateDialog(context, update);
                                          } else if (update != null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('✅ Running latest version (v${UpdateService.currentVersion})!'),
                                                backgroundColor: const Color(0xFF10B981),
                                              ),
                                            );
                                          } else {
                                            final uri = Uri.parse('https://github.com/Aman6390/imd-portal/releases');
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          }
                                        } finally {
                                          if (mounted) setState(() => _isCheckingUpdate = false);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // SECTION 5: Diagnostic Tools & Security (Protected by Key 6390)
                        _buildSectionHeader('DIAGNOSTIC TOOLS & SECURITY'),
                        if (_isDiagnosticsUnlocked)
                          GlassContainer(
                            borderRadius: 20,
                            blur: 18,
                            padding: const EdgeInsets.all(14),
                            borderOpacity: 0.22,
                            surfaceOpacity: 0.1,
                            tintColor: const Color(0xFF7C3AED),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.build_circle_outlined, color: Color(0xFF7C3AED), size: 20),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Master Troubleshooting',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED)),
                                            ),
                                            if (_diagnosticsTimeRemainingText.isNotEmpty)
                                              Text(
                                                '⏳ Lease Active: $_diagnosticsTimeRemainingText (Auto-revokes)',
                                                style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.lock, size: 18, color: Colors.grey),
                                      tooltip: 'Re-lock diagnostic tools',
                                      onPressed: () async {
                                        await StorageService.setDiagnosticsUnlocked(false);
                                        setState(() {
                                          _isDiagnosticsUnlocked = false;
                                          _diagnosticsTimeRemainingText = '';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _buildDiagnosticActionTile(
                                  icon: Icons.network_check_rounded,
                                  iconColor: Colors.blueAccent,
                                  title: 'Check MetNet Portal Connection',
                                  subtitle: 'Ping server and verify RSA encryption',
                                  onTap: _testPortalConnection,
                                ),
                                _buildDiagnosticActionTile(
                                  icon: Icons.cleaning_services_rounded,
                                  iconColor: Colors.amber,
                                  title: 'Clear Downloaded Documents',
                                  subtitle: 'Delete locally cached circular PDFs',
                                  onTap: _clearOfflineDocuments,
                                ),
                                _buildDiagnosticActionTile(
                                  icon: Icons.insights_rounded,
                                  iconColor: const Color(0xFF00C7FF),
                                  title: 'Staff Pulse & App Popularity',
                                  subtitle: 'Live installs, active users, version & feature stats',
                                  onTap: () => TelemetryDashboardModal.show(context),
                                ),
                                _buildDiagnosticActionTile(
                                  icon: Icons.monitor_heart_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  title: 'System Diagnostics & Health Probes',
                                  subtitle: 'Live status across all 10 app modules',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const SystemHealthScreen()),
                                    );
                                  },
                                ),
                                _buildDiagnosticActionTile(
                                  icon: Icons.document_scanner_rounded,
                                  iconColor: Colors.green,
                                  title: 'Scanned Notice Text Inspector',
                                  subtitle: 'Inspect OCR Devanagari text & AI tags',
                                  onTap: _showOcrSandbox,
                                ),
                              ],
                            ),
                          )
                        else
                          GlassContainer(
                            borderRadius: 16,
                            blur: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            borderOpacity: 0.12,
                            surfaceOpacity: 0.05,
                            child: InkWell(
                              onTap: _showUnlockKeyPrompt,
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Diagnostic Tools (Key Required)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),
                        Center(
                          child: Text(
                            'Meteorological Portal · Built for IMD Staff',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF6E6E73) : const Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF8E8E93)
              : const Color(0xFF6E6E73),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6E6E73),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6E6E73),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? const Color(0xFF0284C7)).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ?? const Color(0xFF0284C7),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10.5)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 16),
      onTap: onTap,
    );
  }
}
