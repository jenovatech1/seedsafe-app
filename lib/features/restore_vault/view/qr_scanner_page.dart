import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscan;
import 'package:image/image.dart' as img;
import 'package:zxing2/zxing2.dart' as zxing;
import 'package:zxing2/qrcode.dart' as zq;
import 'dart:io';

import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';
import '../../../shared/widgets/password_prompt_dialog.dart';
import '../../../shared/widgets/progress_dialog.dart';
import '../../home/models/seed_phrase_model.dart';
import '../../home/models/secure_note_model.dart';
import '../../home/models/password_item_model.dart';
import '../../../shared/utils/qr_payload_codec.dart';
import 'package:file_picker/file_picker.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final mscan.MobileScannerController _cameraController =
      mscan.MobileScannerController();
  bool _isProcessing = false;
  double _progress = 0.0;
  String _stage = 'Waiting for QR...';

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  // Unwrap payload format kita; kalau bukan format kita → kembalikan raw (di-trim)
  String? _extractBase64Cipher(String raw, {bool verbose = true}) {
    final s = raw.trim();

    // 1) Coba unwrap format kita
    String inner = s;
    try {
      final decoded = QrPayloadCodec.decode(s);
      if (decoded != null && decoded.isNotEmpty) inner = decoded;
    } catch (_) {
      // biarkan fallback ke s
    }

    // 2) Validasi base64 + panjang minimal 28 byte (salt+nonce+cipher)
    try {
      final bytes = base64.decode(inner.trim());
      if (bytes.length < 28) {
        if (verbose) {
          debugPrint('[QR Import] payload too short: ${bytes.length} bytes');
        }
        return null;
      }
      if (verbose) {
        final cipherLen = bytes.length - 28;
        debugPrint(
          '[QR Import] ok: total=${bytes.length}, salt=16, nonce=12, cipher=$cipherLen',
        );
      }
      return inner;
    } catch (e) {
      if (verbose) {
        debugPrint('[QR Import] base64.decode failed: $e');
      }
      return null;
    }
  }

  Future<void> _restartCameraSafe() async {
    try {
      await _cameraController.start();
    } catch (_) {}
  }

  Future<void> _stopCameraSafe() async {
    try {
      await _cameraController.stop();
    } catch (_) {}
  }

  /// Decode QR dari file gambar menggunakan ZXing2 (lebih toleran dari plugin lama).
  Future<String?> _decodeQrWithZxingFromFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      final w = image.width;
      final h = image.height;

      // Siapkan ARGB untuk ZXing: 0xFFRRGGBB
      final pixels = Int32List(w * h);
      var idx = 0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final px = image.getPixel(x, y); // Pixel (v4)
          final r = px.r.toInt();
          final g = px.g.toInt();
          final b = px.b.toInt();
          pixels[idx++] = (0xFF << 24) | (r << 16) | (g << 8) | b;
        }
      }

      final source = zxing.RGBLuminanceSource(w, h, pixels);
      final binaryBitmap = zxing.BinaryBitmap(zxing.HybridBinarizer(source));
      final reader = zq.QRCodeReader();
      final result = reader.decode(binaryBitmap);

      return result.text;
    } catch (e) {
      debugPrint('[ZXING] decode failed: $e');
      return null;
    }
  }

  Future<void> _pickFromGallery() async {
    final rootCtx = context;
    final picker = ImagePicker();

    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _progress = 0.1;
      _stage = 'Analyzing image...';
    });

    await _stopCameraSafe();

    // --- ZXing path (ganti plugin lama) ---
    final raw = await _decodeQrWithZxingFromFile(file);

    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (rootCtx.mounted) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          const SnackBar(content: Text('No QR code found in that image.')),
        );
      }
      await _restartCameraSafe();
      return;
    }

    final cipherBase64 = _extractBase64Cipher(raw);
    if (cipherBase64 == null) {
      if (mounted) setState(() => _isProcessing = false);
      if (rootCtx.mounted) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          const SnackBar(
            content: Text(
              'QR tidak dikenali sebagai backup SeedSafe atau datanya terpotong.',
            ),
          ),
        );
      }
      await _restartCameraSafe();
      return;
    }

    if (!rootCtx.mounted) return;
    final password = await showPasswordPromptDialog(
      context: rootCtx,
      title: 'Enter Master Password for Import',
    );
    if (password == null || password.isEmpty) {
      if (mounted) setState(() => _isProcessing = false);
      await _restartCameraSafe();
      return;
    }

    await _mergeImport(encrypted: cipherBase64, password: password);
  }

  Future<void> _mergeImport({
    required String encrypted,
    required String password,
  }) async {
    final rootCtx = context;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _progress = 0.15;
        _stage = 'Decrypting backup...';
      });
    }

    try {
      final s = sl<SecurityService>();

      // 1) Decrypt backup
      String jsonString;
      try {
        jsonString = await s.decryptForImport(
          password: password,
          encryptedBase64: encrypted,
        );
      } catch (_) {
        if (mounted) setState(() => _isProcessing = false);
        if (rootCtx.mounted) {
          ScaffoldMessenger.of(rootCtx).showSnackBar(
            const SnackBar(
              content: Text('Wrong password or corrupted backup.'),
            ),
          );
        }
        await _restartCameraSafe();
        return;
      }

      // 2) Pastikan vault aktif
      if (await s.isVaultCreated() == false) {
        await s.createVault(password);
      } else {
        final ok = await s.unlockVault(password);
        if (!ok) {
          if (mounted) setState(() => _isProcessing = false);
          if (rootCtx.mounted) {
            ScaffoldMessenger.of(rootCtx).showSnackBar(
              const SnackBar(content: Text('Could not unlock existing vault.')),
            );
          }
          await _restartCameraSafe();
          return;
        }
      }

      // 3) Parse JSON
      final decoded = jsonDecode(jsonString);
      List phrases = [];
      List notes = [];
      List passwords = [];

      if (decoded is List) {
        phrases = decoded;
      } else if (decoded is Map) {
        phrases = List.from(decoded['phrases'] ?? const []);
        notes = List.from(decoded['notes'] ?? const []);
        passwords = List.from(decoded['passwords'] ?? const []);
      } else {
        throw Exception('Unsupported backup format');
      }

      if (mounted) {
        setState(() {
          _progress = 0.3;
          _stage = 'Merging into vault...';
        });
      }

      final phraseBox = Hive.box<SeedPhrase>('seed_phrase_box');
      final noteBox = Hive.box<SecureNote>('note_box');
      final pwBox = Hive.box<PasswordItem>('password_box');

      // Set label unik per kategori (diupdate tiap add)
      final phraseLabels = phraseBox.values
          .map((e) => e.label.toLowerCase())
          .toSet();
      final noteLabels = noteBox.values
          .map((e) => e.label.toLowerCase())
          .toSet();
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

      // import phrases
      for (final item in phrases) {
        final label = uniqueLabel(
          phraseLabels,
          (item['label'] as String?)?.trim() ?? '',
          'Imported Phrase',
        );
        final phrasePlain = (item['phrase'] as String?)?.trim() ?? '';
        if (phrasePlain.isEmpty) continue;

        final enc = await s.encrypt(phrasePlain);
        final sp = SeedPhrase()
          ..label = label
          ..encryptedPhrase = enc;
        await phraseBox.add(sp);
      }

      // import notes
      for (final item in notes) {
        final label = uniqueLabel(
          noteLabels,
          (item['label'] as String?)?.trim() ?? '',
          'Imported Note',
        );
        final notePlain = (item['note'] as String?)?.trim() ?? '';
        if (notePlain.isEmpty) continue;

        final enc = await s.encrypt(notePlain);
        final n = SecureNote()
          ..label = label
          ..encryptedNote = enc;
        await noteBox.add(n);
      }

      // import passwords
      for (final item in passwords) {
        final label = uniqueLabel(
          pwLabels,
          (item['label'] as String?)?.trim() ?? '',
          'Imported Account',
        );
        final username = (item['username'] as String?)?.trim();
        final passPlain = (item['password'] as String?)?.trim() ?? '';
        if (passPlain.isEmpty) continue;

        final enc = await s.encrypt(passPlain);
        final p = PasswordItem()
          ..label = label
          ..username = (username?.isEmpty ?? true) ? null : username
          ..encryptedPassword = enc;
        await pwBox.add(p);
      }

      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _stage = 'Done';
        _isProcessing = false;
      });

      if (!rootCtx.mounted) return;
      Navigator.of(rootCtx).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _stage = 'Failed';
      });
      final rootCtx = context;
      if (rootCtx.mounted) {
        ScaffoldMessenger.of(
          rootCtx,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
      await _restartCameraSafe();
    }
  }

  Future<void> _pickFromFile() async {
    final rootCtx = context;

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ssv', 'txt'],
        withData: true, // prefer bytes (SAF aman)
      );
      if (res == null) return;

      String raw;
      final f = res.files.single;
      if (f.bytes != null) {
        raw = utf8.decode(f.bytes!);
      } else if (f.path != null) {
        raw = await File(f.path!).readAsString();
      } else {
        throw Exception('Could not read the selected file.');
      }

      final cipherBase64 = _extractBase64Cipher(raw);
      if (cipherBase64 == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File content is not a valid SeedSafe export (maybe truncated).',
            ),
          ),
        );
        return;
      }

      if (!rootCtx.mounted) return;
      final password = await showPasswordPromptDialog(
        context: rootCtx,
        title: 'Enter Master Password for Import',
      );
      if (password == null || password.isEmpty) return;

      if (mounted) {
        setState(() {
          _isProcessing = true;
          _progress = 0.15;
          _stage = 'Decrypting backup...';
        });
      }
      await _mergeImport(encrypted: cipherBase64, password: password);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import from file failed: $e')));
    }
  }

  Future<void> _onDetect(mscan.BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final cipherBase64 = _extractBase64Cipher(raw);
    if (cipherBase64 == null) {
      await _restartCameraSafe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'QR tidak dikenali sebagai backup SeedSafe atau datanya terpotong.',
            ),
          ),
        );
      }
      return;
    }

    final rootCtx = context; // simpan sebelum await
    await _stopCameraSafe();

    if (!rootCtx.mounted) return;
    final password = await showPasswordPromptDialog(
      context: rootCtx,
      title: 'Enter Master Password for Import',
    );
    if (password == null || password.isEmpty) {
      await _restartCameraSafe();
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _progress = 0.15;
        _stage = 'Decrypting backup...';
      });
    }
    await _mergeImport(encrypted: cipherBase64, password: password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore from QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo),
            tooltip: 'Import from Photo',
            onPressed: _pickFromGallery,
          ),
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: 'Import from File',
            onPressed: _pickFromFile,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _cameraController.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          mscan.MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          if (_isProcessing)
            DeterminateOverlay(
              progress: _progress,
              title: 'Importing',
              subtitle: _stage,
            ),
        ],
      ),
    );
  }
}
