import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A compact, non-interactive month grid (like a tiny calendar tile) that
/// highlights which days had a period logged. Used to build the 12-month
/// "year at a glance" view.
class MiniMonthCalendar extends StatelessWidget {
  final int year;
  final int month; // 1-12
  final Map<DateTime, String> periodDaysFlow;

  const MiniMonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.periodDaysFlow,
  });

  Color _flowColor(String flow) {
    switch (flow.toLowerCase()) {
      case 'spotting':
        return AppColors.periodColor.withOpacity(0.35);
      case 'light':
        return AppColors.periodColor.withOpacity(0.55);
      case 'heavy':
        return AppColors.periodColor;
      case 'medium':
      default:
        return AppColors.periodColor.withOpacity(0.8);
    }
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday = 0 ... Sunday = 6, so weeks line up under day-of-week headers.
    final leadingBlanks = (firstDay.weekday + 6) % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final periodCount = List.generate(daysInMonth, (i) => i + 1)
        .where((d) => periodDaysFlow.containsKey(DateTime(year, month, d)))
        .length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _monthNames[month - 1],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (periodCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.periodColorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${periodCount}d',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.periodColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemBuilder: (context, index) {
              final dayNum = index - leadingBlanks + 1;
              if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
              final date = DateTime(year, month, dayNum);
              final flow = periodDaysFlow[date];
              return Padding(
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: flow != null ? _flowColor(flow) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: flow != null ? AppColors.textOnPrimary : AppColors.textSecondary,
                      fontWeight: flow != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
