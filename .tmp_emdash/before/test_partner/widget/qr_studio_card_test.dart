import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/utils/links.dart';
import 'package:partnerapp/widgets/qr_code_view.dart';
import 'package:partnerapp/widgets/qr_studio_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  for (final style in QrCardStyle.values) {
    testWidgets('${style.label}: real identity, same URL, full quiet zone', (
      tester,
    ) async {
      const venue = Venue(
        id: 'v/123',
        name: 'A very long restaurant name with a café and bakery by the sea',
        cuisines: ['Mediterranean'],
      );
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QrStudioCard(venue: venue, style: style),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(venue.name), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Powered by DineCircle'), findsOneWidget);
      final qr = tester.widget<QrCodeView>(find.byType(QrCodeView));
      expect(qr.data, venuePublicUrl(venue.id));
      final view = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(view.eyeStyle.color, Colors.black);
      expect(view.dataModuleStyle.color, Colors.black);
      expect(view.backgroundColor, Colors.white);
      final modules = QrValidator.validate(data: qr.data).qrCode!.moduleCount;
      final padding = (qr.size - view.size!) / 2;
      expect(padding, closeTo(4 * view.size! / modules, 0.001));
    });
  }
}
