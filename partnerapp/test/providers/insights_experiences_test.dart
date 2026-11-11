import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/experience.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/app_providers.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/experience_repository.dart';

/// Attribution for the Experiences card.
///
/// `/partner/events` is account-wide, so the screen can only be right if the
/// rows are narrowed to the venue in the switcher. The id is authoritative;
/// the name is the fallback for a server that predates the id field, because
/// dropping every row would render a confident zero.
class _Scope extends VenueScopeController {
  _Scope({this.name = 'Sea & Salt'});

  final String name;

  @override
  Future<VenueScopeState> build() async => VenueScopeState(
        venues: [_venue(name)],
        selectedId: 'v1',
      );
}

Venue _venue(String name) => Venue(
      id: 'v1',
      name: name,
      city: 'Karachi',
      verified: true,
    );

class _Feed implements ExperienceRepository {
  _Feed(this.rows);

  final List<PartnerExperience> rows;

  @override
  Future<List<PartnerExperience>> experiences({
    String? status,
    int limit = 50,
  }) async =>
      rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PartnerExperience _row(String id, String restaurantId, String restaurantName) =>
    PartnerExperience(
      id: id,
      title: 'Chef’s Table',
      restaurantName: restaurantName,
      restaurantId: restaurantId,
      startAt: DateTime.now().subtract(const Duration(days: 2)),
      seatsTotal: 24,
      seatsBooked: 18,
      pricePerSeat: 4500,
      status: ExperienceStatus.completed,
      type: ExperienceType.dinner,
    );

Future<List<PartnerExperience>> _read(
  List<PartnerExperience> rows, {
  String name = 'Sea & Salt',
}) async {
  final container = ProviderContainer(
    overrides: [
      venueScopeProvider.overrideWith(() => _Scope(name: name)),
      experienceRepositoryProvider.overrideWithValue(_Feed(rows)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(insightsExperiencesProvider('v1').future);
}

void main() {
  test('keeps only rows owned by the venue when the feed carries ids', () async {
    final rows = await _read([
      _row('mine', 'v1', 'Sea & Salt'),
      // Same name, different venue: the id decides, not the label.
      _row('namesake', 'v2', 'Sea & Salt'),
      _row('other', 'v3', 'Kolachi'),
    ]);

    expect(rows.map((row) => row.id), ['mine']);
  });

  test('falls back to the venue name when no row carries an id', () async {
    final rows = await _read([
      _row('mine', '', 'Sea & Salt'),
      _row('other', '', 'Kolachi'),
    ]);

    expect(rows.map((row) => row.id), ['mine']);
  });

  test('a feed without ids or a matching name reports nothing', () async {
    final rows = await _read(
      [_row('other', '', 'Kolachi')],
      name: 'Sea & Salt',
    );

    expect(rows, isEmpty);
  });
}
