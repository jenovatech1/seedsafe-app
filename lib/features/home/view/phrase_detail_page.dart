import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/seed_phrase_model.dart';

import '../../../shared/utils/reauth.dart';
import '../../../shared/widgets/progress_dialog.dart';
import '../../../shared/utils/sensitive_autolock_mixin.dart';
import '../../../shared/widgets/secure_page_guard.dart';

class PhraseDetailPage extends StatefulWidget {
  const PhraseDetailPage({
    super.key,
    required this.label,
    required this.decryptedPhrase,
    required this.phraseKey,
  });

  final String label;
  final String decryptedPhrase;
  final dynamic phraseKey;

  @override
  State<PhraseDetailPage> createState() => _PhraseDetailPageState();
}

class _PhraseDetailPageState extends State<PhraseDetailPage>
    with WidgetsBindingObserver, SensitiveAutoLock<PhraseDetailPage> {
  late final List<String> _words;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _words = widget.decryptedPhrase
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  Future<void> _confirmDelete() async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Phrase?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || didConfirm != true) return;

    final ok = await ensureUnlocked(context, purpose: 'Delete Phrase');
    if (!ok || !mounted) return;

    showSimulatedProgressDialog(
      context,
      title: 'Deleting…',
      subtitle: 'Please wait',
    );
    try {
      final box = Hive.box<SeedPhrase>('seed_phrase_box');
      await box.delete(widget.phraseKey);
    } finally {
      if (mounted) {
        forceCloseProgressDialog(context);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _copyToClipboard(
    String text, {
    String toast = 'Copied to clipboard!',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(toast)));

    // Auto-clear setelah 3 menit, hanya jika clipboard belum berubah
    Future.delayed(const Duration(minutes: 3), () async {
      try {
        final data = await Clipboard.getData('text/plain');
        if (data?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });
  }

  void _toggleObscure() => setState(() => _obscured = !_obscured);

  String get _joined => _words.join(' ');

  @override
  Widget build(BuildContext context) {
    final isValidCount = _words.length == 12 || _words.length == 24;

    return SecurePageGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.label),
          actions: [
            IconButton(
              tooltip: _obscured ? 'Reveal all' : 'Hide all',
              icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
              onPressed: _toggleObscure,
            ),
            IconButton(
              tooltip: 'Delete phrase',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _confirmDelete,
            ),
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Never share your seed phrase. Anyone with these words can access your wallet.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isValidCount
                        ? '${_words.length}-word phrase'
                        : 'Custom phrase (${_words.length} words)',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: GridView.builder(
                    itemCount: _words.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.8,
                        ),
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      final display = _obscured
                          ? '•' * word.length.clamp(4, 8)
                          : word;

                      return InkWell(
                        onTap: () => _copyToClipboard(
                          word,
                          toast: 'Word ${index + 1} copied',
                        ),
                        onLongPress: () {
                          if (_obscured) {
                            final old = _obscured;
                            setState(() => _obscured = false);
                            Future.delayed(const Duration(seconds: 1), () {
                              if (mounted) setState(() => _obscured = old);
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}.',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  display,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    letterSpacing: 0.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.copy,
                                size: 14,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _copyToClipboard(_joined, toast: 'Seed phrase copied'),
                    icon: const Icon(Icons.copy_all),
                    label: const Text('Copy all'),
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFF121212),
      ),
    );
  }
}
