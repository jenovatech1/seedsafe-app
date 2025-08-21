import 'package:hive_flutter/hive_flutter.dart';

import '../../features/home/models/seed_phrase_model.dart';
import '../../features/home/models/secure_note_model.dart';
import '../../features/home/models/password_item_model.dart';

// Nama untuk "box" atau tabel kita di Hive
const kSeedPhraseBox = 'seed_phrase_box';
const kNoteBox = 'note_box';
const kPasswordBox = 'password_box';

class StorageService {
  // Metode untuk menginisialisasi dan membuka box Hive kita.
  // Ini harus dipanggil saat aplikasi pertama kali dimulai.
  Future<void> init() async {
    // Membuka box utama kita untuk menyimpan seed phrase.
    // Data di sini akan kita simpan dalam bentuk terenkripsi.
    await Hive.openBox<SeedPhrase>(kSeedPhraseBox);
    await Hive.openBox<SecureNote>(kNoteBox);
    await Hive.openBox<PasswordItem>(kPasswordBox);
  }

  Future<void> addSeedPhrase(SeedPhrase phrase) async {
    final box = Hive.box<SeedPhrase>(kSeedPhraseBox);
    await box.add(phrase);
  }
}
