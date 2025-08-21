import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:local_auth/local_auth.dart';

// --- FUNGSI TOP-LEVEL UNTUK ISOLATE ---
Uint8List _deriveKeyIsolate(Map<String, dynamic> params) {
  final password = params['password'] as String;
  final salt = params['salt'] as Uint8List;
  final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  pbkdf2.init(Pbkdf2Parameters(salt, 100000, 32));
  return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
}

Uint8List _encryptRawIsolate(Map<String, dynamic> params) {
  final plainText = params['plainText'] as String;
  final key = params['key'] as Uint8List;
  final iv = params['iv'] as Uint8List;
  final gcm = GCMBlockCipher(AESEngine());
  gcm.init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final out = gcm.process(Uint8List.fromList(utf8.encode(plainText)));
  return Uint8List.fromList(out);
}

Uint8List _decryptRawIsolate(Map<String, dynamic> params) {
  final cipher = params['cipher'] as Uint8List;
  final key = params['key'] as Uint8List;
  final iv = params['iv'] as Uint8List;
  final gcm = GCMBlockCipher(AESEngine());
  gcm.init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final out = gcm.process(cipher);
  return Uint8List.fromList(out);
}

String _encryptIsolate(Map<String, dynamic> params) {
  final plainText = params['plainText'] as String;
  final key = params['key'] as Uint8List;
  final iv = params['iv'] as Uint8List;
  final gcm = GCMBlockCipher(AESEngine());
  gcm.init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final encryptedBytes = gcm.process(utf8.encode(plainText));
  return base64.encode(encryptedBytes);
}

String _decryptIsolate(Map<String, dynamic> params) {
  final encryptedBase64 = params['encryptedBase64'] as String;
  final key = params['key'] as Uint8List;
  final iv = params['iv'] as Uint8List;
  final gcm = GCMBlockCipher(AESEngine());
  gcm.init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final decryptedBytes = gcm.process(base64.decode(encryptedBase64));
  return utf8.decode(decryptedBytes);
}

String _decryptForImportIsolate(Map<String, dynamic> params) {
  final password = params['password'] as String;
  final encryptedBase64 = params['encryptedBase64'] as String;

  final raw = encryptedBase64.trim();
  Uint8List combined;
  try {
    combined = base64.decode(raw);
  } catch (e) {
    throw FormatException('Backup payload is not valid Base64: $e');
  }

  if (combined.length < 28) {
    throw FormatException(
      'Backup payload too short (${combined.length} bytes). Expected >= 28.',
    );
  }
  final salt = combined.sublist(0, 16);
  final nonce = combined.sublist(16, 28);
  final encryptedBytes = combined.sublist(28);

  final key = _deriveKeyIsolate({'password': password, 'salt': salt});
  final gcm = GCMBlockCipher(AESEngine());
  gcm.init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
  final decryptedBytes = gcm.process(encryptedBytes);
  return utf8.decode(decryptedBytes);
}
// --- END ISOLATE ---

const kPbkdf2Salt = 'pbkdf2_salt';
const kAesIv = 'aes_iv';
const kVerificationValue = 'verification_value';

const kBiometricKey = 'biometric_key';
const kBiometricIv = 'biometric_iv';

class SecurityService {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  Uint8List? _dataEncryptionKey;
  Uint8List? _iv;

  SecurityService({required FlutterSecureStorage secureStorage})
    : _secureStorage = secureStorage;

  // secure storage options — HARUS konsisten untuk read/write/delete
  static const AndroidOptions _ao = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );
  static const IOSOptions _io = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  Future<String?> _read(String key) =>
      _secureStorage.read(key: key, aOptions: _ao, iOptions: _io);
  Future<void> _write(String key, String value) => _secureStorage.write(
    key: key,
    value: value,
    aOptions: _ao,
    iOptions: _io,
  );
  Future<void> _delete(String key) =>
      _secureStorage.delete(key: key, aOptions: _ao, iOptions: _io);

  Uint8List _getSecureRandomBytes(int length) {
    final secureRandom = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List<int>.generate(32, (_) => Random.secure().nextInt(255)),
          ),
        ),
      );
    return secureRandom.nextBytes(length);
  }

  Future<Uint8List> _deriveKey(String password, Uint8List salt) async {
    return compute(_deriveKeyIsolate, {'password': password, 'salt': salt});
  }

  // ===== Vault lifecycle =====
  Future<void> createVault(String password) async {
    final salt = _getSecureRandomBytes(16);
    final iv = _getSecureRandomBytes(12);
    _iv = iv;
    _dataEncryptionKey = await _deriveKey(password, salt);

    await _write(kAesIv, base64.encode(iv));
    await _write(kPbkdf2Salt, base64.encode(salt));

    final verificationData = await encrypt('ok'); // pakai key+iv aktif
    await _write(kVerificationValue, verificationData);
  }

  Future<bool> unlockVault(String password) async {
    final saltBase64 = await _read(kPbkdf2Salt);
    final verificationDataBase64 = await _read(kVerificationValue);
    final ivBase64 = await _read(kAesIv);
    if (saltBase64 == null ||
        verificationDataBase64 == null ||
        ivBase64 == null) {
      return false;
    }

    final salt = base64.decode(saltBase64);
    final iv = base64.decode(ivBase64);
    final key = await _deriveKey(password, salt);

    _iv = iv;
    _dataEncryptionKey = key;

    try {
      final decryptedVerification = await decrypt(verificationDataBase64);
      return decryptedVerification == 'ok';
    } catch (_) {
      lockVault();
      return false;
    }
  }

  Future<String> encrypt(String plainText) async {
    if (_dataEncryptionKey == null) {
      throw Exception('Vault is locked.');
    }
    final nonce = _getSecureRandomBytes(12);

    // Pastikan return bertipe Uint8List, bukan dynamic
    final Uint8List cipher = await compute<Map<String, dynamic>, Uint8List>(
      _encryptRawIsolate,
      {'plainText': plainText, 'key': _dataEncryptionKey!, 'iv': nonce},
    );

    // Framing v1: 0x01 | nonce(12) | cipher
    final int totalLen = 1 + nonce.length + cipher.length;
    final framed = Uint8List(totalLen);
    framed[0] = 0x01;
    framed.setRange(1, 13, nonce);
    framed.setRange(13, 13 + cipher.length, cipher);

    return base64.encode(framed);
  }

  Future<String> decrypt(String encryptedBase64) async {
    if (_dataEncryptionKey == null) {
      throw Exception('Vault is locked.');
    }
    final raw = base64.decode(encryptedBase64);

    // v1? header 0x01
    if (raw.isNotEmpty && raw[0] == 0x01 && raw.length > 13) {
      final nonce = raw.sublist(1, 13);
      final cipher = raw.sublist(13);

      final Uint8List plainBytes =
          await compute<Map<String, dynamic>, Uint8List>(_decryptRawIsolate, {
            'cipher': cipher,
            'key': _dataEncryptionKey!,
            'iv': nonce,
          });
      return utf8.decode(plainBytes);
    }

    // LEGACY fallback: IV global
    if (_iv == null) {
      throw Exception('Legacy data requires vault IV, but IV is null.');
    }
    return compute(_decryptIsolate, {
      'encryptedBase64': encryptedBase64,
      'key': _dataEncryptionKey!,
      'iv': _iv!,
    });
  }

  Future<String> encryptForExport(String plainJson) async {
    if (_dataEncryptionKey == null) throw Exception('Vault is locked.');
    final saltBase64 = await _read(kPbkdf2Salt);
    if (saltBase64 == null) throw Exception('Salt not found for export.');

    final nonce = _getSecureRandomBytes(12);
    final encryptedContent = await compute(_encryptIsolate, {
      'plainText': plainJson,
      'key': _dataEncryptionKey!,
      'iv': nonce,
    });
    final combined =
        base64.decode(saltBase64) + nonce + base64.decode(encryptedContent);
    return base64.encode(combined);
  }

  Future<String> decryptForImport({
    required String password,
    required String encryptedBase64,
  }) async {
    return compute(_decryptForImportIsolate, {
      'password': password,
      'encryptedBase64': encryptedBase64,
    });
  }

  Future<bool> isVaultCreated() async => (await _read(kPbkdf2Salt)) != null;

  void lockVault() {
    _dataEncryptionKey = null;
    _iv = null;
  }

  // ===== Biometrics (aman & sinkron) =====
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() async {
    final key = await _read(kBiometricKey); // <- konsisten options
    final iv = await _read(kBiometricIv);
    return key != null && iv != null;
  }

  /// Simpan kunci sesi saat ini ke secure storage (biometrik tidak mengubah salt/verifier).
  Future<bool> enableBiometrics() async {
    if (_dataEncryptionKey == null || _iv == null) {
      throw Exception('Unlock vault first to enable biometrics.');
    }
    if (!await canUseBiometrics()) return false;

    final ok = await _localAuth.authenticate(
      localizedReason: 'Enable biometric unlock',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (!ok) return false;

    await _write(kBiometricKey, base64.encode(_dataEncryptionKey!));
    await _write(kBiometricIv, base64.encode(_iv!));
    return true;
  }

  Future<void> disableBiometrics() async {
    await _delete(kBiometricKey);
    await _delete(kBiometricIv);
  }

  Future<bool> unlockWithBiometrics() async {
    if (!await canUseBiometrics()) return false;

    final ok = await _localAuth.authenticate(
      localizedReason: 'Unlock with biometrics',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (!ok) return false;

    final key64 = await _read(kBiometricKey);
    final iv64 = await _read(kBiometricIv);
    if (key64 == null || iv64 == null) return false;

    _dataEncryptionKey = base64.decode(key64);
    _iv = base64.decode(iv64);
    return true;
  }
}
