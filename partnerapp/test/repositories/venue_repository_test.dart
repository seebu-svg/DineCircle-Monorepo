import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/repositories/business_repository.dart';
import 'package:partnerapp/repositories/venue_repository.dart';

/// A [HttpClientAdapter] that answers from canned JSON instead of the network,
/// and records the last request so a test can assert on the built path/query.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  /// Produces the response body for a given request path.
  final Object Function(String path) responder;

  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelToken,
  ) async {
    last = options;
    final body = utf8.encode(jsonEncode(responder(options.path)));
    return ResponseBody(
      Stream.value(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio);
}

void main() {
  group('VenueRepository.listVenues', () {
    test('GETs the account venues and maps each with its role', () async {
      final adapter = _FakeAdapter(
        (path) => {
          'data': {
            'restaurants': [
              {
                'id': 'v1',
                'name': 'Sea & Salt',
                'verified': true,
                'myRole': 'manager',
              },
              {
                'id': 'v2',
                'name': 'The Fold',
                'myRole': 'staff',
              },
            ],
          },
        },
      );
      final repo = VenueRepository(_clientWith(adapter));

      final venues = await repo.listVenues();

      expect(adapter.last!.method, 'GET');
      expect(venues, hasLength(2));
      expect(venues.first.id, 'v1');
      expect(venues.first.verified, isTrue);
      expect(venues.first.myRole.wire, 'manager');
      expect(venues.last.myRole.wire, 'staff');
    });
  });

  group('BusinessRepository', () {
    test('builds the deals path under the venue and forwards the query', () async {
      final adapter = _FakeAdapter(
        (path) => {
          'data': {
            'deals': [
              {
                'id': 'd1',
                'restaurantId': 'v1',
                'title': 'Tasting',
                'kind': 'percent',
                'value': 15,
                'status': 'active',
                'startsAt': '2026-01-01T00:00:00Z',
                'endsAt': '2026-12-31T00:00:00Z',
              },
            ],
            'meta': {'total': 1, 'hasMore': false},
          },
        },
      );
      final repo = BusinessRepository(_clientWith(adapter));

      final deals = await repo.deals('v1', const DealQuery(status: 'active'));

      expect(adapter.last!.path, '/partner/restaurants/v1/deals');
      expect(adapter.last!.queryParameters['status'], 'active');
      expect(deals, hasLength(1));
      expect(deals.first.title, 'Tasting');
      expect(deals.first.status.wire, 'active');
    });

    test('a venue-scoped money read carries its ISO range in the query', () async {
      final adapter = _FakeAdapter(
        (path) => {
          'data': {
            'net': 500,
            'gross': 600,
            'commissionRate': 0.1,
          },
        },
      );
      final repo = BusinessRepository(_clientWith(adapter));

      await repo.earnings(
        'v1',
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 31),
      );

      expect(adapter.last!.queryParameters['from'], '2026-10-01T00:00:00.000Z');
      expect(adapter.last!.queryParameters['to'], '2026-10-31T00:00:00.000Z');
    });
  });
}
