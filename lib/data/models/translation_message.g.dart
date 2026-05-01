// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranslationMessageAdapter extends TypeAdapter<TranslationMessage> {
  @override
  final int typeId = 0;

  @override
  TranslationMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranslationMessage(
      id: fields[0] as String?,
      text: fields[1] as String,
      source: fields[2] as String,
      language: fields[3] as String,
      gifKey: fields[4] as String?,
      timestamp: fields[5] as String?,
      fromPeer: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TranslationMessage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.language)
      ..writeByte(4)
      ..write(obj.gifKey)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.fromPeer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
