import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const SettingsDialog({Key? key, required this.onSaved}) : super(key: key);

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
        content: Text('Keywords reset to original factory defaults.'),
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
          content: Text('Settings & keyword filters successfully saved!'),
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
      length: 3,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, size: 22),
                SizedBox(width: 8),
                Text('Settings & Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.key, size: 18), text: 'Login'),
                Tab(icon: Icon(Icons.star, size: 18), text: 'VIP Filter'),
                Tab(icon: Icon(Icons.block, size: 18), text: 'Junk'),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: TabBarView(
            children: [
              // Tab 1: Login Credentials
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

              // Tab 2: VIP Keywords
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Circulars containing these words (English or हिन्दी) in title or scanned PDF are prioritized.',
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

              // Tab 3: Junk Keywords
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
