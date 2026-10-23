import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_data.dart';
import '../month_calendar_screen.dart';

class AlertGrid extends StatelessWidget {
  final List<LapsingAlert> alerts;

  const AlertGrid({Key? key, required this.alerts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent.shade400),
            const SizedBox(width: 10),
            Text(
              'No active C-Offs expiring soon.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    // Count expiring C-Offs per month (yyyy-MM)
    final monthCounts = <String, int>{};
    final inputFormat = DateFormat('dd-MM-yyyy');

    for (final alert in alerts) {
      try {
        final parsedDate = inputFormat.parse(alert.expiryDate);
        final key = DateFormat('yyyy-MM').format(parsedDate);
        monthCounts[key] = (monthCounts[key] ?? 0) + 1;
      } catch (_) {}
    }

    final now = DateTime.now();
    final List<Widget> monthBoxes = [];

    for (int i = 0; i < 12; i++) {
      final targetMonth = DateTime(now.year, now.month + i, 1);
      final monthKey = DateFormat('yyyy-MM').format(targetMonth);
      final monthLabel = DateFormat('MMM yyyy').format(targetMonth);
      final count = monthCounts[monthKey] ?? 0;

      final hasAlert = count > 0;

      monthBoxes.add(
        _AnimatedMonthBox(
          targetMonth: targetMonth,
          monthLabel: monthLabel,
          count: count,
          hasAlert: hasAlert,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MonthCalendarScreen(
                  month: targetMonth,
                  allAlerts: alerts,
                ),
              ),
            );
          },
        ),
      );
    }

    final totalExpiring = monthCounts.values.fold(0, (sum, val) => sum + val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: monthBoxes),
        ),
        const SizedBox(height: 8),
        Text(
          'Total active C-Offs tracked: $totalExpiring • Tap any month to open calendar view',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// Month box widget with smooth dynamic rotating border glow for active expiring months.
/// Maintains strict 105x105 dimensions with zero layout shift.
class _AnimatedMonthBox extends StatefulWidget {
  final DateTime targetMonth;
  final String monthLabel;
  final int count;
  final bool hasAlert;
  final VoidCallback onTap;

  const _AnimatedMonthBox({
    Key? key,
    required this.targetMonth,
    required this.monthLabel,
    required this.count,
    required this.hasAlert,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AnimatedMonthBox> createState() => _AnimatedMonthBoxState();
}

class _AnimatedMonthBoxState extends State<_AnimatedMonthBox>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.hasAlert) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedMonthBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasAlert && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..repeat();
    } else if (!widget.hasAlert && _controller != null) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.hasAlert
        ? Colors.amber
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final countColor = widget.hasAlert
        ? Colors.redAccent
        : Theme.of(context).colorScheme.outline;
    final bgColor = widget.hasAlert
        ? Colors.amber.withOpacity(0.12)
        : Colors.transparent;

    Widget content = Container(
      width: 105,
      height: 105,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: widget.hasAlert
            ? null // Handled by CustomPaint rotating border
            : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.monthLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.hasAlert ? '${widget.count} C-Off${widget.count != 1 ? 's' : ''}' : '0',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: countColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'tap to view',
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );

    if (widget.hasAlert && _controller != null) {
      content = AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _RotatingBorderPainter(
              progress: _controller!.value,
              accentColor: Colors.amberAccent,
              baseColor: Colors.amber.withOpacity(0.3),
              width: 105,
              height: 105,
              borderRadius: 12.0,
              strokeWidth: 2.0,
            ),
            child: child,
          );
        },
        child: content,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: content,
    );
  }
}

/// Custom painter that draws a seamless rotating sweep-gradient light ring
/// around the exact rounded rectangle border without altering widget bounds.
class _RotatingBorderPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color baseColor;
  final double width;
  final double height;
  final double borderRadius;
  final double strokeWidth;

  _RotatingBorderPainter({
    required this.progress,
    required this.accentColor,
    required this.baseColor,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      width - strokeWidth,
      height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final sweepGradient = SweepGradient(
      colors: [
        baseColor,
        accentColor,
        Colors.white,
        accentColor,
        baseColor,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = sweepGradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RotatingBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
