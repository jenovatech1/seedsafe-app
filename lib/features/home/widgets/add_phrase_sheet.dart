import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';
import '../models/seed_phrase_model.dart';

Future<void> showAddPhraseSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const AddPhraseSheet(),
  );
}

class AddPhraseSheet extends StatefulWidget {
  const AddPhraseSheet({super.key});

  @override
  State<AddPhraseSheet> createState() => _AddPhraseSheetState();
}

class _AddPhraseSheetState extends State<AddPhraseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();

  static const int _maxWords = 24;
  int _visibleCount = 12;

  late final List<TextEditingController> _controllers = List.generate(
    _maxWords,
    (_) => TextEditingController(),
  );

  // NEW: fokus per kotak
  late final List<FocusNode> _nodes = List.generate(
    _maxWords,
    (_) => FocusNode(),
  );

  bool _distributing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _nodes) {
      f.dispose();
    }
    super.dispose();
  }

  // Lompat ke index berikutnya (aman)
  void _focusTo(int index) {
    if (index < 0 || index >= _visibleCount) return;
    _nodes[index].requestFocus();
    // letakkan kursor di akhir
    _controllers[index].selection = TextSelection.fromPosition(
      TextPosition(offset: _controllers[index].text.length),
    );
  }

  void _distributeIfNeeded(String value, int index) {
    if (_distributing) return;

    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return;

    _distributing = true;

    // munculkan field tambahan bila perlu (maks 24)
    final need = index + parts.length;
    if (need > _visibleCount) {
      setState(() {
        _visibleCount = need.clamp(12, 24);
      });
    }

    final limit = _visibleCount;
    var i = index;
    for (var p = 0; p < parts.length && i < limit; p++, i++) {
      _controllers[i].text = parts[p];
    }

    // pindah fokus ke field setelah distribusi
    final next = (index + parts.length < limit)
        ? index + parts.length
        : limit - 1;
    _focusTo(next);

    Future.microtask(() => _distributing = false);
  }

  // NEW: handler satu tempat, termasuk “spasi → next”
  void _onChanged(String v, int index) {
    if (_distributing) return;

    // jika ada spasi di tengah (paste) → distribusi
    if (v.contains(' ') && v.trim().split(RegExp(r'\s+')).length > 1) {
      _distributeIfNeeded(v, index);
      return;
    }

    // kalau hanya spasi di akhir → trim & pindah ke field berikutnya
    if (v.endsWith(' ')) {
      _controllers[index].text = v.trim();
      final next = (index + 1 < _visibleCount) ? index + 1 : index;
      _focusTo(next);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final words = _controllers
        .take(_visibleCount)
        .map((c) => c.text.trim())
        .toList();
    if (words.any((w) => w.isEmpty)) {
      setState(() => _error = 'Please fill all the words.');
      return;
    }

    setState(() => _saving = true);
    try {
      final phrase = words.join(' ');
      final s = sl<SecurityService>();
      final enc = await s.encrypt(phrase);

      final sp = SeedPhrase()
        ..label = _labelController.text.trim()
        ..encryptedPhrase = enc;

      final box = Hive.box<SeedPhrase>('seed_phrase_box');
      await box.add(sp);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seed phrase saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error saving phrase: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 12 + insets.bottom, // keyboard-aware
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add New Seed Phrase',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _visibleCount = _visibleCount == 12 ? 24 : 12;
                        });
                        // jaga fokus tetap nyaman
                        _focusTo(0);
                      },
                      child: Text(
                        _visibleCount == 12 ? 'Use 24 words' : 'Use 12 words',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label (e.g., My Wallet)',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Label cannot be empty'
                      : null,
                ),
                const SizedBox(height: 12),

                // GRID (pakai Expanded, tidak shrinkWrap supaya ringan)
                Expanded(
                  child: GridView.builder(
                    itemCount: _visibleCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.6,
                        ),
                    itemBuilder: (context, index) {
                      return TextFormField(
                        controller: _controllers[index],
                        focusNode: _nodes[index], // NEW
                        autofocus: index == 0, // fokus awal ke kotak 1
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          prefixText: '${index + 1}. ',
                          prefixStyle: const TextStyle(color: Colors.white54),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                        onChanged: (v) => _onChanged(v, index), // NEW
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '' : null,
                        onEditingComplete: () {
                          // tombol Next di keyboard
                          final next = (index + 1 < _visibleCount)
                              ? index + 1
                              : index;
                          _focusTo(next);
                        },
                      );
                    },
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                // Tombol aman dari nav bar
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(),
                            )
                          : const Text('Save Securely'),
                    ),
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
