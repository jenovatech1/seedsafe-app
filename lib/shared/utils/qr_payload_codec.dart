import 'dart:convert';

class QrPayloadCodec {
  static const header = 'SSV1|'; // SeedSafe Version 1
  static const maxQrChars = 1800; // batas aman satu QR

  static String encode(String cipher) {
    // cipher adalah string base64 (standar) hasil SecurityService.encryptForExport.
    // Kita bungkus lagi ke base64URL supaya aman ditaruh di QR tanpa karakter + /
    final b64url = base64Url.encode(utf8.encode(cipher));
    return '$header$b64url';
  }

  /// Decode wrapper -> balikin STRING base64 cipher aslinya.
  /// Return null jika header salah / payload rusak.
  static String? decode(String text) {
    if (!text.startsWith(header)) return null;
    final raw = text.substring(header.length).trim();
    // 1) Coba base64url (tanpa + /)
    try {
      final bytes = base64Url.decode(_normalizeBase64(raw, isUrl: true));
      return utf8.decode(bytes);
    } catch (_) {
      // 2) Gagal? Coba base64 standar (dengan + /)
      try {
        final bytes = base64.decode(_normalizeBase64(raw, isUrl: false));
        return utf8.decode(bytes);
      } catch (_) {
        return null;
      }
    }
  }

  /// Normalisasi padding dan, jika perlu, konversi url<->standar alphabet.
  static String _normalizeBase64(String s, {required bool isUrl}) {
    var v = s.trim();

    // Jika decoder yang dipakai base64Url, biarkan v apa adanya.
    // Jika decoder base64 standar, mapping '-' '_' -> '+' '/'
    if (!isUrl) {
      v = v.replaceAll('-', '+').replaceAll('_', '/');
    }

    // Tambahkan padding '=' sampai kelipatan 4
    final mod = v.length % 4;
    if (mod == 2) v += '==';
    if (mod == 3) v += '=';
    if (mod == 1) {
      // bentuk aneh, biarkan decoder yang melempar
    }
    return v;
  }

  static bool fitsSingleQr(String payload) => payload.length <= maxQrChars;
}
