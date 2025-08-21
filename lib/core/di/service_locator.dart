import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../security/security_service.dart';
import '../storage/storage_service.dart';

// Membuat instance global dari GetIt
final sl = GetIt.instance;

// Fungsi untuk setup semua dependensi kita
Future<void> setupLocator() async {
  // EKSTERNAL
  sl.registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage());
  // sl.registerSingleton<Sodium>(await SodiumInit.init()); // <-- HAPUS BARIS INI

  // SERVIS
  sl.registerSingleton<StorageService>(StorageService());
  sl.registerSingleton<SecurityService>(
    SecurityService(
      secureStorage: sl<FlutterSecureStorage>(),
      // sodium: sl<Sodium>(), // <-- HAPUS BARIS INI
    ),
  );

  await sl<StorageService>().init();
}
