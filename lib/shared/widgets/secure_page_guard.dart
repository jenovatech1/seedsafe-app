import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../shared/feature_flags.dart'; // sesuaikan relative path bila perlu

class SecurePageGuard extends StatefulWidget {
  const SecurePageGuard({super.key, required this.child, bool? enabled})
    : enabled = enabled ?? FeatureGate.isPro;

  final Widget child;
  final bool enabled;

  @override
  State<SecurePageGuard> createState() => _SecurePageGuardState();
}

class _SecurePageGuardState extends State<SecurePageGuard>
    with WidgetsBindingObserver {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyProtection();
  }

  Future<void> _applyProtection() async {
    if (!widget.enabled || _active) return;
    try {
      await ScreenProtector.preventScreenshotOn();
      _active = true;
    } catch (e) {
      debugPrint('[SecurePageGuard] enable failed: $e');
    }
  }

  Future<void> _removeProtection() async {
    if (!_active) return;
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint('[SecurePageGuard] disable failed: $e');
    } finally {
      _active = false;
    }
  }

  @override
  void didUpdateWidget(covariant SecurePageGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _applyProtection();
      } else {
        _removeProtection();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    if (state == AppLifecycleState.resumed) {
      _applyProtection(); // re-apply kalau sempat dilepas OS
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeProtection(); // best-effort supaya halaman lain tidak ikut terkunci
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
