import 'package:flutter/material.dart';
import '../../features/onboarding/view/onboarding_page.dart';
import '../../features/vault_setup/view/create_password_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/restore_vault/view/qr_scanner_page.dart';
import '../../features/unlock/view/unlock_page.dart';
import '../../shared/pages/about_page.dart';

class App extends StatelessWidget {
  const App({super.key, required this.isVaultCreated});
  final bool isVaultCreated;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF39b54a);
    const darkBackgroundColor = Color(0xFF121212);
    return MaterialApp(
      title: 'SeedSafe',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackgroundColor,
        primaryColor: primaryColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColor,
          surface: Color(0xFF1E1E1E), // Warna untuk card/dialog
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white, // Warna teks di tombol
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackgroundColor,
          elevation: 0,
        ),
      ),
      // Mendefinisikan rute/halaman aplikasi kita
      initialRoute: isVaultCreated ? '/unlock' : '/',
      routes: {
        '/': (context) => const OnboardingPage(),
        '/unlock': (context) => const UnlockPage(),
        '/create-password': (context) => const CreatePasswordPage(),
        '/home': (context) => const HomePage(),
        '/restore': (context) => const QrScannerPage(),
        '/about': (_) => const AboutPage(),
      },
    );
  }
}
