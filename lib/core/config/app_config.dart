class AppConfig {
  // set via dart-define saat build
  static const bool isPremiumBuild = bool.fromEnvironment(
    'IS_PREMIUM',
    defaultValue: true, // Play build = true
  );

  // Gate per fitur
  static const bool enableQrExport = isPremiumBuild;
  static const bool enableQrImport = isPremiumBuild;
  static const bool enableFileExport = isPremiumBuild; // nanti
  static const bool enableFileImport = isPremiumBuild; // nanti
  static const bool enableBiometrics =
      true; // saran: tetap aktif di free (keamanan dasar)
}
