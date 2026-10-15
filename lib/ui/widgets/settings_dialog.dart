import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/license_service.dart';
import '../../services/storage_service.dart';

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
  final _activationKeyController = TextEditingController();
  final _adminPinController = TextEditingController();
  final _colleagueDeviceController = TextEditingController();

  List<String> _vipKeywords = [];
  List<String> _junkKeywords = [];

  bool _obscurePassword = true;
  bool _isLoading = true;

  // License state
  String _deviceId = '';
  int _trialDaysRemaining = 30;
  bool _isActivated = false;
  bool _isOwner = false;
  bool _isAdminUnlocked = false;
  String _generatedKeyForColleague = '';

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
    _activationKeyController.dispose();
    _adminPinController.dispose();
    _colleagueDeviceController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    final (user, pass) = await StorageService.loadCredentials();
    final vip = await StorageService.loadVipKeywords();
    final junk = await StorageService.loadJunkKeywords();
    final devId = await LicenseService.getDeviceId();
    final days = await LicenseService.getRemainingTrialDays();
    final activated = await LicenseService.isActivated();
    final owner = await LicenseService.isOwner();

    if (mounted) {
      setState(() {
        _usernameController.text = user;
        _passwordController.text = pass;
        _vipKeywords = List<String>.from(vip);
        _junkKeywords = List<String>.from(junk);
        _deviceId = devId;
        _trialDaysRemaining = days;
        _isActivated = activated;
        _isOwner = owner;
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

  Future<void> _handleActivation() async {
    final key = _activationKeyController.text.trim();
    if (key.isEmpty) return;

    final (success, message) = await LicenseService.verifyAndActivate(key);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _activationKeyController.clear();
      await _loadAllSettings();
    }
  }

  void _unlockAdminGenerator() {
    final pin = _adminPinController.text.trim();
    if (LicenseService.verifyAdminPin(pin)) {
      setState(() {
        _isAdminUnlocked = true;
      });
      _adminPinController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Incorrect Admin PIN.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _generateKeyForColleague() {
    final colleagueId = _colleagueDeviceController.text.trim().toUpperCase();
    if (colleagueId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter colleague\'s Device ID.')),
      );
      return;
    }

    final key = LicenseService.generateKeyForDevice(colleagueId);
    setState(() {
      _generatedKeyForColleague = key;
    });
    Clipboard.setData(ClipboardData(text: key));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Key copied to clipboard: $key'),
        backgroundColor: Colors.green,
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
      length: 5,
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
                Tab(icon: Icon(Icons.verified_user, size: 16), text: 'License'),
                Tab(icon: Icon(Icons.info, size: 16), text: 'About & Theme'),
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

              // TAB 4: License & Admin Key Generator
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isActivated
                            ? Colors.green.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isActivated ? Colors.green : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isActivated ? Icons.verified : Icons.timelapse,
                            color: _isActivated ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isActivated
                                  ? (_isOwner ? '👑 Owner Mode (Master VIP Active)' : '✨ Pro License (Lifetime Activated)')
                                  : '⏳ 30-Day Beta Trial: $_trialDaysRemaining days left',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isActivated ? Colors.green : Colors.orange,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Device ID Row
                    const Text('Your Unique Device ID:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            _deviceId,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'Copy Device ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _deviceId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Device ID copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Activation Box (for regular or trial users)
                    if (!_isActivated) ...[
                      const Text('Enter Activation Key or Master VIP Key:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _activationKeyController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'PRO-XXXX-XXXX',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _handleActivation,
                            child: const Text('Activate'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // OWNER-ONLY ADMIN GENERATOR
                    if (_isOwner) ...[
                      const Divider(height: 24),
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.amber, size: 20),
                          SizedBox(width: 6),
                          Text('👑 Admin License Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!_isAdminUnlocked) ...[
                        const Text('Enter your 4-digit Admin PIN to open the generator:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _adminPinController,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                  hintText: 'PIN',
                                  counterText: '',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _unlockAdminGenerator,
                              child: const Text('Unlock'),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text('Enter colleague\'s Device ID to generate their key:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _colleagueDeviceController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. IMD-8B4E-29A1',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _generateKeyForColleague,
                              child: const Text('Generate'),
                            ),
                          ],
                        ),
                        if (_generatedKeyForColleague.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Text('Generated Key: ', style: TextStyle(fontSize: 12)),
                                SelectableText(
                                  _generatedKeyForColleague,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),

              // TAB 5: About & Theme
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
                      'Version: 1.2.0 (Release Build)',
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
