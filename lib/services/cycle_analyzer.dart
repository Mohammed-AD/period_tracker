import '../models/cycle_entry.dart';

enum HealthStatus { healthy, attention, concern, insufficientData }

class HealthInsight {
  final HealthStatus status;
  final String title;
  final String summary;
  final List<String> details;
  final List<String> recommendations;

  HealthInsight({
    required this.status,
    required this.title,
    required this.summary,
    required this.details,
    required this.recommendations,
  });
}

/// Rule-based analysis engine — no external AI call needed.
/// Looks at logged cycle history and flags patterns worth attention.
class CycleAnalyzer {
  final List<CycleEntry> entries;

  CycleAnalyzer(this.entries);

  List<CycleEntry> get _sorted {
    final list = [...entries]..sort((a, b) => a.startDate.compareTo(b.startDate));
    return list;
  }

  /// Cycle length = days between consecutive period start dates.
  List<int> get cycleLengths {
    final sorted = _sorted;
    if (sorted.length < 2) return [];
    final lengths = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      lengths.add(sorted[i].startDate.difference(sorted[i - 1].startDate).inDays);
    }
    return lengths;
  }

  List<int> get periodLengths {
    return _sorted
        .where((e) => e.periodLength != null)
        .map((e) => e.periodLength!)
        .toList();
  }

  double? get averageCycleLength {
    final lengths = cycleLengths;
    if (lengths.isEmpty) return null;
    return lengths.reduce((a, b) => a + b) / lengths.length;
  }

  double? get averagePeriodLength {
    final lengths = periodLengths;
    if (lengths.isEmpty) return null;
    return lengths.reduce((a, b) => a + b) / lengths.length;
  }

  /// Standard deviation of cycle lengths — high variance = irregular cycles.
  double? get cycleLengthVariability {
    final lengths = cycleLengths;
    if (lengths.length < 2) return null;
    final avg = averageCycleLength!;
    final variance = lengths.map((l) => (l - avg) * (l - avg)).reduce((a, b) => a + b) / lengths.length;
    return variance > 0 ? (variance).abs() : 0;
  }

  DateTime? get predictedNextPeriodStart {
    final sorted = _sorted;
    if (sorted.isEmpty) return null;
    final last = sorted.last;
    final avgCycle = averageCycleLength ?? 28;
    return last.startDate.add(Duration(days: avgCycle.round()));
  }

  DateTime? get predictedOvulationDate {
    final next = predictedNextPeriodStart;
    if (next == null) return null;
    // Ovulation typically occurs ~14 days before the next period.
    return next.subtract(const Duration(days: 14));
  }

  DateTimeRange? get fertileWindow {
    final ovulation = predictedOvulationDate;
    if (ovulation == null) return null;
    return DateTimeRange(
      start: ovulation.subtract(const Duration(days: 5)),
      end: ovulation.add(const Duration(days: 1)),
    );
  }

  /// Main entry point: analyze full history and return a health insight.
  HealthInsight analyze() {
    if (_sorted.length < 2) {
      return HealthInsight(
        status: HealthStatus.insufficientData,
        title: 'Not enough data yet',
        summary: 'Log at least 2 periods so I can start analyzing your cycle patterns.',
        details: const [],
        recommendations: const [
          'Log your next period start and end date.',
          'Try to track symptoms daily for better insights.',
        ],
      );
    }

    final details = <String>[];
    final recommendations = <String>[];
    HealthStatus status = HealthStatus.healthy;

    final avgCycle = averageCycleLength!;
    final lengths = cycleLengths;
    final variability = cycleLengthVariability ?? 0;

    // Rule 1: Average cycle length out of typical healthy range (21-35 days)
    if (avgCycle < 21) {
      status = _worse(status, HealthStatus.concern);
      details.add('Your average cycle length is ${avgCycle.toStringAsFixed(0)} days, which is shorter than the typical 21–35 day range.');
      recommendations.add('Consider speaking with a gynecologist about consistently short cycles.');
    } else if (avgCycle > 35) {
      status = _worse(status, HealthStatus.concern);
      details.add('Your average cycle length is ${avgCycle.toStringAsFixed(0)} days, which is longer than the typical 21–35 day range.');
      recommendations.add('Cycles consistently longer than 35 days can be worth discussing with a doctor.');
    } else {
      details.add('Your average cycle length is ${avgCycle.toStringAsFixed(0)} days — within the typical healthy range.');
    }

    // Rule 2: High variability between cycles (irregular cycles)
    if (lengths.length >= 3) {
      final maxLen = lengths.reduce((a, b) => a > b ? a : b);
      final minLen = lengths.reduce((a, b) => a < b ? a : b);
      final spread = maxLen - minLen;
      if (spread > 9) {
        status = _worse(status, HealthStatus.attention);
        details.add('Your cycle lengths vary quite a bit (from $minLen to $maxLen days).');
        recommendations.add('Significant month-to-month variation can be normal, but tracking stress, weight changes, and sleep may help. Mention this pattern at your next checkup.');
      }
    }

    // Rule 3: Period (bleeding) duration
    final avgPeriod = averagePeriodLength;
    if (avgPeriod != null) {
      if (avgPeriod > 7) {
        status = _worse(status, HealthStatus.concern);
        details.add('Your periods are lasting an average of ${avgPeriod.toStringAsFixed(0)} days, longer than the typical 3–7 days.');
        recommendations.add('Periods regularly lasting more than 7 days should be evaluated by a doctor.');
      } else if (avgPeriod < 2) {
        status = _worse(status, HealthStatus.attention);
        details.add('Your periods are quite short, averaging ${avgPeriod.toStringAsFixed(1)} days.');
        recommendations.add('Very short periods can be normal for some people, but mention this if it\'s a recent change.');
      } else {
        details.add('Your periods last an average of ${avgPeriod.toStringAsFixed(0)} days — within a typical range.');
      }
    }

    // Rule 4: Heavy flow frequency
    final heavyCount = entries.where((e) => e.flow.toLowerCase() == 'heavy').length;
    if (heavyCount >= 3) {
      status = _worse(status, HealthStatus.attention);
      details.add('You\'ve logged heavy flow in $heavyCount of your recent periods.');
      recommendations.add('Frequent heavy bleeding can sometimes indicate hormonal imbalance or other conditions — worth a conversation with your doctor.');
    }

    // Rule 5: Missed/skipped period (large gap)
    if (lengths.isNotEmpty && lengths.last > 45) {
      status = _worse(status, HealthStatus.concern);
      details.add('It\'s been ${lengths.last} days since your last period started — longer than expected.');
      recommendations.add('A missed or significantly delayed period can have many causes (stress, pregnancy, hormonal shifts). Consider checking in with a doctor.');
    }

    // Rule 6: Frequent severe symptoms
    final symptomCounts = <String, int>{};
    for (final e in entries) {
      for (final s in e.symptoms) {
        symptomCounts[s] = (symptomCounts[s] ?? 0) + 1;
      }
    }
    final frequentSymptoms = symptomCounts.entries.where((e) => e.value >= entries.length * 0.7 && entries.length >= 3).map((e) => e.key).toList();
    if (frequentSymptoms.isNotEmpty) {
      details.add('You consistently log: ${frequentSymptoms.join(", ")}.');
      if (frequentSymptoms.contains('Cramps') && status == HealthStatus.healthy) {
        recommendations.add('Mild cramps are common. If they\'re severe enough to disrupt daily life, that\'s worth discussing with a doctor.');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add('Keep logging consistently — your cycle looks healthy overall!');
    }

    String summary;
    switch (status) {
      case HealthStatus.healthy:
        summary = 'Your cycle looks healthy and fairly regular based on your logged data.';
        break;
      case HealthStatus.attention:
        summary = 'Your cycle is mostly normal, but a few patterns are worth keeping an eye on.';
        break;
      case HealthStatus.concern:
        summary = 'A few patterns in your cycle suggest it may be worth checking in with a doctor.';
        break;
      case HealthStatus.insufficientData:
        summary = 'Not enough data yet.';
        break;
    }

    return HealthInsight(
      status: status,
      title: _titleFor(status),
      summary: summary,
      details: details,
      recommendations: recommendations,
    );
  }

  HealthStatus _worse(HealthStatus current, HealthStatus candidate) {
    const order = {
      HealthStatus.healthy: 0,
      HealthStatus.attention: 1,
      HealthStatus.concern: 2,
      HealthStatus.insufficientData: -1,
    };
    return order[candidate]! > order[current]! ? candidate : current;
  }

  String _titleFor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return 'Looking healthy 💚';
      case HealthStatus.attention:
        return 'Worth keeping an eye on 💛';
      case HealthStatus.concern:
        return 'Consider seeing a doctor 🩺';
      case HealthStatus.insufficientData:
        return 'Keep logging 📋';
    }
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  DateTimeRange({required this.start, required this.end});

  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) && (d.isAtSameMomentAs(e) || d.isBefore(e));
  }
}
