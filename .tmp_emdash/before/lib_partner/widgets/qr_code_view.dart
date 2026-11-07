import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_spacing.dart';

/// A real, scannable QR code rendered from an authoritative payload string.
///
/// Backed by the pure-Dart `qr_flutter` encoder — the same one the customer app
/// uses for booking references — so it renders identically in widget tests and
/// on the web build, with no native plugin and nothing to request from the API.
///
/// The code stays dark-on-light even inside the dark theme on purpose: inverted
/// or low-contrast codes are the usual reason a printed card fails to scan.
/// [data] empty means "nothing to encode yet" and falls back to a neutral
/// placeholder rather than letting the encoder throw.
class QrCodeView extends StatelessWidget {
  const QrCodeView({
    super.key,
    required this.data,
    this.size = 200,
    this.foreground = const Color(0xFF0A090C),
    this.background = Colors.white,
    this.semanticsLabel = 'Scannable QR code',
  });

  final String data;
  final double size;
  final Color foreground;
  final Color background;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final empty = data.trim().isEmpty;
    final modules = empty
        ? 21
        : QrValidator.validate(data: data).qrCode?.moduleCount ?? 21;
    // ISO QR quiet zone: four modules on every side at every output size.
    final quietZone = size * 4 / (modules + 8);
    return Semantics(
      label: semanticsLabel,
      value: empty ? 'No link available' : data,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        padding: EdgeInsets.all(quietZone),
        child: empty
            ? Icon(
                Icons.qr_code_2_rounded,
                size: size * 0.6,
                color: foreground.withValues(alpha: 0.25),
              )
            : QrImageView(
                data: data,
                size: size - quietZone * 2,
                version: QrVersions.auto,
                backgroundColor: background,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: foreground,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: foreground,
                ),
                padding: EdgeInsets.zero,
              ),
      ),
    );
  }
}
