import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';

/// Menampilkan dialog untuk membuka vault dan mengembalikan true jika berhasil.
Future<bool> showUnlockDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Enter Master Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final securityService = sl<SecurityService>();
              final success = await securityService.unlockVault(
                passwordController.text,
              );
              if (context.mounted) Navigator.of(context).pop(success);
            },
            child: const Text('Unlock'),
          ),
        ],
      );
    },
  );
  return result ?? false; // Kembalikan false jika dialog ditutup begitu saja
}
