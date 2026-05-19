// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_call.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecentCallAdapter extends TypeAdapter<RecentCall> {
  @override
  final int typeId = 1;

  @override
  RecentCall read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecentCall(
      callId: fields[0] as String,
      partnerName: fields[1] as String?,
      partnerRole: fields[2] as String?,
      timestamp: fields[3] as String?,
      durationSeconds: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, RecentCall obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.callId)
      ..writeByte(1)
      ..write(obj.partnerName)
      ..writeByte(2)
      ..write(obj.partnerRole)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.durationSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentCallAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
