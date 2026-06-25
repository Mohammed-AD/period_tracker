import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
import '../../models/daily_log.dart';
import '../../services/cycle_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// Daily Sleep + Water tracker. Always operates on "today" — past days can
/// be reviewed in the small history strip at the bottom, but logging only
/// ever targets the current day, matching how people actually use these
/// trackers (you log today's water as you drink it, not last Tuesday's).
class TrackersScreen extends StatefulWidget {
  const TrackersScreen({super.key});

  @override
  State<TrackersScreen> createState() => TrackersScreenState();
}

class TrackersScreenState extends State<TrackersScreen> {
  late DailyLog _today;
  late int _waterGoalMl;
  bool _loading = true;

  static const int _cupMl = 250;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await CycleRepository.getOrCreateDailyLog(DateTime.now());
    final settings = CycleRepository.getSettings();
    if (!mounted) return;
    setState(() {
      _today = log;
      _waterGoalMl = settings.waterGoalMl;
      _loading = false;
    });
  }

  /// Called from HomeScreen when this tab is reselected, so a new day's
  /// empty log shows up correctly instead of yesterday's stale one (the
  /// same IndexedStack staleness issue documented on InsightsScreen).
  void reload() {
    if (!mounted) return;
    setState(() => _loading = true);
    _load();
  }

  Future<void> _addWater(int ml) async {
    HapticFeedback.lightImpact();
    setState(() => _today.waterMl = (_today.waterMl + ml).clamp(0, 20000).toInt());
    await CycleRepository.saveDailyLog(_today);
  }

  Future<void> _removeWater() async {
    if (_today.waterMl <= 0) return;
    HapticFeedback.selectionClick();
    setState(() => _today.waterMl = (_today.waterMl - _cupMl).clamp(0, 20000).toInt());
    await CycleRepository.saveDailyLog(_today);
  }

  Future<void> _setSleep(double hours, String quality) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _today.sleepHours = hours;
      _today.sleepQuality = quality;
    });
    await CycleRepository.saveDailyLog(_today);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Text('Trackers', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _buildWaterCard(),
              const SizedBox(height: 20),
              _buildSleepCard(),
              const SizedBox(height: 20),
              _buildWeekStrip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterCard() {
    final progress = _waterGoalMl == 0 ? 0.0 : (_today.waterMl / _waterGoalMl).clamp(0.0, 1.0);
    final liters = (_today.waterMl / 1000).toStringAsFixed(2);
    final goalLiters = (_waterGoalMl / 1000).toStringAsFixed(1);

    return GlassCard(
      gradientColors: [AppColors.fertileColorLight.withOpacity(0.7), AppColors.secondaryLight.withOpacity(0.4)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, color: AppColors.fertileColor),
              const SizedBox(width: 8),
              Text('Water intake', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => CircularPercentIndicator(
                  radius: 56,
                  lineWidth: 12,
                  percent: value,
                  animation: false,
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: AppColors.surface,
                  progressColor: AppColors.fertileColor,
                  center: Text(
                    '${(value * 100).round()}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$liters L of $goalLiters L', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Goal: ${_waterGoalMl}ml/day', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _circleButton(Icons.remove_rounded, _removeWater),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _addWater(_cupMl),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('250ml'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.fertileColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return _TapScale(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.divider)),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildSleepCard() {
    final hours = _today.sleepHours;

    return GlassCard(
      gradientColors: [AppColors.secondaryLight.withOpacity(0.7), AppColors.primaryLight.withOpacity(0.4)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_rounded, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('Sleep', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hours != null ? '${hours.toStringAsFixed(1)} hours last night' : 'How did you sleep last night?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0].map((h) {
              final selected = hours == h;
              return _TapScale(
                onTap: () => _setSleep(h, _today.sleepQuality ?? 'Okay'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.secondary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${h.toStringAsFixed(0)}h',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (hours != null) ...[
            const SizedBox(height: 16),
            Text('How was the quality?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SleepQualityOptions.all.map((q) {
                final selected = _today.sleepQuality == q;
                return _TapScale(
                  onTap: () => _setSleep(hours, q),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      q,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final logs = CycleRepository.getRecentDailyLogs(7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 days', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: logs.map((log) {
              final waterPct = _waterGoalMl == 0 ? 0.0 : (log.waterMl / _waterGoalMl).clamp(0.0, 1.0);
              final isToday = DateUtils.isSameDay(log.date, DateTime.now());
              return Column(
                children: [
                  SizedBox(
                    height: 50,
                    width: 18,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: waterPct == 0 ? 0.04 : waterPct,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.fertileColor.withOpacity(waterPct == 0 ? 0.3 : 1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E').format(log.date).substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Small reusable "press to shrink slightly" wrapper for tap micro-feedback,
/// used throughout the trackers UI instead of a bare GestureDetector so
/// every tappable chip/button here feels consistently responsive.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
