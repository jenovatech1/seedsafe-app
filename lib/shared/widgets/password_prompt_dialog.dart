import 'package:flutter/material.dart';

Future<String?> showPasswordPromptDialog({
  required BuildContext context,
  String title = 'Enter Master Password',
}) {
  final controller = TextEditingController();
  bool obscure = true;

  return showDialog<String>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (dialogCtx, setState) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              obscureText: obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Master Password',
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              onSubmitted: (_) =>
                  Navigator.of(dialogCtx).pop(controller.text.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogCtx).pop(controller.text.trim()),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );
}
