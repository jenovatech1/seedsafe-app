import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/password_item_model.dart';

import '../../../shared/utils/reauth.dart';
import '../../../shared/widgets/progress_dialog.dart';
import '../../../shared/utils/sensitive_autolock_mixin.dart';
import '../../../shared/widgets/secure_page_guard.dart';

class PasswordDetailPage extends StatefulWidget {
  const PasswordDetailPage({
    super.key,
    required this.label,
    required this.username,
    required this.decryptedPassword,
    required this.itemKey,
  });

  final String label;
  final String? username;
  final String decryptedPassword;
  final dynamic itemKey;

  @override
  State<PasswordDetailPage> createState() => _PasswordDetailPageState();
}

class _PasswordDetailPageState extends State<PasswordDetailPage>
    with WidgetsBindingObserver, SensitiveAutoLock<PasswordDetailPage> {
  Future<void> _confirmAndDelete() async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete password?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || sure != true) return;

    final ok = await ensureUnlocked(context, purpose: 'Delete Password');
    if (!ok || !mounted) return;

    showSimulatedProgressDialog(
      context,
      title: 'Deleting…',
      subtitle: 'Please wait',
    );

    try {
      final box = Hive.box<PasswordItem>('password_box');
      await box.delete(widget.itemKey);
    } finally {
      if (mounted) {
        forceCloseProgressDialog(context);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SecurePageGuard(
      child: PopScope<bool>(
        canPop: false, // kita kontrol pop agar bisa kirim result=true ke caller
        onPopInvokedWithResult: (didPop, bool? result) {
          if (didPop) return;
          Navigator.of(context).pop(false);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.label),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          body: SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.username != null &&
                      widget.username!.isNotEmpty) ...[
                    const Text(
                      'Username',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.username!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Password',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    widget.decryptedPassword,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.decryptedPassword),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _confirmAndDelete,
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
