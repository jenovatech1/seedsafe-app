// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed_phrase_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SeedPhraseAdapter extends TypeAdapter<SeedPhrase> {
  @override
  final int typeId = 0;

  @override
  SeedPhrase read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SeedPhrase()
      ..label = fields[0] as String
      ..encryptedPhrase = fields[1] as String;
  }

  @override
  void write(BinaryWriter writer, SeedPhrase obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.encryptedPhrase);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeedPhraseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
