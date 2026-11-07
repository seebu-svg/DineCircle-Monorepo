import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/api/api_exception.dart';

void main() {
  group('ApiException.fromStatus', () {
    test('reads error, code and Zod issues from a JSON error body', () {
      final e = ApiException.fromStatus(422, <String, dynamic>{
        'error': 'Validation failed',
        'code': 'unprocessable',
        'issues': [
          <String, dynamic>{'path': ['gallery', 3], 'message': 'Too long'},
          <String, dynamic>{'path': ['name'], 'message': 'Required'},
        ],
      });
      expect(e.statusCode, 422);
      expect(e.isValidation, isTrue);
      expect(e.code, 'unprocessable');
      expect(e.issues, hasLength(2));
      expect(e.issuesByPath['gallery.3'], 'Too long');
      expect(e.issuesByPath['name'], 'Required');
    });

    test('falls back to message key, then a generic string for a non-map body', () {
      final viaMessage = ApiException.fromStatus(
        400,
        <String, dynamic>{'message': 'Bad request'},
      );
      expect(viaMessage.message, 'Bad request');

      final plain = ApiException.fromStatus(500, 'Internal Server Error');
      expect(plain.message, 'Internal Server Error');
      expect(plain.statusCode, 500);
    });

    test('a body with nothing readable still yields "Request failed"', () {
      final e = ApiException.fromStatus(500, <String, dynamic>{});
      expect(e.message, 'Request failed');
    });
  });

  group('status predicates', () {
    test('401/403/404/409 map to their intents', () {
      expect(ApiException.fromStatus(401, null).isUnauthorized, isTrue);
      expect(ApiException.fromStatus(403, null).isForbidden, isTrue);
      expect(ApiException.fromStatus(404, null).isNotFound, isTrue);
      expect(ApiException.fromStatus(409, null).isConflict, isTrue);
    });
  });

  group('transport factories', () {
    test('network uses the synthetic 0 status and is flagged', () {
      final e = ApiException.network();
      expect(e.statusCode, 0);
      expect(e.code, 'network');
    });

    test('timeout uses 408', () {
      final e = ApiException.timeout();
      expect(e.statusCode, 408);
      expect(e.code, 'timeout');
    });

    test('cancelled carries no status', () {
      final e = ApiException.cancelled();
      expect(e.statusCode, isNull);
      expect(e.code, 'cancelled');
    });
  });

  test('toString includes status and joined issues', () {
    final e = ApiException(
      message: 'Nope',
      statusCode: 409,
      issues: const [ApiFieldIssue(path: 'status', message: 'Moved')],
    );
    expect(e.toString(), contains('409'));
    expect(e.toString(), contains('status: Moved'));
  });
}
