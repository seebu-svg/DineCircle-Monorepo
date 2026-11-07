// Run with flutter_tester after compiling with Flutter's frontend_server.
// This device-independent smoke check captures each template at two text scales.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/widgets/qr_studio_card.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = errors.add;
  final directory = Directory('/tmp/dinecircle-qr-verification')
    ..createSync(recursive: true);
  for (final scale in [1.0, 2.0]) {
    for (final style in QrCardStyle.values) {
      final key = GlobalKey();
      const venue = Venue(
        id: 'ven_123',
        name:
            'Sea & Salt: The Restaurant and Café with a Beautifully Long Name',
        cuisines: ['Mediterranean', 'Contemporary'],
      );
      runApp(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: key,
                      child: QrStudioCard(venue: venue, style: style),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await binding.endOfFrame;
      await binding.endOfFrame;
      if (errors.isNotEmpty) {
        throw StateError(errors.map((e) => e.exceptionAsString()).join('\n'));
      }
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: 1500 / boundary.size.width,
      );
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final stem = '${style.name}-${scale.toInt()}';
        File('${directory.path}/$stem.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        stdout.writeln(
          'Rendered $stem: ${image.width} × ${image.height}; no layout errors',
        );
      } finally {
        image.dispose();
      }
    }
  }
  exit(0);
}
