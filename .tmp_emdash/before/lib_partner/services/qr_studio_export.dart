import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter's SDK channel bridges the OS document picker, PDF renderer and share
/// sheet. No storage permissions or third-party plugin dependencies are needed.
class QrStudioExport {
  static const channel = MethodChannel('com.dinecircle.partnerapp/qr_studio');

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Null means cancelled. The native side only returns saved after completion.
  static Future<String?> send({
    required Uint8List png,
    required String filename,
    required bool pdf,
    required bool share,
  }) => channel.invokeMethod<String>('export', {
    'png': png,
    'filename': filename,
    'pdf': pdf,
    'share': share,
  });
}
