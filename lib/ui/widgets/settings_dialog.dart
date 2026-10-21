import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

    if (mounted) {
      setState(() {
        _usernameController.text = user;
        _passwordController.text = pass;
        _vipKeywords = List<String>.from(vip);
        _junkKeywords = List<String>.from(junk);
        _isLoading = false;
      });
    }
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
                      child: const Row(
                        children: [
                          Icon(Icons.volunteer_activism_rounded, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Free Edition for all IMD Employees (v1.3.0)',
                              style: TextStyle(
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
                      icon: const Icon(Icons.system_update_alt, size: 18),
                      label: const Text('Check for Updates / Download Latest APK'),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Checking for updates online...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        final update = await UpdateService.checkForUpdate();
                        if (!context.mounted) return;
                        if (update != null && update.hasUpdate) {
                          UpdateService.showUpdateDialog(context, update);
                        } else if (update != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ You are on the latest version (v${UpdateService.currentVersion})!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        } else {
                          // Offline or error fallback: open releases page directly
                          final uri = Uri.parse('https://github.com/Aman6390/imd-portal/releases');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                    ),

                    const Divider(height: 24),
                    // App Info
                    const Text('About IMD Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    const Text(
                      'IMD Portal is an automated companion app designed for employees and staff of the India Meteorological Department (IMD).\n\n'
                      'Features include automated MetNet login, real-time Casual Leave, RH, and Compensatory Off balance tracking with 6-month expiry forecasting, bilingual Devanagari OCR for Hindi circulars, deduplicated offline caching, and Android Home Screen widgets.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text('Developer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    const Text(
                      'Designed & Developed by Aman (Aman6390).\n'
                      'Built to simplify daily departmental tracking and streamline intranet access for IMD colleagues.\n'
                      'Version: 1.3.0 (Release Build)',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
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
