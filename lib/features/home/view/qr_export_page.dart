import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:seed_safe/shared/utils/qr_payload_codec.dart';
import 'package:seed_safe/shared/widgets/secure_page_guard.dart';

class QrExportPage extends StatefulWidget {
  const QrExportPage({super.key, required this.encryptedData});
  final String encryptedData;

  @override
  State<QrExportPage> createState() => _QrExportPageState();
}

class _QrExportPageState extends State<QrExportPage> {
  final GlobalKey _qrKey = GlobalKey();
  String _saveResult = '';

  // Batas aman agar QR tidak terlalu padat/white-out (silakan sesuaikan)
  static const int kMaxSingleQrChars = QrPayloadCodec.maxQrChars;

  Future<void> _saveQrToGallery() async {
    try {
      // Pastikan frame selesai dirender dulu (menghindari boundary null/kosong)
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (!mounted) return;
        setState(() => _saveResult = '❌ Error: QR not ready to save.');
        return;
      }

      // (Opsional tapi disarankan) minta izin akses galeri
      final granted = await Gal.requestAccess();
      if (granted != true) {
        if (!mounted) return;
        setState(() => _saveResult = '❌ Permission denied to save image.');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (!mounted) return;
        setState(() => _saveResult = '❌ Failed to encode image bytes.');
        return;
      }

      await Gal.putImageBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      setState(() => _saveResult = '✅ QR Code saved to gallery!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveResult = '❌ Error saving QR Code: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.encryptedData.length;
    final tooLarge = len > kMaxSingleQrChars;

    return SecurePageGuard(
      child: PopScope<bool>(
        canPop: false, // kita kontrol pop supaya bisa kirim result=true
        onPopInvokedWithResult: (didPop, bool? result) {
          if (didPop) return; // sudah dipop oleh sistem
          Navigator.of(context).pop(true); // kirim result ke caller
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Exported Vault QR Code'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tooLarge) ...[
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 72,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Data terlalu besar untuk 1 QR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ukuran data: $len karakter\nBatas aman: $kMaxSingleQrChars karakter',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kurangi jumlah item atau gunakan mode Multi-QR (akan tersedia).',
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white, // kontras penting untuk scanner
                        padding: const EdgeInsets.all(16),
                        child: QrImageView(
                          data: widget.encryptedData,
                          version: QrVersions.auto,
                          size: 360,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.L,
                          gapless: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'IMPORTANT!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Store this QR code securely OFFLINE. Anyone with this code and your Master Password can access your funds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: tooLarge ? null : _saveQrToGallery,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      tooLarge ? 'Cannot Save (Too Large)' : 'Save to Gallery',
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  if (_saveResult.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _saveResult,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _saveResult.startsWith('✅')
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),
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
