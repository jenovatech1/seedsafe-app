import 'package:flutter/widgets.dart';
import '../../core/di/service_locator.dart';
import '../../core/security/security_service.dart';
import 'reauth.dart';

mixin SensitiveAutoLock<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Jangan kunci ketika reauth/biometric dialog lagi aktif
    if (ReauthTracker.active) return;

    // Kunci hanya saat benar2 ke background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lockNow();
    }
  }

  void _lockNow() {
    if (_navigating || !mounted) return;
    _navigating = true;

    // (opsional) clear clipboard di halaman sensitif – bebas kalau mau
    // Clipboard.setData(const ClipboardData(text: '')).catchError((_) {});

    sl<SecurityService>().lockVault();
    Navigator.of(context).pushNamedAndRemoveUntil('/unlock', (_) => false);
  }
}
