import 'package:seed_safe/shared/utils/qr_payload_codec.dart';

const bool kPro = bool.fromEnvironment('PRO', defaultValue: false);

class FeatureGate {
  static const bool isPro = bool.fromEnvironment('IS_PRO', defaultValue: false);

  // Free: tidak ada export apapun
  static const bool canExportQr = isPro;
  static const bool canExportFile = isPro;
  static const bool canFingerPrint = isPro;

  // Batas QR tetap
  static int get maxQrChars => QrPayloadCodec.maxQrChars;
}
