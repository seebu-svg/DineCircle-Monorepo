import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/services/qr_studio_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MethodCall? captured;
  String? outcome;
  setUp(() {
    captured = null;
    outcome = 'saved';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(QrStudioExport.channel, (call) async {
          captured = call;
          return outcome;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(QrStudioExport.channel, null),
  );

  test(
    'PNG/PDF and share requests pass the exact captured PNG to native code',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      for (final pdf in [false, true]) {
        for (final share in [false, true]) {
          expect(
            await QrStudioExport.send(
              png: bytes,
              filename: 'venue-qr',
              pdf: pdf,
              share: share,
            ),
            'saved',
          );
          expect(captured!.method, 'export');
          expect(captured!.arguments['png'], bytes);
          expect(captured!.arguments['pdf'], pdf);
          expect(captured!.arguments['share'], share);
        }
      }
    },
  );
  test('native cancellation is not reported as saved', () async {
    outcome = null;
    expect(
      await QrStudioExport.send(
        png: Uint8List(1),
        filename: 'qr',
        pdf: false,
        share: false,
      ),
      isNull,
    );
  });
  test('native errors propagate for screen feedback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          QrStudioExport.channel,
          (_) async => throw PlatformException(code: 'export_failed'),
        );
    expect(
      QrStudioExport.send(
        png: Uint8List(1),
        filename: 'qr',
        pdf: false,
        share: false,
      ),
      throwsA(isA<PlatformException>()),
    );
  });
}
