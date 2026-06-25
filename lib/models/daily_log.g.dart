// GENERATED CODE - DO NOT MODIFY BY HAND
// Hand-written to match build_runner's output format — see cycle_entry.g.dart note.

part of 'daily_log.dart';

class DailyLogAdapter extends TypeAdapter<DailyLog> {
  @override
  final int typeId = 3;

  @override
  DailyLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyLog(
      date: fields[0] as DateTime,
      waterMl: fields[1] as int? ?? 0,
      sleepHours: fields[2] as double?,
      sleepQuality: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.waterMl)
      ..writeByte(2)
      ..write(obj.sleepHours)
      ..writeByte(3)
      ..write(obj.sleepQuality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
