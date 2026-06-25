import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A frosted-glass styled card: soft gradient background, blurred backdrop,
/// and a thin translucent border/highlight. Used for the newer tracker and
/// insight cards so they feel like a distinct "glass" layer floating above
/// the page, rather than another flat AppColors.surface box.
///
/// Kept deliberately subtle — this app's existing visual language is soft
/// and pastel, so the glass effect is a light accent (low blur, gentle
/// gradient) rather than the heavy frosted-panel look you'd see in a
/// dashboard UI, which would clash with Bloom's softer aesthetic.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Color>? gradientColors;
  final double borderRadius;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradientColors,
    this.borderRadius = 24,
    this.blurSigma = 18,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ??
        [
          AppColors.primaryLight.withOpacity(0.55),
          AppColors.secondaryLight.withOpacity(0.35),
        ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
