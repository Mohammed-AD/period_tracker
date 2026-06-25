import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/app_theme.dart';
import '../models/cycle_entry.dart';

/// Replaces the plain ChoiceChip row for flow intensity with a row of
/// animated droplets — more droplets filled = heavier flow. Tapping a
/// droplet bounces it into place, which communicates "heavier" through
/// motion as well as fill count and droplet size.
class FlowIntensitySelector extends StatelessWidget {
  final String selected; // one of FlowOptions.all
  final ValueChanged<String> onChanged;

  const FlowIntensitySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  int get _selectedIndex => FlowOptions.all.indexOf(selected).clamp(0, FlowOptions.all.length - 1).toInt();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < FlowOptions.all.length; i++)
          Expanded(
            child: _DropletOption(
              label: FlowOptions.all[i],
              filled: i <= _selectedIndex,
              // Spotting's droplet is intentionally the smallest, heavy's the
              // largest — size itself communicates intensity, not just color.
              fillScale: 0.55 + (i / (FlowOptions.all.length - 1)) * 0.45,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(FlowOptions.all[i]);
              },
            ),
          ),
      ],
    );
  }
}

class _DropletOption extends StatefulWidget {
  final String label;
  final bool filled;
  final double fillScale;
  final VoidCallback onTap;

  const _DropletOption({
    required this.label,
    required this.filled,
    required this.fillScale,
    required this.onTap,
  });

  @override
  State<_DropletOption> createState() => _DropletOptionState();
}

class _DropletOptionState extends State<_DropletOption> with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(_DropletOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filled && !oldWidget.filled) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.filled ? AppColors.periodColor : AppColors.divider;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              // A quick overshoot-then-settle "bounce" using a sine curve
              // over the controller's 0..1 lifetime, layered on top of the
              // droplet's resting scale.
              final t = _bounceController.value;
              final bounceExtra = widget.filled ? (0.3 * (1 - t) * (t < 1 ? 1 : 0)) : 0.0;
              return Transform.scale(scale: 1.0 + bounceExtra, child: child);
            },
            child: AnimatedScale(
              scale: widget.fillScale,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(2),
                  ),
                ),
                transform: Matrix4.rotationZ(0.78),
                transformAlignment: Alignment.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              color: widget.filled ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: widget.filled ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
