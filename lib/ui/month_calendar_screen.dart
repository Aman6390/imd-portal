import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_data.dart';

class MonthCalendarScreen extends StatelessWidget {
  final DateTime month;
  final List<LapsingAlert> allAlerts;

  const MonthCalendarScreen({
    Key? key,
    required this.month,
    required this.allAlerts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(month);
    final monthKey = DateFormat('yyyy-MM').format(month);
    final inputFormat = DateFormat('dd-MM-yyyy');

    // Filter alerts that expire in this specific month, mapped by day of month (int)
    final Map<int, List<LapsingAlert>> dayAlerts = {};
    for (final alert in allAlerts) {
      try {
        final parsedDate = inputFormat.parse(alert.expiryDate);
        if (DateFormat('yyyy-MM').format(parsedDate) == monthKey) {
          dayAlerts.putIfAbsent(parsedDate.day, () => []).add(alert);
        }
      } catch (_) {}
    }

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1 = Monday, 7 = Sunday
    final totalExpiringInMonth = dayAlerts.values.fold(0, (sum, list) => sum + list.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$monthName Expiry',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: totalExpiringInMonth > 0
                      ? [Colors.amber.shade900.withOpacity(0.4), Colors.amber.shade800.withOpacity(0.15)]
                      : [Colors.grey.shade900, Colors.grey.shade800.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: totalExpiringInMonth > 0 ? Colors.amber.shade400 : Colors.grey.shade700,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    totalExpiringInMonth > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: totalExpiringInMonth > 0 ? Colors.amberAccent : Colors.greenAccent,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totalExpiringInMonth > 0
                              ? '$totalExpiringInMonth C-Off${totalExpiringInMonth > 1 ? 's' : ''} Expiring in $monthName'
                              : 'No C-Offs Expiring in $monthName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalExpiringInMonth > 0
                              ? 'Highlighted days indicate exact expiration dates.'
                              : 'Your C-Off balance is safe for this month.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Calendar Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    // Weekday Headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                        return SizedBox(
                          width: 38,
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: day == 'S' ? Colors.orangeAccent : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 20),

                    // Calendar Grid Days
                    _buildCalendarGrid(daysInMonth, firstWeekday, dayAlerts, context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // List of specific expiring dates
            if (dayAlerts.isNotEmpty) ...[
              const Text(
                '📅 Breakdown by Day:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...dayAlerts.entries.map((entry) {
                final day = entry.key;
                final items = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.shade900,
                      foregroundColor: Colors.amberAccent,
                      child: Text('$day', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                      '${items.length} C-Off${items.length > 1 ? 's' : ''} Expiring',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Credited on: ${items.map((i) => i.creditDate).join(', ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${items.first.daysLeft}d left',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(
    int daysInMonth,
    int firstWeekday,
    Map<int, List<LapsingAlert>> dayAlerts,
    BuildContext context,
  ) {
    final List<Widget> dayCells = [];

    // Empty padding cells before the 1st day of the month
    for (int i = 1; i < firstWeekday; i++) {
      dayCells.add(const SizedBox(width: 38, height: 38));
    }

    // Days 1 through daysInMonth
    for (int day = 1; day <= daysInMonth; day++) {
      final expiringHere = dayAlerts[day];
      final count = expiringHere?.length ?? 0;
      final hasAlert = count > 0;

      dayCells.add(
        Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: hasAlert ? Colors.redAccent.withOpacity(0.85) : Colors.transparent,
            shape: BoxShape.circle,
            border: hasAlert
                ? Border.all(color: Colors.amber, width: 2)
                : null,
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: hasAlert ? FontWeight.bold : FontWeight.normal,
                    color: hasAlert ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                if (hasAlert && count > 1)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 6,
      runSpacing: 6,
      children: dayCells,
    );
  }
}
