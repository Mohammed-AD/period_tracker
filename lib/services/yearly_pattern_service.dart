import '../models/cycle_entry.dart';

/// Aggregated stats for a single calendar month, used by the Yearly
/// Pattern screen.
class MonthlyStat {
  final int month; // 1-12
  final int periodDays; // total days bled, summed across entries, in this month
  final int periodsStarted; // how many periods started in this month
  final double? avgCycleLength; // avg gap (days) from the previous period, for periods starting this month

  MonthlyStat({
    required this.month,
    required this.periodDays,
    required this.periodsStarted,
    this.avgCycleLength,
  });
}

/// Everything the Yearly Pattern screen needs for one year, computed once
/// from the full entry history (cycle length needs the entry immediately
/// before the year boundary too, so we always work from all entries, not
/// just ones dated within the year).
class YearlyPatternData {
  final int year;
  final List<MonthlyStat> monthlyStats; // always length 12, index 0 = Jan
  final Map<DateTime, String> periodDaysFlow; // normalized date -> flow, for this year only
  final double? avgCycleLength;
  final double? avgPeriodLength;
  final int totalPeriodsLogged;
  final int longestCycle;
  final int shortestCycle;
  final Map<String, int> flowDistribution; // flow label -> number of bled days this year
  final Map<String, int> symptomDistribution; // symptom -> number of periods (this year) logging it
  final Map<String, int> moodDistribution; // mood -> number of periods (this year) logging it

  YearlyPatternData({
    required this.year,
    required this.monthlyStats,
    required this.periodDaysFlow,
    required this.avgCycleLength,
    required this.avgPeriodLength,
    required this.totalPeriodsLogged,
    required this.longestCycle,
    required this.shortestCycle,
    required this.flowDistribution,
    required this.symptomDistribution,
    required this.moodDistribution,
  });

  bool get hasData => totalPeriodsLogged > 0;

  /// Years that have at least one logged period, newest first. Falls back
  /// to the current year if nothing has been logged yet.
  static List<int> availableYears(List<CycleEntry> allEntries) {
    if (allEntries.isEmpty) return [DateTime.now().year];
    final years = allEntries.map((e) => e.startDate.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  factory YearlyPatternData.compute(List<CycleEntry> allEntries, int year) {
    final sorted = [...allEntries]..sort((a, b) => a.startDate.compareTo(b.startDate));

    final dayCounts = List<int>.filled(12, 0);
    final startCounts = List<int>.filled(12, 0);
    final cycleGapsByMonth = List<List<int>>.generate(12, (_) => []);
    final periodDaysFlow = <DateTime, String>{};
    final flowDistribution = <String, int>{};

    for (int i = 0; i < sorted.length; i++) {
      final entry = sorted[i];

      // Expand this period into individual bled days, but cap an ongoing
      // entry at today so we don't loop forever.
      final end = entry.endDate ?? DateTime.now();
      var day = DateTime(entry.startDate.year, entry.startDate.month, entry.startDate.day);
      final lastDay = DateTime(end.year, end.month, end.day);
      while (!day.isAfter(lastDay)) {
        if (day.year == year) {
          dayCounts[day.month - 1]++;
          periodDaysFlow[day] = entry.flow;
          flowDistribution[entry.flow] = (flowDistribution[entry.flow] ?? 0) + 1;
        }
        day = day.add(const Duration(days: 1));
      }

      if (entry.startDate.year == year) {
        startCounts[entry.startDate.month - 1]++;
        if (i > 0) {
          final gap = entry.startDate.difference(sorted[i - 1].startDate).inDays;
          if (gap > 0) cycleGapsByMonth[entry.startDate.month - 1].add(gap);
        }
      }
    }

    final monthlyStats = List.generate(12, (i) {
      final gaps = cycleGapsByMonth[i];
      final avgGap = gaps.isEmpty ? null : gaps.reduce((a, b) => a + b) / gaps.length;
      return MonthlyStat(
        month: i + 1,
        periodDays: dayCounts[i],
        periodsStarted: startCounts[i],
        avgCycleLength: avgGap,
      );
    });

    // Year-wide averages, based only on periods that started in this year.
    final yearEntries = sorted.where((e) => e.startDate.year == year).toList();
    final periodLengths = yearEntries.where((e) => e.periodLength != null).map((e) => e.periodLength!).toList();
    final avgPeriodLength = periodLengths.isEmpty ? null : periodLengths.reduce((a, b) => a + b) / periodLengths.length;

    final allGaps = cycleGapsByMonth.expand((g) => g).toList();
    final avgCycleLength = allGaps.isEmpty ? null : allGaps.reduce((a, b) => a + b) / allGaps.length;
    final longestCycle = allGaps.isEmpty ? 0 : allGaps.reduce((a, b) => a > b ? a : b);
    final shortestCycle = allGaps.isEmpty ? 0 : allGaps.reduce((a, b) => a < b ? a : b);

    final symptomDistribution = <String, int>{};
    final moodDistribution = <String, int>{};
    for (final e in yearEntries) {
      for (final s in e.symptoms) {
        symptomDistribution[s] = (symptomDistribution[s] ?? 0) + 1;
      }
      if (e.mood != null && e.mood!.isNotEmpty) {
        moodDistribution[e.mood!] = (moodDistribution[e.mood!] ?? 0) + 1;
      }
    }

    return YearlyPatternData(
      year: year,
      monthlyStats: monthlyStats,
      periodDaysFlow: periodDaysFlow,
      avgCycleLength: avgCycleLength,
      avgPeriodLength: avgPeriodLength,
      totalPeriodsLogged: yearEntries.length,
      longestCycle: longestCycle,
      shortestCycle: shortestCycle,
      flowDistribution: flowDistribution,
      symptomDistribution: symptomDistribution,
      moodDistribution: moodDistribution,
    );
  }
}