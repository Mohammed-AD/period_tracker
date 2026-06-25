import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A brief animated "Saved!" confirmation: a circle draws itself, then a
/// checkmark draws inside it, then everything fades and the caller's
/// [onComplete] fires.
///
/// This is a hand-built Flutter animation rather than a real Lottie
/// file — we don't have network access in this environment to fetch a
/// `.json` Lottie asset from LottieFiles, and `lottie: ^3.1.2` is in
/// pubspec.yaml but has nothing to play yet. If you want an actual Lottie
/// animation here later: drop a file at `assets/lottie/success.json`,
/// list it under `flutter: assets:` in pubspec.yaml, and replace the
/// body of this widget with `Lottie.asset('assets/lottie/success.json',
/// repeat: false, onLoaded: (comp) { ... })` — the call site in
/// log_entry_screen.dart (`showSuccessOverlay`) doesn't need to change.
class SuccessOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onComplete;

  const SuccessOverlay({super.key, required this.message, required this.onComplete});

  /// Shows the overlay above the current screen for ~1.1s, then pops it
  /// and calls [onComplete] — handy for "saved!" confirmations right
  /// before navigating back.
  static Future<void> show(BuildContext context, {String message = 'Saved!'}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.15),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) {
        return SuccessOverlay(
          message: message,
          onComplete: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<SuccessOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleProgress;
  late Animation<double> _checkProgress;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _circleProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _checkProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOutBack),
    );
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    );
    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: 1 - _fadeOut.value,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CustomPaint(
                        painter: _CheckPainter(
                          circleProgress: _circleProgress.value,
                          checkProgress: _checkProgress.value,
                          color: AppColors.fertileColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.message,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color color;

  _CheckPainter({required this.circleProgress, required this.checkProgress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      circlePaint,
    );

    if (checkProgress <= 0) return;
    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Checkmark as two segments: short stroke down-right, then long stroke
    // up-right, animated by progressively revealing points along the path.
    final p1 = Offset(center.dx - radius * 0.42, center.dy + radius * 0.02);
    final p2 = Offset(center.dx - radius * 0.08, center.dy + radius * 0.34);
    final p3 = Offset(center.dx + radius * 0.46, center.dy - radius * 0.32);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (checkProgress <= 0.5) {
      final t = checkProgress / 0.5;
      path.lineTo(_lerp(p1, p2, t).dx, _lerp(p1, p2, t).dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (checkProgress - 0.5) / 0.5;
      path.lineTo(_lerp(p2, p3, t).dx, _lerp(p2, p3, t).dy);
    }
    canvas.drawPath(path, checkPaint);
  }

  Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t.clamp(0.0, 1.0))!;

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.circleProgress != circleProgress || oldDelegate.checkProgress != checkProgress;
}
