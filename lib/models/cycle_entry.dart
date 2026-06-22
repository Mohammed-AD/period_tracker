import 'package:hive/hive.dart';

part 'cycle_entry.g.dart';

@HiveType(typeId: 0)
class CycleEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime startDate;

  @HiveField(2)
  DateTime? endDate;

  @HiveField(3)
  List<String> symptoms; // e.g. cramps, headache, bloating, fatigue

  @HiveField(4)
  String flow; // light, medium, heavy, spotting

  @HiveField(5)
  String? mood; // happy, sad, irritable, anxious, calm

  @HiveField(6)
  String? notes;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  CycleEntry({
    required this.id,
    required this.startDate,
    this.endDate,
    List<String>? symptoms,
    this.flow = 'medium',
    this.mood,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : symptoms = symptoms ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Length of this period in days (inclusive). Null if still ongoing.
  int? get periodLength {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays + 1;
  }

  bool get isOngoing => endDate == null;
}

/// Symptom options shown in the log entry screen.
class SymptomOptions {
  static const List<String> all = [
    'Cramps',
    'Headache',
    'Bloating',
    'Fatigue',
    'Backache',
    'Nausea',
    'Acne',
    'Tender breasts',
    'Mood swings',
    'Cravings',
    'Insomnia',
    'Diarrhea',
  ];
}

class FlowOptions {
  static const List<String> all = ['Spotting', 'Light', 'Medium', 'Heavy'];
}

class MoodOptions {
  static const List<String> all = [
    'Happy',
    'Calm',
    'Irritable',
    'Anxious',
    'Sad',
    'Energetic',
  ];
}
