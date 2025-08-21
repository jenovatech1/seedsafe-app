import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app/view/app.dart';
import 'core/di/service_locator.dart';
import 'core/security/security_service.dart';
import 'features/home/models/seed_phrase_model.dart';
import 'features/home/models/secure_note_model.dart';
import 'features/home/models/password_item_model.dart';

Future<void> main() async {
  // Simpan instance WidgetsBinding
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Beritahu splash screen untuk tetap tampil
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Hive.initFlutter();
  Hive.registerAdapter(SeedPhraseAdapter());
  Hive.registerAdapter(SecureNoteAdapter());
  Hive.registerAdapter(PasswordItemAdapter());
  await setupLocator();

  final securityService = sl<SecurityService>();
  final bool isVaultCreated = await securityService.isVaultCreated();

  // SEMUA SETUP SELESAI, HAPUS SPLASH SCREEN
  // Kita beri jeda sedikit agar transisi mulus
  await Future.delayed(const Duration(milliseconds: 200));
  FlutterNativeSplash.remove();
  runApp(App(isVaultCreated: isVaultCreated));
}
