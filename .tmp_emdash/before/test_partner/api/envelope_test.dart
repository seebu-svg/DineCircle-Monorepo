import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/api/envelope.dart';

void main() {
  group('ApiEnvelope.parse', () {
    test('unwraps a single resource under data', () {
      final env = ApiEnvelope.parse({
        'data': {
          'restaurant': {'id': 'v1', 'name': 'Sea & Salt'},
        },
      });
      final map = env.resourceMap('restaurant');
      expect(map, isNotNull);
      expect(map!['name'], 'Sea & Salt');
      expect(env.single('restaurant', (j) => j['id']), 'v1');
    });

    test('maps a list and its meta together', () {
      final env = ApiEnvelope.parse({
        'data': {
          'reservations': [
            {'id': 'r1'},
            {'id': 'r2'},
          ],
        },
        'meta': {'page': 2, 'limit': 20, 'total': 45, 'hasMore': true},
      });
      final ids = env.list('reservations', (j) => j['id'] as String);
      expect(ids, ['r1', 'r2']);
      expect(env.meta.page, 2);
      expect(env.meta.total, 45);
      expect(env.meta.hasMore, isTrue);
    });

    test('a missing resource key yields an empty list, not a throw', () {
      final env = ApiEnvelope.parse({
        'data': <String, dynamic>{},
      });
      expect(env.list('deals', (j) => j), isEmpty);
      expect(env.single('deal', (j) => j), isNull);
    });

    test('passes through a bare resource object when there is no data key', () {
      final env = ApiEnvelope.parse({
        'id': 'x',
        'role': 'host',
      });
      expect(env.data['id'], 'x');
    });

    test('whole() maps the data object itself (dashboard/earnings shape)', () {
      final env = ApiEnvelope.parse({
        'data': {'covers': 12, 'net': 340.5},
      });
      final covers = env.whole((d) => d['covers']);
      expect(covers, 12);
    });

    test('tolerates a non-map body without throwing', () {
      final env = ApiEnvelope.parse('plain string');
      expect(env.data, isEmpty);
    });
  });

  group('ApiMeta', () {
    test('legacy limit-only payload still parses total and defaults', () {
      final meta = ApiMeta.fromJson({'total': 7, 'unread': 2});
      expect(meta.total, 7);
      expect(meta.unread, 2);
      expect(meta.page, 1);
      expect(meta.hasMore, isFalse);
      expect(meta.hasMeta, isTrue);
    });

    test('absent meta means hasMeta is false', () {
      const meta = ApiMeta();
      expect(meta.hasMeta, isFalse);
    });
  });

  group('ApiPage', () {
    test('hasMore only when the payload actually carried meta', () {
      const page = ApiPage<String>(
        items: ['a'],
        meta: ApiMeta(hasMore: true),
      );
      expect(page.hasMore, isFalse); // hasMeta defaults false

      const withMeta = ApiPage<String>(
        items: ['a'],
        meta: ApiMeta(hasMore: true, hasMeta: true),
      );
      expect(withMeta.hasMore, isTrue);
    });

    test('append concatenates without mutating the original', () {
      const page = ApiPage<int>(items: [1], meta: ApiMeta());
      final next = page.append([2, 3]);
      expect(next.items, [1, 2, 3]);
      expect(page.items, [1]);
    });
  });
}
