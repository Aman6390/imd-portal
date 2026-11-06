import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/telemetry_service.dart';
import 'glass_container.dart';

/// Modal bottom sheet displaying live anonymous staff analytics & app popularity metrics.
/// Exclusively accessible when Master Key 6390 is unlocked.
class TelemetryDashboardModal extends StatefulWidget {
  const TelemetryDashboardModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TelemetryDashboardModal(),
    );
  }

  @override
  State<TelemetryDashboardModal> createState() => _TelemetryDashboardModalState();
}

class _TelemetryDashboardModalState extends State<TelemetryDashboardModal> {
  late Future<TelemetryReport> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = TelemetryService.fetchMasterAnalytics();
  }

  void _refresh() {
    setState(() {
      _analyticsFuture = TelemetryService.fetchMasterAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C7FF).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Color(0xFF00C7FF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Staff Pulse & App Popularity',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Aman6390/metnet-user-data • Live Analytics',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Analytics',
                  onPressed: _refresh,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: FutureBuilder<TelemetryReport>(
              future: _analyticsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text(
                          'Aggregating live staff telemetry...',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          const Text(
                            'Failed to Load Analytics',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final report = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  children: [
                    // 1. Bento 3-Stat Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildBentoCard(
                            label: 'TOTAL INSTALLS',
                            value: '${report.totalInstalls}',
                            subtitle: 'Unique Devices',
                            color: const Color(0xFF00C7FF),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBentoCard(
                            label: 'ACTIVE TODAY',
                            value: '${report.activeToday}',
                            subtitle: 'Past 24 Hours',
                            color: const Color(0xFF34C759),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBentoCard(
                            label: 'ACTIVE 7 DAYS',
                            value: '${report.activePast7Days}',
                            subtitle: 'Weekly Users',
                            color: const Color(0xFFA855F7),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. Version Distribution Card
                    GlassContainer(
                      borderRadius: 20,
                      blur: 16,
                      padding: const EdgeInsets.all(16),
                      borderOpacity: 0.14,
                      surfaceOpacity: 0.05,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.system_update_alt_rounded, size: 17, color: Color(0xFF00C7FF)),
                              const SizedBox(width: 8),
                              const Text(
                                'App Version Distribution',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Text(
                                '${report.totalInstalls} devices',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (report.versionDistribution.isEmpty)
                            const Text(
                              'No active device pings recorded yet.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          else
                            ...report.versionDistribution.entries.map((entry) {
                              final ver = entry.key;
                              final count = entry.value;
                              final ratio = report.totalInstalls > 0 ? count / report.totalInstalls : 0.0;
                              final percent = (ratio * 100).toStringAsFixed(0);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'v$ver',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '$count devices ($percent%)',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 6,
                                        backgroundColor: isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.black.withOpacity(0.06),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C7FF)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. Feature Telemetry Card
                    GlassContainer(
                      borderRadius: 20,
                      blur: 16,
                      padding: const EdgeInsets.all(16),
                      borderOpacity: 0.14,
                      surfaceOpacity: 0.05,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 17, color: Color(0xFFFF9F0A)),
                              SizedBox(width: 8),
                              Text(
                                'Feature Adoption & Settings',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.withOpacity(0.25)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Weather Banner: ON',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${report.weatherBannerEnabledCount} users',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.25)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Weather Banner: OFF',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${report.weatherBannerDisabledCount} users',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 4. Recent Anonymous Pings
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Recent Anonymous Heartbeats',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey),
                      ),
                    ),
                    if (report.recentPings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No telemetry issues created yet. When devices open the app, pings will show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    else
                      ...report.recentPings.map((ping) {
                        final timeAgo = _formatTimeAgo(ping.timestamp);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ping.deviceId,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C7FF).withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${ping.version}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00C7FF)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeAgo,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCard({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }
}
