import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';
import '../models/secure_note_model.dart';

Future<void> showAddNoteSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const AddNoteSheet(),
  );
}

class AddNoteSheet extends StatefulWidget {
  const AddNoteSheet({super.key});

  @override
  State<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<AddNoteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final s = sl<SecurityService>();
      final enc = await s.encrypt(_noteController.text.trim());

      final note = SecureNote()
        ..label = _labelController.text.trim()
        ..encryptedNote = enc;

      final box = Hive.box<SecureNote>('note_box');
      await box.add(note);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error saving note: $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Note',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Label cannot be empty'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Note'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Note cannot be empty'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : const Text('Save Securely'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
