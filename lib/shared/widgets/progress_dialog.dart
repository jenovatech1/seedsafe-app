// lib/shared/widgets/progress_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';

bool _progressDialogOpen = false;

/// Dialog progress “simulasi” (indeterminate)
Future<void> showSimulatedProgressDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
}) {
  _progressDialogOpen = true;
  return showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _SimulatedProgress(title: title, subtitle: subtitle),
  ).whenComplete(() {
    _progressDialogOpen = false;
  });
}

/// Tutup dialog progress **seketika** (sinkron) dan tunggu 1 microtask
Future<void> closeProgressDialogNow(BuildContext context) async {
  if (!_progressDialogOpen) return;
  _progressDialogOpen = false;
  final nav = Navigator.maybeOf(context, rootNavigator: true);
  if (nav == null) return;
  try {
    nav.pop(); // tutup dialog sekarang
  } catch (_) {}
  // beri kesempatan route stack flush dulu
  await Future<void>.delayed(Duration.zero);
}

/// Versi aman global (tetap ada, menutup di frame berikutnya)
void forceCloseProgressDialog(BuildContext context) {
  if (!_progressDialogOpen) return;
  _progressDialogOpen = false;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final nav = Navigator.maybeOf(context, rootNavigator: true);
    if (nav == null) return;
    try {
      nav.pop();
    } catch (_) {}
  });
}

class _SimulatedProgress extends StatefulWidget {
  final String title;
  final String? subtitle;
  const _SimulatedProgress({required this.title, this.subtitle});

  @override
  State<_SimulatedProgress> createState() => _SimulatedProgressState();
}

class _SimulatedProgressState extends State<_SimulatedProgress> {
  double _v = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        if (_v < 0.92) _v += 0.02;
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _v),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(_v * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay deterministik dipakai di QR import (tanpa perubahan)
class DeterminateOverlay extends StatelessWidget {
  final double progress; // 0..1
  final String title;
  final String? subtitle;
  const DeterminateOverlay({
    super.key,
    required this.progress,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF000000).withValues(alpha: 0.7),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
