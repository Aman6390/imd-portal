import 'package:flutter/material.dart';

/// Apple Design System 3-Column Bento Grid for Leave Balances.
/// Replaces the fragmented horizontal scroll row with a unified, optically balanced
/// segmented card spanning 100% of the viewport with Apple HIG typography and semantic accents.
class LeaveCardsRow extends StatelessWidget {
  final Map<String, String> leavesData;

  const LeaveCardsRow({Key? key, required this.leavesData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final leaveTypes = [
      (
        'Casual Leave (CL)',
        'Casual Leave',
        'CL',
        const Color(0xFF007AFF), // Apple SystemBlue
      ),
      (
        'Restricted Holiday (RH)',
        'Restricted',
        'RH',
        const Color(0xFF5856D6), // Apple SystemIndigo
      ),
      (
        'Compensatory Off (C-Off)',
        'Comp. Off',
        'C-Off',
        const Color(0xFFFF9500), // Apple SystemOrange
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: leaveTypes.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final key = item.$1;
          final displayName = item.$2;
          final shortCode = item.$3;
          final accentColor = item.$4;

          final valueStr = leavesData[key] ?? '0';
          final value = int.tryParse(valueStr) ?? 0;

          // For C-Off, if high balance or approaching expiry, escalate to Apple SystemRed
          Color effectiveColor = accentColor;
          if (shortCode == 'C-Off' && value > 15) {
            effectiveColor = const Color(0xFFFF3B30); // Apple SystemRed
          }

          final isLast = index == leaveTypes.length - 1;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 4),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B2232).withOpacity(0.5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header badge pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: effectiveColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shortCode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: effectiveColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Display count
                  Text(
                    valueStr,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Subtitle label
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
