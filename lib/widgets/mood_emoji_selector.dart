import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/app_theme.dart';
import '../models/cycle_entry.dart';

/// Maps each MoodOptions value to an emoji + accent color so the mood
/// picker reads instantly, instead of relying on text labels alone.
class MoodVisuals {
  static const Map<String, String> emoji = {
    'Happy': '😊',
    'Calm': '😌',
    'Irritable': '😤',
    'Anxious': '😟',
    'Sad': '😢',
    'Energetic': '⚡',
  };

  static Color colorFor(String mood) {
    switch (mood) {
      case 'Happy':
        return const Color(0xFFFFC857);
      case 'Calm':
        return const Color(0xFF8FD3C7);
      case 'Irritable':
        return const Color(0xFFE8607F);
      case 'Anxious':
        return const Color(0xFFB9A6DD);
      case 'Sad':
        return const Color(0xFF8FA9D3);
      case 'Energetic':
        return const Color(0xFFFF9F6B);
      default:
        return AppColors.primary;
    }
  }
}

/// A row of tappable emoji "bubbles" for mood selection. Selecting one
/// pops it slightly larger with a colored glow; tapping the already-
/// selected mood deselects it (matches the previous ChoiceChip behavior).
class MoodEmojiSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const MoodEmojiSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: MoodOptions.all.map((mood) {
        final isSelected = selected == mood;
        return _MoodBubble(
          mood: mood,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(isSelected ? null : mood);
          },
        );
      }).toList(),
    );
  }
}

class _MoodBubble extends StatefulWidget {
  final String mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodBubble({required this.mood, required this.isSelected, required this.onTap});

  @override
  State<_MoodBubble> createState() => _MoodBubbleState();
}

class _MoodBubbleState extends State<_MoodBubble> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = MoodVisuals.colorFor(widget.mood);
    final emoji = MoodVisuals.emoji[widget.mood] ?? '🙂';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : (widget.isSelected ? 1.08 : 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected ? color.withOpacity(0.22) : AppColors.cardBackground,
                border: Border.all(
                  color: widget.isSelected ? color : Colors.transparent,
                  width: 2,
                ),
                boxShadow: widget.isSelected
                    ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 6),
            Text(
              widget.mood,
              style: TextStyle(
                fontSize: 11,
                color: widget.isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
