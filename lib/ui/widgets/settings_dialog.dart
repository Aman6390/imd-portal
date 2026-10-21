import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../models/dashboard_data.dart';
import '../../services/circular_service.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final VoidCallback? onToggleTheme;
  final bool? isDarkMode;

  const SettingsDialog({
    Key? key,
    required this.onSaved,
    this.onToggleTheme,
    this.isDarkMode,
  }) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newVipController = TextEditingController();
  final _newJunkController = TextEditingController();

  List<String> _vipKeywords = [];
  List<String> _junkKeywords = [];

  bool _obscurePassword = true;
  bool _isLoading = true;
  bool _isCheckingUpdate = false;
  bool _isDiagnosticsUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _newVipController.dispose();
    _newJunkController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    final (user, pass) = await StorageService.loadCredentials();
    final vip = await StorageService.loadVipKeywords();
    final junk = await StorageService.loadJunkKeywords();
    final diagUnlocked = await StorageService.isDiagnosticsUnlocked();

    if (mounted) {
      setState(() {
        _usernameController.text = user;
        _passwordController.text = pass;
        _vipKeywords = List<String>.from(vip);
        _junkKeywords = List<String>.from(junk);
        _isDiagnosticsUnlocked = diagUnlocked;
        _isLoading = false;
      });
    }
  }

  void _showUnlockKeyPrompt() {
    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              'Enter the 4-digit key to unlock troubleshooting and diagnostic tools.',
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                if (mounted) {
                  setState(() {
                    _isDiagnosticsUnlocked = true;
                  });
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Developer & Troubleshooting Tools Unlocked!'),
                    backgroundColor: Colors.green,
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
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  void _addVipKeyword() {
    final word = _newVipController.text.trim().toLowerCase();
    if (word.isNotEmpty && !_vipKeywords.contains(word)) {
      setState(() {
        _vipKeywords.add(word);
        _newVipController.clear();
      });
    }
  }

  void _addJunkKeyword() {
    final word = _newJunkController.text.trim().toLowerCase();
    if (word.isNotEmpty && !_junkKeywords.contains(word)) {
      setState(() {
        _junkKeywords.add(word);
        _newJunkController.clear();
      });
    }
  }

  void _resetKeywords() {
    setState(() {
      _vipKeywords = List<String>.from(StorageService.defaultVipKeywords);
      _junkKeywords = List<String>.from(StorageService.defaultJunkKeywords);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Keywords reset to factory defaults.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSave() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both username and password.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final successCreds = await StorageService.saveCredentials(user, pass);
    await StorageService.saveVipKeywords(_vipKeywords);
    await StorageService.saveJunkKeywords(_junkKeywords);

    if (!mounted) return;

    if (successCreds) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save credentials.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, size: 22),
                SizedBox(width: 8),
                Text('Settings & Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.key, size: 16), text: 'Account'),
                Tab(icon: Icon(Icons.star, size: 16), text: 'VIP Filter'),
                Tab(icon: Icon(Icons.block, size: 16), text: 'Junk Filter'),
                Tab(icon: Icon(Icons.info, size: 16), text: 'About & Updates'),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: TabBarView(
            children: [
              // TAB 1: Login Credentials
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Enter your MetNet intranet credentials. Stored securely on your device for live sync.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.password_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // TAB 2: VIP Keywords
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Circulars containing these words in title or scanned PDF (English/हिन्दी) are alerted.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newVipController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. transfer, पदोन्नति',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addVipKeyword(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _addVipKeyword,
                        tooltip: 'Add VIP Keyword',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _vipKeywords.map((kw) {
                          return Chip(
                            label: Text(kw, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _vipKeywords.remove(kw);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Reset Defaults', style: TextStyle(fontSize: 12)),
                      onPressed: _resetKeywords,
                    ),
                  ),
                ],
              ),

              // TAB 3: Junk Keywords
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Circulars matching these words in title are discarded automatically.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newJunkController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. driver, canteen',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addJunkKeyword(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _addJunkKeyword,
                        tooltip: 'Add Junk Keyword',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _junkKeywords.map((kw) {
                          return Chip(
                            label: Text(kw, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _junkKeywords.remove(kw);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Reset Defaults', style: TextStyle(fontSize: 12)),
                      onPressed: _resetKeywords,
                    ),
                  ),
                ],
              ),

              // TAB 4: About, Theme & Updates
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Theme Switcher Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.dark_mode_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Switch(
                          value: widget.isDarkMode ?? true,
                          onChanged: (_) {
                            if (widget.onToggleTheme != null) {
                              widget.onToggleTheme!();
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Free Edition Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade600, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volunteer_activism_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Free Edition for Meteorological Staff (v${UpdateService.currentVersion})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // App Updates Section
                    const Text('App Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    const Text(
                      'Check online for new releases, bug fixes, and feature updates directly from the project repository.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: _isCheckingUpdate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_alt, size: 18),
                      label: Text(
                        _isCheckingUpdate
                            ? 'Checking for Updates Online...'
                            : 'Check for Updates / Download Latest APK',
                      ),
                      onPressed: _isCheckingUpdate
                          ? null
                          : () async {
                              setState(() {
                                _isCheckingUpdate = true;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Connecting to GitHub to check for updates...'),
                                    ],
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              try {
                                final update = await UpdateService.checkForUpdate();
                                if (!context.mounted) return;

                                if (update != null && update.hasUpdate) {
                                  UpdateService.showUpdateDialog(context, update);
                                } else if (update != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ You are running the latest version (v${UpdateService.currentVersion})!'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                } else {
                                  // Offline or error fallback: open releases page directly
                                  final uri = Uri.parse('https://github.com/Aman6390/imd-portal/releases');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isCheckingUpdate = false;
                                  });
                                }
                              }
                            },
                    ),

                    const Divider(height: 24),
                    // App Info
                    const Text('About Meteorological Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    const Text(
                      'Meteorological Portal is an automated companion app designed for meteorological staff and employees.\n\n'
                      'Features include automated MetNet login, real-time Casual Leave, RH, and Compensatory Off balance tracking with 6-month expiry forecasting, rolling 30-day circulars, bilingual Devanagari OCR for Hindi orders, deduplicated offline caching, and Android Home Screen widgets.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text('Developer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      'Designed & Developed by Aman (Aman6390).\n'
                      'Built to simplify daily departmental tracking and streamline intranet access for colleagues.\n'
                      'Version: ${UpdateService.currentVersion} (Release Build)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),

                    // Diagnostic Tools Section (Protected by Key 6390)
                    if (_isDiagnosticsUnlocked) ...[
                      const Divider(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.build_circle_outlined, color: Colors.purpleAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Troubleshooting Tools',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purpleAccent),
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
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('🔒 Diagnostic tools locked.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.network_check_rounded, color: Colors.blueAccent),
                              title: const Text('Check Portal Connection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Ping MetNet server & check RSA encryption availability', style: TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: _testPortalConnection,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.cleaning_services_rounded, color: Colors.amber),
                              title: const Text('Clear Downloaded Documents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Free up storage by clearing locally cached circular PDFs', style: TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: _clearOfflineDocuments,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.document_scanner_rounded, color: Colors.green),
                              title: const Text('Scanned Notice Text Inspector', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Pick a circular to inspect extracted Devanagari/English text & AI summary', style: TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: _showOcrSandbox,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.build_outlined, size: 14, color: Colors.grey),
                          label: const Text(
                            'Diagnostic Tools (Key Required)',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          onPressed: _showUnlockKeyPrompt,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _handleSave,
            child: const Text('Save All'),
          ),
        ],
      ),
    );
  }
}
