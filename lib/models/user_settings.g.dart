// GENERATED CODE - DO NOT MODIFY BY HAND
// Hand-written to match build_runner's output format — see cycle_entry.g.dart note.

part of 'user_settings.dart';

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 1;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      onboardingComplete: fields[0] as bool,
      averageCycleLength: fields[1] as int,
      averagePeriodLength: fields[2] as int,
      lockEnabled: fields[3] as bool,
      biometricEnabled: fields[4] as bool,
      userName: fields[5] as String?,
      lastPeriodStartManual: fields[6] as DateTime?,
      remindersEnabled: fields[7] as bool,
      // Older saved records (written before theming was added) won't have
      // field 8 — default to 'rose' so they don't crash on load.
      themeName: fields[8] as String? ?? 'rose',
      // Fields 9-11 added later (profile photo / age / email) — older
      // records simply won't have them, default to null.
      profileImagePath: fields[9] as String?,
      age: fields[10] as int?,
      email: fields[11] as String?,
      // Fields 12-15 added with the trackers/reminders update — older
      // records won't have them, default sensibly so nothing crashes.
      waterGoalMl: fields[12] as int? ?? 2000,
      periodReminderEnabled: fields[13] as bool? ?? true,
      ovulationReminderEnabled: fields[14] as bool? ?? true,
      waterReminderEnabled: fields[15] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.onboardingComplete)
      ..writeByte(1)
      ..write(obj.averageCycleLength)
      ..writeByte(2)
      ..write(obj.averagePeriodLength)
      ..writeByte(3)
      ..write(obj.lockEnabled)
      ..writeByte(4)
      ..write(obj.biometricEnabled)
      ..writeByte(5)
      ..write(obj.userName)
      ..writeByte(6)
      ..write(obj.lastPeriodStartManual)
      ..writeByte(7)
      ..write(obj.remindersEnabled)
      ..writeByte(8)
      ..write(obj.themeName)
      ..writeByte(9)
      ..write(obj.profileImagePath)
      ..writeByte(10)
      ..write(obj.age)
      ..writeByte(11)
      ..write(obj.email)
      ..writeByte(12)
      ..write(obj.waterGoalMl)
      ..writeByte(13)
      ..write(obj.periodReminderEnabled)
      ..writeByte(14)
      ..write(obj.ovulationReminderEnabled)
      ..writeByte(15)
      ..write(obj.waterReminderEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
