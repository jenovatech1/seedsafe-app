import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/security/security_service.dart';
import '../widgets/password_prompt_dialog.dart';

/// --- Tracker reauth global (hindari nested prompt berlapis) ---
class ReauthTracker {
  static int _depth = 0;
  static bool get active => _depth > 0;

  static Future<T> scope<T>(Future<T> Function() fn) async {
    _depth++;
    try {
      return await fn();
    } finally {
      _depth = (_depth - 1).clamp(0, 1 << 30);
    }
  }
}

/// Pastikan vault "unlocked".
/// - Coba biometrik dulu jika enabled & device support.
/// - Kalau gagal/tidak tersedia → minta master password.
Future<bool> ensureUnlocked(
  BuildContext context, {
  required String purpose,
}) async {
  return ReauthTracker.scope(() async {
    final s = sl<SecurityService>();

    // 1) Coba biometrik dulu (semua operasi async terjadi di sini)
    try {
      final enabled = await s.isBiometricsEnabled();
      final canUse = enabled ? await s.canUseBiometrics() : false;
      if (enabled && canUse) {
        final ok = await s.unlockWithBiometrics();
        if (ok) return true;
      }
    } catch (_) {
      // abaikan error biometrik → fallback ke password
    }

    // 2) Sebelum pakai context lagi setelah async gap → guard dulu
    if (!context.mounted) return false;

    // 3) Fallback: minta password via dialog
    final pwd = await showPasswordPromptDialog(
      context: context,
      title: 'Confirm to $purpose',
    );
    if (pwd == null || pwd.isEmpty) return false;

    // 4) Verifikasi
    return await s.unlockVault(pwd);
  });
}
