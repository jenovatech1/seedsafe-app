import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class PasswordItem extends HiveObject {
  @HiveField(0)
  late String label;
  @HiveField(1)
  String? username;
  @HiveField(2)
  late String encryptedPassword;
}

class PasswordItemAdapter extends TypeAdapter<PasswordItem> {
  @override
  final int typeId = 2;
  @override
  PasswordItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final obj = PasswordItem()
      ..label = fields[0] as String
      ..username = fields[1] as String?
      ..encryptedPassword = fields[2] as String;
    return obj;
  }
  @override
  void write(BinaryWriter writer, PasswordItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)..write(obj.label)
      ..writeByte(1)..write(obj.username)
      ..writeByte(2)..write(obj.encryptedPassword);
  }
}