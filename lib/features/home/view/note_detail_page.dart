import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/secure_note_model.dart';

import '../../../shared/utils/reauth.dart';
import '../../../shared/widgets/progress_dialog.dart';
import '../../../shared/utils/sensitive_autolock_mixin.dart';
import '../../../shared/widgets/secure_page_guard.dart';

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({
    super.key,
    required this.label,
    required this.decryptedNote,
    required this.noteKey,
  });

  final String label;
  final String decryptedNote;
  final dynamic noteKey;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage>
    with WidgetsBindingObserver, SensitiveAutoLock<NoteDetailPage> {
  Future<void> _confirmAndDelete() async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete note?'),
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

    // Re-auth
    final ok = await ensureUnlocked(context, purpose: 'Delete Note');
    if (!ok || !mounted) return;

    showSimulatedProgressDialog(
      context,
      title: 'Deleting…',
      subtitle: 'Please wait',
    );

    try {
      final box = Hive.box<SecureNote>('note_box');
      await box.delete(widget.noteKey);
    } finally {
      if (mounted) {
        // Tutup dialog progress sebelum pop
        forceCloseProgressDialog(context);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SecurePageGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.label)),
        body: SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.decryptedNote,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.decryptedNote),
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
    );
  }
}
