import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';
import '../models/password_item_model.dart';

Future<void> showAddPasswordSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const AddPasswordSheet(),
  );
}

class AddPasswordSheet extends StatefulWidget {
  const AddPasswordSheet({super.key});

  @override
  State<AddPasswordSheet> createState() => _AddPasswordSheetState();
}

class _AddPasswordSheetState extends State<AddPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final s = sl<SecurityService>();
      final enc = await s.encrypt(_passwordController.text.trim());

      final item = PasswordItem()
        ..label = _labelController.text.trim()
        ..username = _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim()
        ..encryptedPassword = enc;

      final box = Hive.box<PasswordItem>('password_box');
      await box.add(item);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error saving password: $e');
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
              'Add Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (e.g., Email, Bank)',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Label cannot be empty'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Password cannot be empty'
                  : null,
              obscureText: true,
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
