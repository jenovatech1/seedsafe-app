import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/di/service_locator.dart';
import '../../core/security/security_service.dart';
import '../../features/home/models/seed_phrase_model.dart';
import '../../features/home/models/secure_note_model.dart';
import '../../features/home/models/password_item_model.dart';
import '../utils/qr_payload_codec.dart';
import '../widgets/password_prompt_dialog.dart';

/// Start flow: pilih file → validasi → minta password → decrypt → merge ke vault.
Future<void> startImportFromFile(BuildContext context) async {
  // Simpan referensi yang aman sebelum async call
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);

  // 1) Pick file .ssv / .txt
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['ssv', 'txt'],
    withReadStream: false,
  );
  if (result == null) return;

  final path = result.files.single.path;
  if (path == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No file path returned.')),
    );
    return;
  }

  // 2) Baca isi file
  String rawText;
  try {
    rawText = await File(path).readAsString();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Failed to read file: $e')));
    return;
  }

  // 3) Ambil base64 cipher dari konten (support SSV1| wrapper)
  final cipherBase64 = _extractBase64CipherFromString(rawText);
  if (cipherBase64 == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'This file is not recognized as a SeedSafe backup (or data is truncated).',
        ),
      ),
    );
    return;
  }

  // 4) Minta password (pastikan context masih mounted)
  if (!context.mounted) return;
  final password = await showPasswordPromptDialog(
    context: context,
    title: 'Enter Master Password for Import',
  );
  if (password == null || password.isEmpty) return;

  // 5) Decrypt json → merge ke vault
  try {
    final s = sl<SecurityService>();

    // Decrypt backup
    final jsonString = await s.decryptForImport(
      password: password,
      encryptedBase64: cipherBase64,
    );

    // Pastikan vault aktif
    if (await s.isVaultCreated() == false) {
      await s.createVault(password);
    } else {
      final ok = await s.unlockVault(password);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not unlock existing vault.')),
        );
        return;
      }
    }

    // Parse JSON
    final decoded = jsonDecode(jsonString);
    List phrases = [];
    List notes = [];
    List passwords = [];

    if (decoded is List) {
      // legacy: hanya phrases
      phrases = decoded;
    } else if (decoded is Map) {
      phrases = List.from(decoded['phrases'] ?? const []);
      notes = List.from(decoded['notes'] ?? const []);
      passwords = List.from(decoded['passwords'] ?? const []);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unsupported backup format.')),
      );
      return;
    }

    // Merge ke Hive
    await _mergeToHive(
      phrases: phrases,
      notes: notes,
      passwords: passwords,
      security: s,
    );

    // Sukses → kembali ke home + toast
    if (context.mounted) {
      nav.pushNamedAndRemoveUntil('/home', (r) => false);
      messenger.showSnackBar(const SnackBar(content: Text('Import complete.')));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

/// Ekstrak base64 cipher dari string file (mendukung SSV1| wrapper).
/// Return null kalau bukan base64 yang valid (minimal 28 byte: 16 salt + 12 nonce + cipher).
String? _extractBase64CipherFromString(String raw) {
  final s = raw.trim();
  // 1) Unwrap kalau format kita
  String inner = s;
  try {
    final decoded = QrPayloadCodec.decode(s);
    if (decoded != null && decoded.isNotEmpty) inner = decoded;
  } catch (_) {
    // biarkan fallback ke s
  }

  // 2) Validasi base64 + panjang minimal
  try {
    final bytes = base64.decode(inner.trim());
    if (bytes.length < 28) return null;
    return inner.trim();
  } catch (_) {
    return null;
  }
}

/// Merge data ter-decrypt ke Hive (terenkripsi ulang pakai key aktif).
Future<void> _mergeToHive({
  required List phrases,
  required List notes,
  required List passwords,
  required SecurityService security,
}) async {
  final phraseBox = Hive.box<SeedPhrase>('seed_phrase_box');
  final noteBox = Hive.box<SecureNote>('note_box');
  final pwBox = Hive.box<PasswordItem>('password_box');

  final phraseLabels = phraseBox.values
      .map((e) => e.label.toLowerCase())
      .toSet();
  final noteLabels = noteBox.values.map((e) => e.label.toLowerCase()).toSet();
  final pwLabels = pwBox.values.map((e) => e.label.toLowerCase()).toSet();

  String uniqueLabel(Set<String> existing, String base, String fallback) {
    var safeBase = (base.isEmpty ? fallback : base).trim();
    var name = safeBase;
    var i = 1;
    while (existing.contains(name.toLowerCase())) {
      i++;
      name = '$safeBase ($i)';
    }
    existing.add(name.toLowerCase());
    return name;
  }

  // phrases
  for (final item in phrases) {
    final label = uniqueLabel(
      phraseLabels,
      (item['label'] as String?)?.trim() ?? '',
      'Imported Phrase',
    );
    final phrasePlain = (item['phrase'] as String?)?.trim() ?? '';
    if (phrasePlain.isEmpty) continue;

    final enc = await security.encrypt(phrasePlain);
    final sp = SeedPhrase()
      ..label = label
      ..encryptedPhrase = enc;
    await phraseBox.add(sp);
  }

  // notes
  for (final item in notes) {
    final label = uniqueLabel(
      noteLabels,
      (item['label'] as String?)?.trim() ?? '',
      'Imported Note',
    );
    final notePlain = (item['note'] as String?)?.trim() ?? '';
    if (notePlain.isEmpty) continue;

    final enc = await security.encrypt(notePlain);
    final n = SecureNote()
      ..label = label
      ..encryptedNote = enc;
    await noteBox.add(n);
  }

  // passwords
  for (final item in passwords) {
    final label = uniqueLabel(
      pwLabels,
      (item['label'] as String?)?.trim() ?? '',
      'Imported Account',
    );
    final username = (item['username'] as String?)?.trim();
    final passPlain = (item['password'] as String?)?.trim() ?? '';
    if (passPlain.isEmpty) continue;

    final enc = await security.encrypt(passPlain);
    final p = PasswordItem()
      ..label = label
      ..username = (username?.isEmpty ?? true) ? null : username
      ..encryptedPassword = enc;
    await pwBox.add(p);
  }
}
