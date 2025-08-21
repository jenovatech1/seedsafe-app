# SeedSafe (Flutter)

Offline seed phrase manager — **100% offline, open-source**.  
- AES-256-GCM encryption  
- PBKDF2-HMAC-SHA256 key derivation  
- Biometric unlock  
- Encrypted export: **SSV1 QR** / **.ssv** (interoperable with the web Offline Recovery Tool)

## Build (Android)
```bash
flutter pub get
flutter build apk --release
