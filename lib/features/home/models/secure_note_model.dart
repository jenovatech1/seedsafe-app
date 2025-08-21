import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class SecureNote extends HiveObject {
  @HiveField(0)
  late String label;
  @HiveField(1)
  late String encryptedNote;
}

class SecureNoteAdapter extends TypeAdapter<SecureNote> {
  @override
  final int typeId = 1;
  @override
  SecureNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final obj = SecureNote()
      ..label = fields[0] as String
      ..encryptedNote = fields[1] as String;
    return obj;
  }
  @override
  void write(BinaryWriter writer, SecureNote obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)..write(obj.label)
      ..writeByte(1)..write(obj.encryptedNote);
  }
}