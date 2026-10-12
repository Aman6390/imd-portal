import 'package:flutter/material.dart';

class LeaveCardsRow extends StatelessWidget {
  final Map<String, String> leavesData;

  const LeaveCardsRow({Key? key, required this.leavesData}) : super(key: key);

  Color _getColor(String key, int value) {
    if (key == 'Compensatory Off (C-Off)') {
      return value > 15 ? Colors.deepOrangeAccent : Colors.greenAccent.shade400;
    } else {
      return value > 5 ? Colors.lightBlueAccent : Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveTypes = [
      ('Casual Leave (CL)', 'Casual Leave'),
      ('Restricted Holiday (RH)', 'Restricted Holiday'),
      ('Compensatory Off (C-Off)', 'Compensatory Off'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: leaveTypes.map((item) {
          final key = item.$1;
          final displayName = item.$2;
          final valueStr = leavesData[key] ?? '0';
          final value = int.tryParse(valueStr) ?? 0;
          final metricColor = _getColor(key, value);

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: metricColor.withOpacity(0.3),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      valueStr,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: metricColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'days',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
