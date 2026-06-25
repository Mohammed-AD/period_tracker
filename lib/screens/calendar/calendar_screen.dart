import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:table_calendar/table_calendar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
import '../../models/cycle_entry.dart';
import '../../services/cycle_repository.dart';
import '../../services/cycle_analyzer.dart';
import '../../services/reminder_scheduler.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cycle_wheel.dart';
import '../../widgets/glass_card.dart';
import '../log_entry/log_entry_screen.dart';

enum _DayPhase { period, predictedPeriod, fertile, ovulation, none }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late List<CycleEntry> _entries;
  late CycleAnalyzer _analyzer;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadData();
  }

  void _loadData() {
    _entries = CycleRepository.getAllEntries();
    _analyzer = CycleAnalyzer(_entries);
  }

  void _refresh() {
    setState(() => _loadData());
  }

  _DayPhase _phaseFor(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);

    // Logged period days
    for (final entry in _entries) {
      final start = DateTime(entry.startDate.year, entry.startDate.month, entry.startDate.day);
      final end = entry.endDate != null
          ? DateTime(entry.endDate!.year, entry.endDate!.month, entry.endDate!.day)
          : start;
      if ((d.isAtSameMomentAs(start) || d.isAfter(start)) &&
          (d.isAtSameMomentAs(end) || d.isBefore(end))) {
        return _DayPhase.period;
      }
    }

    // Predicted next period
    final predicted = _analyzer.predictedNextPeriodStart;
    if (predicted != null) {
      final settings = CycleRepository.getSettings();
      final predictedEnd = predicted.add(Duration(days: settings.averagePeriodLength - 1));
      final pStart = DateTime(predicted.year, predicted.month, predicted.day);
      final pEnd = DateTime(predictedEnd.year, predictedEnd.month, predictedEnd.day);
      if ((d.isAtSameMomentAs(pStart) || d.isAfter(pStart)) &&
          (d.isAtSameMomentAs(pEnd) || d.isBefore(pEnd))) {
        return _DayPhase.predictedPeriod;
      }
    }

    // Ovulation day
    final ovulation = _analyzer.predictedOvulationDate;
    if (ovulation != null) {
      final o = DateTime(ovulation.year, ovulation.month, ovulation.day);
      if (d.isAtSameMomentAs(o)) return _DayPhase.ovulation;
    }

    // Fertile window
    final fertile = _analyzer.fertileWindow;
    if (fertile != null && fertile.contains(d)) {
      return _DayPhase.fertile;
    }

    return _DayPhase.none;
  }

  Color _colorForPhase(_DayPhase phase) {
    switch (phase) {
      case _DayPhase.period:
        return AppColors.periodColor;
      case _DayPhase.predictedPeriod:
        return AppColors.predictedColor;
      case _DayPhase.fertile:
        return AppColors.fertileColor;
      case _DayPhase.ovulation:
        return AppColors.ovulationColor;
      case _DayPhase.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final cycleDay = _currentCycleDay();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              _buildHeader(cycleDay),
              const SizedBox(height: 20),
              _buildCycleWheelCard(cycleDay),
              const SizedBox(height: 16),
              _buildProgressRingsRow(cycleDay),
              const SizedBox(height: 16),
              _buildFertileWindowSummary(),
              const SizedBox(height: 16),
              _buildClearMonthButton(),
              const SizedBox(height: 12),
              _buildCalendarCard(),
              const SizedBox(height: 16),
              _buildLegend(),
              const SizedBox(height: 20),
              if (_selectedDay != null) _buildSelectedDayPanel(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LogEntryScreen(initialDate: _selectedDay ?? today)),
          );
          if (result == true) _refresh();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Log Period', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  int? _currentCycleDay() {
    if (_entries.isEmpty) return null;
    final last = _entries.first; // sorted desc by startDate
    return DateTime.now().difference(last.startDate).inDays + 1;
  }

  Widget _buildHeader(int? cycleDay) {
    final settings = CycleRepository.getSettings();
    final greeting = settings.userName != null && settings.userName!.isNotEmpty
        ? 'Hi, ${settings.userName} 🌸'
        : 'Hi there 🌸';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                cycleDay != null ? 'Cycle Day $cycleDay' : 'Log your first period to begin',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCycleWheelCard(int? cycleDay) {
    final settings = CycleRepository.getSettings();
    final lastEntry = _entries.isNotEmpty ? _entries.first : null;

    int? fertileStartDay;
    int? fertileEndDay;
    int? ovulationDay;

    if (lastEntry != null) {
      final fertile = _analyzer.fertileWindow;
      final ovulation = _analyzer.predictedOvulationDate;
      if (fertile != null) {
        fertileStartDay = fertile.start.difference(lastEntry.startDate).inDays + 1;
        fertileEndDay = fertile.end.difference(lastEntry.startDate).inDays + 1;
      }
      if (ovulation != null) {
        ovulationDay = ovulation.difference(lastEntry.startDate).inDays + 1;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Center(
        child: CycleWheel(
          currentCycleDay: cycleDay,
          cycleLength: settings.averageCycleLength,
          periodLength: settings.averagePeriodLength,
          fertileStartDay: fertileStartDay,
          fertileEndDay: fertileEndDay,
          ovulationDay: ovulationDay,
        ),
      ),
    );
  }

  Widget _buildProgressRingsRow(int? cycleDay) {
    final settings = CycleRepository.getSettings();
    final lastEntry = _entries.isNotEmpty ? _entries.first : null;

    double periodProgress = 0;
    String periodLabel = 'No period logged';
    if (cycleDay != null && lastEntry != null && lastEntry.isOngoing) {
      periodProgress = (cycleDay / settings.averagePeriodLength).clamp(0.0, 1.0);
      periodLabel = 'Day $cycleDay of ~${settings.averagePeriodLength}';
    } else if (cycleDay != null) {
      periodLabel = 'Day $cycleDay of cycle';
    }

    double fertileProgress = 0;
    String fertileLabel = 'Not in fertile window';
    final fertile = _analyzer.fertileWindow;
    if (fertile != null) {
      final today = DateTime.now();
      final totalDays = fertile.end.difference(fertile.start).inDays + 1;
      if (fertile.contains(today)) {
        final elapsed = DateTime(today.year, today.month, today.day)
                .difference(DateTime(fertile.start.year, fertile.start.month, fertile.start.day))
                .inDays +
            1;
        fertileProgress = (elapsed / totalDays).clamp(0.0, 1.0);
        fertileLabel = 'Day $elapsed of $totalDays fertile';
      } else if (today.isBefore(fertile.start)) {
        final daysUntil = fertile.start.difference(today).inDays;
        fertileLabel = 'Starts in $daysUntil ${daysUntil == 1 ? "day" : "days"}';
      }
    }

    return Row(
      children: [
        Expanded(child: _ringStat(
          percent: periodProgress,
          color: AppColors.periodColor,
          icon: Icons.water_drop_rounded,
          label: periodLabel,
        )),
        const SizedBox(width: 12),
        Expanded(child: _ringStat(
          percent: fertileProgress,
          color: AppColors.fertileColor,
          icon: Icons.eco_rounded,
          label: fertileLabel,
        )),
      ],
    );
  }

  Widget _ringStat({required double percent, required Color color, required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CircularPercentIndicator(
              radius: 26,
              lineWidth: 6,
              percent: value,
              animation: false,
              circularStrokeCap: CircularStrokeCap.round,
              backgroundColor: AppColors.divider,
              progressColor: color,
              center: Icon(icon, size: 16, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFertileWindowSummary() {
    final fertile = _analyzer.fertileWindow;
    final ovulation = _analyzer.predictedOvulationDate;

    if (fertile == null || ovulation == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Log at least one period to see your predicted fertile window.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final rangeStr =
        '${DateFormat('MMM d').format(fertile.start)} – ${DateFormat('MMM d').format(fertile.end)}';
    final ovulationStr = DateFormat('MMM d').format(ovulation);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      gradientColors: [AppColors.fertileColorLight.withOpacity(0.8), AppColors.fertileColorLight.withOpacity(0.4)],
      borderRadius: 18,
      blurSigma: 10,
      child: Row(
        children: [
          Icon(Icons.eco_rounded, color: AppColors.fertileColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fertile window: $rangeStr',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Predicted ovulation around $ovulationStr',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearMonthButton() {
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedDay);
    final count = CycleRepository.getEntriesForMonth(_focusedDay).length;
    if (count == 0) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => _clearMonth(_focusedDay),
        icon: Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.concern),
        label: Text(
          'Clear $monthLabel ($count)',
          style: TextStyle(color: AppColors.concern, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  /// Deletes every period entry whose start date falls in [month] — scoped
  /// strictly to whichever month is currently shown on the calendar, never
  /// to all saved data. The confirmation names the exact month and count
  /// so there's no ambiguity about what's about to be removed.
  Future<void> _clearMonth(DateTime month) async {
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final entries = CycleRepository.getEntriesForMonth(month);
    if (entries.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Clear $monthLabel?'),
        content: Text(
          'This will permanently delete ${entries.length} period ${entries.length == 1 ? "entry" : "entries"} '
          'logged in $monthLabel. Other months are not affected. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.concern, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deletedCount = await CycleRepository.deleteEntriesForMonth(month);
    HapticFeedback.mediumImpact();

    try {
      await ReminderScheduler.rescheduleAll(CycleRepository.getAllEntries());
    } catch (_) {
      // Non-fatal — reminders are a side effect, see ReminderScheduler docs.
    }

    if (mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $deletedCount ${deletedCount == 1 ? "entry" : "entries"} from $monthLabel.')),
      );
    }
  }

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: TableCalendar(
        firstDay: DateTime(2023, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onPageChanged: (focused) => setState(() => _focusedDay = focused),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppColors.primary),
          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
          weekendStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        calendarStyle: const CalendarStyle(outsideDaysVisible: false),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _buildDayCell(day),
          todayBuilder: (context, day, focusedDay) => _buildDayCell(day, isToday: true),
          selectedBuilder: (context, day, focusedDay) => _buildDayCell(day, isSelected: true),
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {bool isToday = false, bool isSelected = false}) {
    final phase = _phaseFor(day);
    final phaseColor = _colorForPhase(phase);
    final hasPhase = phase != _DayPhase.none;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasPhase ? phaseColor.withOpacity(phase == _DayPhase.predictedPeriod ? 0.45 : 0.9) : Colors.transparent,
        border: isSelected
            ? Border.all(color: AppColors.todayBorder, width: 2)
            : isToday
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: hasPhase && phase != _DayPhase.predictedPeriod ? Colors.white : AppColors.textPrimary,
          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendDot(AppColors.periodColor, 'Period'),
        _legendDot(AppColors.predictedColor, 'Predicted'),
        _legendDot(AppColors.fertileColor, 'Fertile'),
        _legendDot(AppColors.ovulationColor, 'Ovulation'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildSelectedDayPanel() {
    final phase = _phaseFor(_selectedDay!);
    final dateStr = DateFormat('EEEE, MMM d').format(_selectedDay!);

    final entry = _entries.where((e) {
      final start = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end = e.endDate != null
          ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day)
          : start;
      final d = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      return (d.isAtSameMomentAs(start) || d.isAfter(start)) && (d.isAtSameMomentAs(end) || d.isBefore(end));
    }).toList();

    String phaseLabel;
    switch (phase) {
      case _DayPhase.period:
        phaseLabel = 'Period day';
        break;
      case _DayPhase.predictedPeriod:
        phaseLabel = 'Predicted period';
        break;
      case _DayPhase.fertile:
        phaseLabel = 'Fertile window';
        break;
      case _DayPhase.ovulation:
        phaseLabel = 'Predicted ovulation';
        break;
      case _DayPhase.none:
        phaseLabel = 'No data';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(phaseLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          if (entry.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.divider),
            const SizedBox(height: 8),
            Text('Flow: ${entry.first.flow}', style: Theme.of(context).textTheme.bodyMedium),
            if (entry.first.symptoms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Symptoms: ${entry.first.symptoms.join(", ")}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            if (entry.first.mood != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Mood: ${entry.first.mood}', style: Theme.of(context).textTheme.bodyMedium),
              ),
          ],
        ],
      ),
    );
  }
}
