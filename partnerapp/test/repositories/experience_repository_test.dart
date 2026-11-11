import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/api/api_exception.dart';
import 'package:partnerapp/models/collab.dart';
import 'package:partnerapp/models/experience.dart';
import 'package:partnerapp/repositories/experience_repository.dart';

/// A [HttpClientAdapter] that answers from canned JSON instead of the network.
///
/// The repository layer is where the proposal contract is actually encoded —
/// path, query, body keys — so these tests assert on the request the client
/// *sent* as much as on the model it built. The server integration suite is the
/// authority on behaviour; this one is the authority on the client's shape.
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

  /// The request the repository actually built.
  String get path => last!.path;
  String get method => last!.method;
  Object? get data => last!.data;
  Map<String, dynamic>? get queryParameters => last!.queryParameters;
}

ApiClient _clientWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio);
}

/// An adapter that answers every request with one status, used to prove what the
/// repository does with an answer it did not expect.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelToken,
  ) async {
    last = options;
    return ResponseBody(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientAnswering(_StatusAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio);
}

/// The adapter built by the most recent [_repoWith], so a test can assert on the
/// request after awaiting the call.
_FakeAdapter? _captured;

_FakeAdapter get _sent => _captured!;

ExperienceRepository _repoWith(Object Function(String path) responder) {
  final adapter = _FakeAdapter(responder);
  _captured = adapter;
  return ExperienceRepository(_clientWith(adapter));
}

/// Every partner route answers inside `{ data: ... }`.
Map<String, dynamic> _envelope(Map<String, dynamic> data) => {'data': data};

void main() {
  const venueId = 'v1';
  const eventId = 'e9';

  group('ExperienceRepository.eventRequestDetail', () {
    test('GETs the single request and keeps the full record', () async {
      final repo = _repoWith(
        (path) => _envelope({
          'request': {
            'id': eventId,
            'title': 'Counter Omakase',
            'tagline': 'Twelve seats, one seating',
            'description': 'A chef-led tasting at the pass.',
            'hostId': 'h1',
            'hostName': 'Nora Feld',
            'host': {
              'id': 'h1',
              'name': 'Nora Feld',
              'handle': 'nora',
              'avatarUrl': '',
            },
            'startAt': '2026-12-05T18:00:00.000Z',
            'endAt': '2026-12-05T21:30:00.000Z',
            'durationMinutes': 210,
            'seatsTotal': 12,
            'seatsBooked': 4,
            'seatsLeft': 8,
            'pricePerSeat': 145,
            'type': 'tasting',
            'status': 'requested',
            'coverImage': 'https://img.test/cover.jpg',
            'gallery': ['https://img.test/a.jpg', 'https://img.test/b.jpg'],
            'audience': 'followers',
            'menuStyle': 'tastingMenu',
            'included': ['Welcome drink', 'All courses'],
            'tags': ['omakase'],
            'hostNote': 'Please flag allergies when booking.',
            'language': 'English',
            'dressCode': 'Smart casual',
            // Sent in running order: the detail read gathers courses with
            // `ORDER BY position ASC`, so the model must not shuffle them.
            'menu': [
              {
                'id': 'm1',
                'position': 1,
                'name': 'Nigiri flight',
                'description': 'Chef choice',
                'pairing': '',
                'isSignature': true,
              },
              {
                'id': 'm2',
                'position': 2,
                'name': 'Grilled turbot',
                'description': 'Brown butter, capers',
                'pairing': 'Riesling',
                'isSignature': false,
              },
            ],
            'declineReason': '',
            'approvedAt': null,
            'requiresApproval': true,
            'approvalStaleAt': '2026-12-01T09:00:00.000Z',
            'isReapproval': true,
            'cancelledAt': null,
            'cancellationReason': '',
            'createdAt': '2026-11-20T09:00:00.000Z',
          },
        }),
      );

      final detail = await repo.eventRequestDetail(venueId, eventId);

      expect(
        _sent.path,
        '/partner/restaurants/$venueId/event-requests/$eventId',
      );
      expect(_sent.method, 'GET');
      expect(detail.title, 'Counter Omakase');
      expect(detail.status, ExperienceStatus.requested);
      expect(detail.isAwaitingDecision, isTrue);
      expect(detail.requiresApproval, isTrue);
      expect(detail.durationMinutes, 210);
      expect(detail.audience, 'followers');
      expect(detail.dressCode, 'Smart casual');
      expect(detail.language, 'English');
      expect(detail.hostNote, 'Please flag allergies when booking.');
      expect(detail.included, ['Welcome drink', 'All courses']);
      expect(detail.gallery, hasLength(2));
      expect(detail.host.handle, 'nora');
      // Running order is what makes a tasting menu readable, and the detail
      // read is the only surface that carries it at all.
      expect(detail.menu.map((c) => c.name).toList(), [
        'Nigiri flight',
        'Grilled turbot',
      ]);
      expect(detail.menu.map((c) => c.position).toList(), [1, 2]);
      expect(detail.menu.first.isSignature, isTrue);
      expect(detail.menu.last.pairing, 'Riesling');
      // A re-approval is what the "Changed since your last approval" badge reads.
      expect(detail.changedSinceApproval, isTrue);
      expect(detail.hasFullDetail, isTrue);
    });

    test('a payload without the request key is a hard failure, not an empty sheet', () async {
      final repo = _repoWith((path) => _envelope(const {}));

      await expectLater(
        repo.eventRequestDetail(venueId, eventId),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ExperienceRepository.discoverHosts', () {
    test('omits q when the desk has not typed anything', () async {
      final repo = _repoWith(
        (path) => _envelope({'hosts': <Map<String, Object>>[]}),
      );

      await repo.discoverHosts(venueId);

      final adapter = _sent;
      expect(adapter.path, '/partner/restaurants/$venueId/discover-hosts');
      expect(adapter.queryParameters!.containsKey('q'), isFalse);
      expect(adapter.queryParameters!['limit'], 30);
    });

    test('trims the query and maps the host the composer needs', () async {
      final repo = _repoWith(
        (path) => _envelope({
          'hosts': [
            {
              'id': 'h7',
              'name': 'Ava Chen',
              'handle': 'ava',
              'avatarUrl': 'https://img.test/ava.png',
              'bio': 'Host of the harbour suppers',
              'followersCount': 340,
              'eventsTogether': 2,
            },
          ],
        }),
      );

      final hosts = await repo.discoverHosts(venueId, query: '  Ava  ');

      expect(_sent.queryParameters!['q'], 'Ava');
      expect(hosts.single.id, 'h7');
      expect(hosts.single.displayName, 'Ava Chen');
      expect(hosts.single.initials, 'A');
      expect(hosts.single.followersCount, 340);
      // A returning host is offered first in the composer's copy.
      expect(hosts.single.hasWorkedHere, isTrue);
    });
  });

  group('ExperienceRepository.proposeToHost', () {
    test('POSTs the pair and drops experienceId when nothing is attached', () async {
      final repo = _repoWith(
        (path) => _envelope({
          'proposal': {
            'id': 'p1',
            'title': 'Harbour supper',
            'message': 'Publish this with us',
            'status': 'invited',
            'direction': 'outgoing',
            'proposedBy': 'restaurant',
            'experienceId': null,
            'declineReason': '',
            'createdAt': '2026-11-09T10:00:00.000Z',
            'respondedAt': null,
            'host': {
              'id': 'h7',
              'name': 'Ava Chen',
              'handle': 'ava',
              'avatarUrl': '',
            },
          },
        }),
      );

      final proposal = await repo.proposeToHost(
        venueId: venueId,
        hostId: 'h7',
        title: '  Harbour supper  ',
        message: '  Publish this with us ',
      );

      final adapter = _sent;
      expect(adapter.method, 'POST');
      expect(adapter.path, '/partner/restaurants/$venueId/collab-proposals');
      final body = adapter.data as Map<String, dynamic>;
      expect(body['hostId'], 'h7');
      // The server trims too, but sending a padded title would let a 121-character
      // field with spaces fail validation the client could have avoided.
      expect(body['title'], 'Harbour supper');
      expect(body['message'], 'Publish this with us');
      expect(body.containsKey('experienceId'), isFalse);

      expect(proposal.direction, ProposalDirection.outgoing);
      expect(proposal.awaitsHost, isTrue);
      expect(proposal.counterpartLabel, 'Ava Chen');
    });

    test('sends experienceId when a draft is attached', () async {
      final repo = _repoWith(
        (path) => _envelope({
          'proposal': {
            'id': 'p2',
            'title': 'Harbour supper',
            'direction': 'outgoing',
            'status': 'invited',
            'host': {'id': 'h7', 'name': 'Ava Chen'},
            'experience': {
              'id': 'd4',
              'title': 'Rooftop Draft',
              'coverImage': '',
              'startAt': '2026-12-12T18:00:00.000Z',
              'status': 'draft',
            },
          },
        }),
      );

      final proposal = await repo.proposeToHost(
        venueId: venueId,
        hostId: 'h7',
        title: 'Harbour supper',
        message: 'Take a look',
        experienceId: 'd4',
      );

      expect((_sent.data as Map)['experienceId'], 'd4');
      expect(proposal.experience?.id, 'd4');
      expect(proposal.experience?.status, 'draft');
    });
  });

  group('ExperienceRepository lifecycle transitions', () {
    test('cancel posts a reason only when one was given', () async {
      final repo = _repoWith(
        (path) => _envelope({'eventId': eventId, 'status': 'cancelled'}),
      );

      final first = await repo.cancelEvent(eventId);
      expect((_sent.data as Map).containsKey('reason'), isFalse);
      expect(first.eventId, eventId);
      expect(first.isCancelled, isTrue);

      final second = await repo.cancelEvent(eventId, reason: '  Kitchen flood  ');
      final body = _sent.data as Map;
      expect(body['reason'], 'Kitchen flood');
      expect(second.status, 'cancelled');
      expect(second.isCompleted, isFalse);
    });

    test('complete and reopen unwrap the nested event receipt', () async {
      final repo = _repoWith(
        (path) => path.endsWith('/complete')
            ? _envelope({
                'event': {'id': eventId, 'status': 'completed'},
              })
            : _envelope({
                'event': {'id': eventId, 'status': 'confirmed'},
              }),
      );

      final completed = await repo.completeEvent(eventId);
      expect(_sent.path, '/partner/events/$eventId/complete');
      expect(completed.isCompleted, isTrue);
      expect(completed.eventId, eventId);

      final reopened = await repo.reopenEvent(eventId);
      expect(_sent.path, '/partner/events/$eventId/reopen');
      expect(reopened.isReopened, isTrue);
      expect(reopened.isCancelled, isFalse);
    });
  });

  group('ExperienceRepository.experiences', () {
    test('carries the venue and host ids the proposal composer filters on', () async {
      final repo = _repoWith(
        (path) => _envelope({
          'events': [
            {
              'id': 'd1',
              'title': 'Rooftop Draft',
              'restaurantName': 'Sea & Salt',
              'restaurantId': venueId,
              'hostId': 'h7',
              'startAt': '2026-12-12T18:00:00.000Z',
              'seatsTotal': 20,
              'seatsBooked': 0,
              'seatsLeft': 20,
              'pricePerSeat': 90,
              'status': 'draft',
              'type': 'dinner',
            },
          ],
        }),
      );

      final rows = await repo.experiences(status: 'draft');

      expect(_sent.queryParameters!['status'], 'draft');
      expect(rows.single.restaurantId, venueId);
      expect(rows.single.hostId, 'h7');
      expect(rows.single.status, ExperienceStatus.draft);
    });
  });

  group('ExperienceRepository.proposals', () {
    test('a server without the proposals router is reported as a missing capability',
        () async {
      // The deployed API can be older than this client. A missing route is not
      // an empty inbox: reporting "no proposals" would tell the venue there is
      // nothing to answer when the truth is that nobody can look. The screen
      // renders this as a named gap; Home renders the count as unknown.
      final adapter = _StatusAdapter(404, {'error': 'Route not found'});
      final repo = ExperienceRepository(_clientAnswering(adapter));

      await expectLater(
        repo.proposals(venueId),
        throwsA(isA<FeatureUnavailableException>()),
      );
      expect(
        adapter.last!.path,
        '/partner/restaurants/$venueId/collab-proposals',
      );
    });

    test('a real failure is not swallowed', () async {
      final adapter = _StatusAdapter(500, {'error': 'boom'});
      final repo = ExperienceRepository(_clientAnswering(adapter));

      expect(repo.proposals(venueId), throwsA(isA<ApiException>()));
    });
  });
}
