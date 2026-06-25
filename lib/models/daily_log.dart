import 'package:hive/hive.dart';

part 'daily_log.g.dart';

/// One row per calendar day, holding the day's sleep + water tracking.
/// Kept separate from CycleEntry (which is period-specific) since these
/// are logged every day regardless of where someone is in their cycle.
@HiveType(typeId: 3)
class DailyLog extends HiveObject {
  /// Normalized to midnight, used as the lookup key (see DailyLogRepository).
  @HiveField(0)
  DateTime date;

  /// Water drunk so far today, in milliliters.
  @HiveField(1)
  int waterMl;

  /// Hours slept the previous night. Null until logged.
  @HiveField(2)
  double? sleepHours;

  /// Subjective sleep quality: 'Poor', 'Okay', 'Good', 'Great'. Null until logged.
  @HiveField(3)
  String? sleepQuality;

  DailyLog({
    required this.date,
    this.waterMl = 0,
    this.sleepHours,
    this.sleepQuality,
  });
}

/// Sleep quality options shown in the sleep tracker.
class SleepQualityOptions {
  static const List<String> all = ['Poor', 'Okay', 'Good', 'Great'];
}
