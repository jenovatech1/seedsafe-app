import 'package:hive/hive.dart';

// part 'namafile.g.dart' akan di-generate oleh build_runner
part 'seed_phrase_model.g.dart';

@HiveType(typeId: 0) // typeId harus unik untuk setiap model
class SeedPhrase extends HiveObject {
  // Kita tidak perlu ID, karena Hive akan memberikannya secara otomatis

  @HiveField(0) // Index field juga harus unik per model
  late String label;

  @HiveField(1)
  late String encryptedPhrase; // Kita hanya menyimpan versi terenkripsi
}
