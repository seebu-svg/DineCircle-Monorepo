import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/utils/links.dart';
import 'package:partnerapp/widgets/qr_code_view.dart';

/// A printed code that renders as a placeholder is worse than no code at all,
/// so these tests pin the two states the venue QR screen relies on: a real
/// encoder fed the venue link, and a neutral placeholder when the selected venue
/// has no id (never an encoder exception).
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('encodes the venue link with the real QR encoder', (tester) async {
    final link = venuePublicUrl('ven_123');
    await tester.pumpWidget(host(QrCodeView(data: link)));

    // The encoder builds its module matrix during the pump, so a payload it
    // rejects would surface here rather than on a printed card.
    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.widget<QrCodeView>(find.byType(QrCodeView)).data, link);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsNothing);
  });

  testWidgets('stays dark-on-light so a printed card still scans',
      (tester) async {
    await tester.pumpWidget(host(QrCodeView(data: venuePublicUrl('ven_123'))));

    final view = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(view.backgroundColor, Colors.white);
    expect(view.eyeStyle.color, const Color(0xFF0A090C));
    expect(view.dataModuleStyle.color, const Color(0xFF0A090C));
  });

  testWidgets('falls back to a placeholder when there is nothing to encode',
      (tester) async {
    await tester.pumpWidget(host(const QrCodeView(data: '   ')));

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
  });
}
