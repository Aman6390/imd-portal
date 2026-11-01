import 'package:flutter/material.dart';
import 'glass_container.dart';

/// iOS 27 Liquid Glass 3-Column Bento Grid for Leave Balances.
/// Features frosted glassmorphic card containers, translucent liquid wave gradients,
/// specular edge highlights, and spatial glowing numerals.
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
        'CASUAL',
        const Color(0xFF00C7FF), // Electric Liquid Cyan
      ),
      (
        'Restricted Holiday (RH)',
        'Restricted',
        'RESTRICTED',
        const Color(0xFFA855F7), // Spatial Liquid Violet
      ),
      (
        'Compensatory Off (C-Off)',
        'Comp. Off',
        'COMP-OFF',
        const Color(0xFFFF9F0A), // Radiant Amber Liquid
      ),
    ];

    return GlassContainer(
      borderRadius: 22,
      blur: 20,
      padding: const EdgeInsets.all(8),
      borderOpacity: 0.16,
      surfaceOpacity: 0.06,
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

          // For C-Off, if high balance or approaching expiry, escalate to red
          Color effectiveColor = accentColor;
          if (shortCode == 'COMP-OFF' && value > 15) {
            effectiveColor = const Color(0xFFFF3B30);
          }

          final isLast = index == leaveTypes.length - 1;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.05),
                          effectiveColor.withOpacity(0.12),
                          effectiveColor.withOpacity(0.32),
                        ]
                      : [
                          Colors.white.withOpacity(0.7),
                          effectiveColor.withOpacity(0.08),
                          effectiveColor.withOpacity(0.20),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? effectiveColor.withOpacity(0.38)
                      : effectiveColor.withOpacity(0.25),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveColor.withOpacity(isDark ? 0.15 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Liquid Glass Header Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: effectiveColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: effectiveColor.withOpacity(0.35),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      shortCode,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : effectiveColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Display Count with Specular Spatial Glow
                  Text(
                    valueStr,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      shadows: isDark
                          ? [
                              Shadow(
                                color: effectiveColor.withOpacity(0.55),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle / Expiring Status Pill
                  if (shortCode == 'COMP-OFF' && value > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Expiring Soon',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9F0A),
                        ),
                      ),
                    )
                  else
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFD1D1D6) : const Color(0xFF48484A),
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
