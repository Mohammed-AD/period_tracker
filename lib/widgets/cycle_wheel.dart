import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A circular "wheel" representation of the user's cycle: one full lap of
/// the ring = one average cycle. Colored arcs mark the period, the fertile
/// window, and ovulation day; a small marker shows where "today" sits on
/// that lap. The ring animates in (sweeping into place) the first time it
/// appears, and the today-marker gently pulses to draw the eye.
///
/// All inputs are plain values (no repository/service calls in here) so
/// this stays easy to preview, test, and reuse from any screen.
class CycleWheel extends StatefulWidget {
  /// 1-indexed day within the current cycle (day 1 = period start). Used
  /// to place the "today" marker and drive the center label.
  final int? currentCycleDay;

  /// Average length of a full cycle, in days — defines one lap of the ring.
  final int cycleLength;

  /// Average period length, in days, starting at day 1.
  final int periodLength;

  /// 1-indexed day-of-cycle the fertile window starts on (inclusive).
  final int? fertileStartDay;

  /// 1-indexed day-of-cycle the fertile window ends on (inclusive).
  final int? fertileEndDay;

  /// 1-indexed day-of-cycle ovulation is predicted on.
  final int? ovulationDay;

  final double size;

  const CycleWheel({
    super.key,
    required this.currentCycleDay,
    required this.cycleLength,
    required this.periodLength,
    this.fertileStartDay,
    this.fertileEndDay,
    this.ovulationDay,
    this.size = 260,
  });

  @override
  State<CycleWheel> createState() => _CycleWheelState();
}

class _CycleWheelState extends State<CycleWheel> with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _pulseController;
  late Animation<double> _sweepProgress;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweepProgress = CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_introController, _pulseController]),
        builder: (context, _) {
          return CustomPaint(
            painter: _CycleWheelPainter(
              sweepProgress: _sweepProgress.value,
              pulseValue: _pulseController.value,
              cycleLength: widget.cycleLength,
              periodLength: widget.periodLength,
              currentCycleDay: widget.currentCycleDay,
              fertileStartDay: widget.fertileStartDay,
              fertileEndDay: widget.fertileEndDay,
              ovulationDay: widget.ovulationDay,
              periodColor: AppColors.periodColor,
              fertileColor: AppColors.fertileColor,
              ovulationColor: AppColors.ovulationColor,
              trackColor: AppColors.divider,
              todayBorder: AppColors.todayBorder,
              surface: AppColors.surface,
            ),
            child: Center(child: _buildCenterLabel(context)),
          );
        },
      ),
    );
  }

  Widget _buildCenterLabel(BuildContext context) {
    final day = widget.currentCycleDay;
    if (day == null) {
      return Text(
        'Log your\nfirst period',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Day', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        Text(
          '$day',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        Text(
          'of ${widget.cycleLength}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _CycleWheelPainter extends CustomPainter {
  final double sweepProgress; // 0..1 intro animation
  final double pulseValue; // 0..1 ping-pong pulse
  final int cycleLength;
  final int periodLength;
  final int? currentCycleDay;
  final int? fertileStartDay;
  final int? fertileEndDay;
  final int? ovulationDay;
  final Color periodColor;
  final Color fertileColor;
  final Color ovulationColor;
  final Color trackColor;
  final Color todayBorder;
  final Color surface;

  _CycleWheelPainter({
    required this.sweepProgress,
    required this.pulseValue,
    required this.cycleLength,
    required this.periodLength,
    required this.currentCycleDay,
    required this.fertileStartDay,
    required this.fertileEndDay,
    required this.ovulationDay,
    required this.periodColor,
    required this.fertileColor,
    required this.ovulationColor,
    required this.trackColor,
    required this.todayBorder,
    required this.surface,
  });

  // -90deg so day 1 starts at the top of the circle, like a clock at 12.
  static const double _startAngle = -math.pi / 2;

  double _angleForDay(num day, int total) => _startAngle + (2 * math.pi) * (day / total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    final strokeWidth = 18.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    void drawArc(int startDay, int endDayExclusive, Color color, {double opacity = 1}) {
      final clampedStart = startDay.clamp(0, cycleLength);
      final clampedEnd = endDayExclusive.clamp(0, cycleLength);
      if (clampedEnd <= clampedStart) return;
      final startAngle = _angleForDay(clampedStart, cycleLength);
      final fullSweep = _angleForDay(clampedEnd, cycleLength) - startAngle;
      final animatedSweep = fullSweep * sweepProgress;
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        animatedSweep,
        false,
        paint,
      );
    }

    // Fertile window (drawn first so ovulation/period visually sit "on top")
    if (fertileStartDay != null && fertileEndDay != null) {
      drawArc(fertileStartDay! - 1, fertileEndDay!, fertileColor, opacity: 0.85);
    }

    // Ovulation day — a short, slightly thicker emphasis arc.
    if (ovulationDay != null) {
      drawArc(ovulationDay! - 1, ovulationDay!, ovulationColor);
    }

    // Period days, day 1..periodLength.
    drawArc(0, periodLength, periodColor);

    // Today marker: a small dot + ring riding on the circle, gently pulsing.
    final today = currentCycleDay;
    if (today != null && today >= 1) {
      final angle = _angleForDay(today - 0.5, cycleLength) * sweepProgress +
          _startAngle * (1 - sweepProgress);
      final markerCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final pulseRadius = 9 + pulseValue * 3;

      final glowPaint = Paint()
        ..color = todayBorder.withOpacity(0.25 * sweepProgress)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(markerCenter, pulseRadius, glowPaint);

      final dotPaint = Paint()
        ..color = surface
        ..style = PaintingStyle.fill;
      canvas.drawCircle(markerCenter, 8 * sweepProgress, dotPaint);

      final ringPaint = Paint()
        ..color = todayBorder.withOpacity(sweepProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(markerCenter, 8 * sweepProgress, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CycleWheelPainter oldDelegate) {
    return oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.cycleLength != cycleLength ||
        oldDelegate.periodLength != periodLength ||
        oldDelegate.currentCycleDay != currentCycleDay ||
        oldDelegate.fertileStartDay != fertileStartDay ||
        oldDelegate.fertileEndDay != fertileEndDay ||
        oldDelegate.ovulationDay != ovulationDay;
  }
}
