import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/collab.dart';
import 'package:partnerapp/models/experience.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/app_providers.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/experience_repository.dart';
import 'package:partnerapp/screens/experiences/experiences_list.dart';
import 'package:partnerapp/screens/experiences/experiences_section_screen.dart';
import 'package:partnerapp/screens/experiences/experiences_widgets.dart';
import 'package:partnerapp/screens/experiences/proposals_tab.dart';
import 'package:partnerapp/screens/experiences/request_inbox.dart';
import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/widgets/section_tabs.dart';

const _user = PartnerUser(id: 'u1', name: 'Ada Owner', role: 'restaurant_owner');

Venue venue({
  String name = 'Cafe Aylanto',
  bool verified = true,
  PartnerRole role = PartnerRole.owner,
}) => Venue(
  id: 'v1',
  name: name,
  city: 'Karachi',
  verified: verified,
  myRole: role,
);

class _Scope extends VenueScopeController {
  _Scope(this.value);

  final Venue value;

  @override
  Future<VenueScopeState> build() async =>
      VenueScopeState(venues: [value], selectedId: value.id);
}

class _Badge extends NotificationBadgeController {
  @override
  Future<int> build() async => 0;
}

/// Only the writes these screens make are implemented; everything else keeps
/// the real signature so a screen cannot silently call something unreachable.
class TestRepo extends ExperienceRepository {
  TestRepo() : super(ApiClient());

  int approves = 0;
  int declines = 0;
  int accepts = 0;
  int cancels = 0;
  int answerCalls = 0;
  int proposeCalls = 0;
  bool lastAccept = false;
  String lastDeclineReason = '';
  String lastAnswerReason = '';
  String lastApproveVenue = '';

  @override
  Future<EventDecision> approve(String venueId, String eventId) async {
    approves++;
    lastApproveVenue = venueId;
    return EventDecision(eventId: eventId, status: 'confirmed');
  }

  @override
  Future<EventDecision> decline(
    String venueId,
    String eventId, {
    String reason = '',
  }) async {
    declines++;
    lastDeclineReason = reason;
    return EventDecision(eventId: eventId, status: 'declined', reason: reason);
  }

  @override
  Future<CollabProposal?> answerProposal(
    String venueId,
    String proposalId, {
    required bool accept,
    String reason = '',
  }) async {
    answerCalls++;
    lastAccept = accept;
    lastAnswerReason = reason;
    if (accept) accepts++;
    return null;
  }

  @override
  Future<CollabProposal> proposeToHost({
    required String venueId,
    required String hostId,
    required String title,
    required String message,
    String? experienceId,
  }) async {
    proposeCalls++;
    return proposal(id: 'sent-$proposeCalls', title: title);
  }

  @override
  Future<CollabProposal?> cancelProposal(
    String venueId,
    String proposalId,
  ) async {
    cancels++;
    return null;
  }
}

PartnerExperience experience({
  String id = 'e1',
  String title = 'Chef’s table',
  String venueName = 'Cafe Aylanto',
  ExperienceType type = ExperienceType.dinner,
  ExperienceStatus status = ExperienceStatus.confirmed,
  int seatsTotal = 20,
  int seatsBooked = 9,
  double price = 6500,
  String cover = '',
  DateTime? startAt,
}) => PartnerExperience(
  id: id,
  title: title,
  restaurantName: venueName,
  restaurantId: 'v1',
  startAt: startAt ?? DateTime.now().add(const Duration(days: 5)),
  seatsTotal: seatsTotal,
  seatsBooked: seatsBooked,
  pricePerSeat: price,
  status: status,
  type: type,
  coverImage: cover,
);

ExperienceRequest request({
  String id = 'r1',
  String title = 'Levantine courtyard dinner',
  String hostName = 'Ava Chen',
  ExperienceStatus status = ExperienceStatus.requested,
  String cover = '',
  DateTime? startAt,
}) => ExperienceRequest(
  id: id,
  title: title,
  hostId: 'h1',
  hostName: hostName,
  host: const ProposalHostRef(id: 'h1', name: 'Ava Chen', handle: 'ava'),
  startAt: startAt ?? DateTime.now().add(const Duration(days: 9)),
  seatsTotal: 24,
  seatsBooked: 6,
  seatsLeft: 18,
  pricePerSeat: 4500,
  status: status,
  type: ExperienceType.supperClub,
  coverImage: cover,
);

CollabProposal proposal({
  String id = 'p1',
  String title = 'Harbour supper',
  ProposalDirection direction = ProposalDirection.incoming,
  ProposalStatus status = ProposalStatus.invited,
  String host = 'Ava Chen',
  DateTime? createdAt,
}) => CollabProposal(
  id: id,
  title: title,
  direction: direction,
  status: status,
  host: ProposalHost(id: 'h1', name: host, handle: 'ava'),
  experience: ProposalExperience(
    id: 'e9',
    title: 'Rooftop tasting',
    startAt: DateTime.now().add(const Duration(days: 12)),
  ),
  createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 1)),
);

Widget harness(
  Widget child, {
  Venue? scope,
  TestRepo? repo,
  List<PartnerExperience> experiences = const [],
  Future<List<PartnerExperience>> Function()? experiencesReader,
  Map<String, List<ExperienceRequest>> requests = const {},
  List<CollabProposal> proposals = const [],
  Future<List<CollabProposal>> Function()? proposalsReader,
  List<DiscoverableHost> hosts = const [],
}) {
  return ProviderScope(
    overrides: [
      venueScopeProvider.overrideWith(() => _Scope(scope ?? venue())),
      notificationBadgeProvider.overrideWith(_Badge.new),
      isOfflineProvider.overrideWithValue(false),
      currentUserProvider.overrideWithValue(_user),
      isPlatformAdminProvider.overrideWithValue(false),
      experienceRepositoryProvider.overrideWithValue(repo ?? TestRepo()),
      experiencesProvider.overrideWith(
        (ref, status) =>
            experiencesReader?.call() ?? Future.value(experiences),
      ),
      eventRequestsProvider.overrideWith(
        (ref, key) async => requests[key.status] ?? const <ExperienceRequest>[],
      ),
      eventRequestDetailProvider.overrideWith(
        (ref, key) async => request(id: key.request),
      ),
      collabProposalsProvider.overrideWith(
        (ref, key) =>
            proposalsReader?.call() ?? Future.value(proposals),
      ),
      discoverHostsProvider.overrideWith(
        (ref, key) async => hosts,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

/// Taps one chip in the shared filter rail.
///
/// The rail is a horizontal list, so a chip past the right edge has not been
/// built yet on a narrow screen; it is scrolled into view first.
Future<void> rail(WidgetTester tester, String label) async {
  final rail = find.byType(ExperienceFilterRail);
  final chip = find.descendant(of: rail, matching: find.text(label));
  await tester.scrollUntilVisible(
    chip,
    120,
    scrollable: find.descendant(of: rail, matching: find.byType(Scrollable)),
  );
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// One labelled fact on a card. The label is part of a rich text run, so it is
/// matched on the widget rather than on a plain [Text].
Finder metaRow(String label) => find.byWidgetPredicate(
  (widget) => widget is ExperienceMetaRow && widget.label == label,
);

/// The number a rail chip measured, scoped so a header metric cannot answer
/// for it.
Finder railCount(String value) => find.descendant(
  of: find.byType(ExperienceFilterRail),
  matching: find.text(value),
);

/// Pins a device size and a text scale for one test, and clears both after.
void useDevice(WidgetTester tester, Size size, {double scale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  group('Requests', () {
    testWidgets('a request names the host, the date and all three actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const RequestInbox(),
          requests: {
            'requested': [
              request(),
              request(id: 'r0', title: 'Cellar tasting'),
            ],
            'confirmed': [
              request(id: 'r2', status: ExperienceStatus.confirmed),
            ],
            'declined': const [],
          },
        ),
      );
      await tester.pumpAndSettle();

      final header = find.byType(ExperienceHeader);
      expect(header, findsOneWidget);
      // Identity is the restaurant, stated plainly, never behind a menu.
      expect(
        find.descendant(of: header, matching: find.text('CAFE AYLANTO')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.byType(DropdownButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: header, matching: find.byType(PopupMenuButton)),
        findsNothing,
      );
      expect(find.text('Levantine courtyard dinner'), findsOneWidget);
      expect(find.text('Ava Chen'), findsOneWidget);
      expect(metaRow('Requested date'), findsOneWidget);
      expect(metaRow('Capacity'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-approve-r1')), findsOneWidget);
      expect(find.byKey(const ValueKey('request-decline-r1')), findsOneWidget);
      expect(find.byKey(const ValueKey('request-details-r1')), findsOneWidget);

      // The rail counts every queue it measured, not just the visible one:
      // two to review, one approved, none declined.
      expect(railCount('2'), findsOneWidget);
      expect(railCount('1'), findsOneWidget);
      expect(railCount('0'), findsOneWidget);
    });

    testWidgets('approving confirms first and then writes', (tester) async {
      final repo = TestRepo();
      await tester.pumpWidget(
        harness(
          const RequestInbox(),
          repo: repo,
          requests: {
            'requested': [request()],
            'confirmed': const [],
            'declined': const [],
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('request-approve-r1')));
      await tester.pumpAndSettle();
      expect(repo.approves, 0, reason: 'the dialog gates the write');

      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(repo.approves, 1);
      expect(repo.lastApproveVenue, 'v1');
    });

    testWidgets('the rail switches queues without hiding their counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const RequestInbox(),
          requests: {
            'requested': [request()],
            'confirmed': [
              request(id: 'r2', title: 'Approved supper', status: ExperienceStatus.confirmed),
            ],
            'declined': const [],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Levantine courtyard dinner'), findsOneWidget);
      expect(find.text('Approved supper'), findsNothing);

      await rail(tester, 'Approved');
      expect(find.text('Approved supper'), findsOneWidget);
      expect(find.text('Levantine courtyard dinner'), findsNothing);
      // A decided request has no decision buttons left.
      expect(find.byKey(const ValueKey('request-approve-r2')), findsNothing);
      expect(find.byKey(const ValueKey('request-details-r2')), findsOneWidget);
    });

    testWidgets('an empty queue says what will fill it', (tester) async {
      await tester.pumpWidget(
        harness(
          const RequestInbox(),
          requests: {
            'requested': const [],
            'confirmed': const [],
            'declined': const [],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing to review'), findsOneWidget);
      expect(
        find.textContaining('New host proposals for this venue appear here'),
        findsOneWidget,
      );
    });
  });

  group('Proposals', () {
    testWidgets('incoming and sent cards name the counterpart and next action', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const ProposalsTab(),
          proposals: [
            proposal(),
            proposal(
              id: 'p2',
              title: 'Chef collaboration',
              direction: ProposalDirection.outgoing,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Harbour supper'), findsOneWidget);
      expect(find.text('Chef collaboration'), findsOneWidget);
      // Both directions are named on the rail *and* on the card it describes.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proposal-card-p1')),
          matching: find.text('Incoming'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('proposal-card-p2')),
          matching: find.text('Sent by you'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Next: Your decision'), findsOneWidget);
      expect(find.textContaining('Next: Waiting on Ava Chen'), findsOneWidget);
      expect(find.byKey(const ValueKey('proposal-accept-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('proposal-decline-p1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('proposal-withdraw-p2')),
        findsOneWidget,
      );
    });

    testWidgets('accepting a proposal confirms and then writes', (tester) async {
      final repo = TestRepo();
      await tester.pumpWidget(
        harness(const ProposalsTab(), repo: repo, proposals: [proposal()]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('proposal-accept-p1')));
      await tester.pumpAndSettle();
      expect(repo.accepts, 0);

      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();
      expect(repo.accepts, 1);
    });

    testWidgets('the direction chips split one measured feed', (tester) async {
      await tester.pumpWidget(
        harness(
          const ProposalsTab(),
          proposals: [
            proposal(),
            proposal(
              id: 'p2',
              title: 'Chef collaboration',
              direction: ProposalDirection.outgoing,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await rail(tester, 'Incoming');
      expect(find.text('Harbour supper'), findsOneWidget);
      expect(find.text('Chef collaboration'), findsNothing);

      await rail(tester, 'Sent by you');
      expect(find.text('Harbour supper'), findsNothing);
      expect(find.text('Chef collaboration'), findsOneWidget);
    });

    testWidgets('a missing route is named, never rendered as an empty inbox', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const ProposalsTab(),
          proposalsReader: () async => throw const FeatureUnavailableException(
            'Collaboration proposals',
            'Route not found',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('not on this server build'), findsOneWidget);
      expect(find.textContaining('Route not found'), findsOneWidget);
      expect(find.text('No proposals yet'), findsNothing);
      expect(find.text('Check again'), findsOneWidget);
    });
  });

  group('Experiences', () {
    testWidgets('a card carries title, format, date, capacity and price', (
      tester,
    ) async {
      useDevice(tester, const Size(420, 900));
      await tester.pumpWidget(
        harness(
          const ExperiencesScreen(),
          experiences: [experience()],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chef’s table'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Cafe Aylanto'), findsOneWidget);
      expect(metaRow('When'), findsOneWidget);
      expect(find.textContaining('Rs. 6,500'), findsOneWidget);
      expect(find.byType(ExperienceFillBar), findsOneWidget);
      expect(find.textContaining('9 of 20 seats filled'), findsOneWidget);
      expect(find.text('Confirmed'), findsWidgets);
    });

    testWidgets('the rail filters by lifecycle and keeps measured counts', (
      tester,
    ) async {
      useDevice(tester, const Size(420, 900));
      await tester.pumpWidget(
        harness(
          const ExperiencesScreen(),
          experiences: [
            experience(id: 'e1', title: 'Confirmed dinner'),
            experience(
              id: 'e2',
              title: 'Live tasting',
              status: ExperienceStatus.live,
              type: ExperienceType.tasting,
            ),
            experience(
              id: 'e3',
              title: 'Past brunch',
              status: ExperienceStatus.completed,
              type: ExperienceType.brunch,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirmed dinner'), findsOneWidget);
      // Every chip measured the whole book, not only the page it can show.
      expect(railCount('3'), findsOneWidget);
      expect(railCount('2'), findsNothing, reason: 'no two rows share a status');

      await rail(tester, 'Live');
      expect(find.text('Live tasting'), findsOneWidget);
      expect(find.text('Confirmed dinner'), findsNothing);

      await rail(tester, 'Past');
      expect(find.text('Past brunch'), findsOneWidget);
      expect(find.text('Live tasting'), findsNothing);
    });

    testWidgets('an empty book offers the one action that changes it', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const ExperiencesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No experiences yet'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create experience'),
        findsWidgets,
      );
      expect(find.byKey(const ValueKey('experience-create')), findsOneWidget);
    });

    testWidgets('a role that may not publish sees the action disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const ExperiencesScreen(),
          scope: venue(role: PartnerRole.staff),
        ),
      );
      await tester.pumpAndSettle();

      final create = tester.widget<FilledButton>(
        find.byKey(const ValueKey('experience-create')),
      );
      expect(create.onPressed, isNull);
    });

    testWidgets('a failed read keeps the shared error and its retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const ExperiencesScreen(),
          experiencesReader: () async => throw StateError('Offline'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('manage opens the editor prefilled with the row', (
      tester,
    ) async {
      useDevice(tester, const Size(420, 900));
      await tester.pumpWidget(
        harness(const ExperiencesScreen(), experiences: [experience()]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('experience-manage-e1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit experience'), findsOneWidget);
      expect(find.text('Cover photo'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save changes'), findsOneWidget);
      // The row's own values came with it, not a blank form.
      final titleField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Title *'),
          matching: find.byType(TextField),
        ),
      );
      expect(titleField.controller?.text, 'Chef’s table');
    });

    testWidgets('320dp at 2x text scale lays out without an exception', (
      tester,
    ) async {
      useDevice(tester, const Size(320, 640), scale: 2);
      await tester.pumpWidget(
        harness(
          const ExperiencesScreen(),
          experiences: [
            experience(title: 'A very long experience title that wraps'),
            experience(
              id: 'e2',
              title: 'Second',
              status: ExperienceStatus.live,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'a 320dp phone at 2x text must lay out, not overflow',
      );

      // The book is one scroll view: the header and the cards scroll away
      // together instead of the header pinning the cards out of existence.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Proposals regressions', () {
    testWidgets('dismissing the decline sheet is not a decision', (tester) async {
      useDevice(tester, const Size(420, 900));
      final repo = TestRepo();
      await tester.pumpWidget(
        harness(
          ProposalsTab(onFindHost: () {}),
          repo: repo,
          proposals: [proposal()],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('proposal-decline-p1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Decline "Harbour supper"'), findsOneWidget);

      // Backing out of the sheet is what a desk does when it changes its mind.
      // The barrier is how a phone dismisses it, and it returns null.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(
        repo.answerCalls,
        0,
        reason: 'a dismissed sheet must not write a decision',
      );
      expect(
        find.byKey(const ValueKey('proposal-decline-p1')),
        findsOneWidget,
        reason: 'the proposal is still open and answerable',
      );
    });

    testWidgets('an empty reason still declines on purpose', (tester) async {
      useDevice(tester, const Size(420, 900));
      final repo = TestRepo();
      await tester.pumpWidget(
        harness(
          ProposalsTab(onFindHost: () {}),
          repo: repo,
          proposals: [proposal()],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('proposal-decline-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send decline'));
      await tester.pumpAndSettle();

      expect(repo.answerCalls, 1);
      expect(repo.lastAccept, isFalse);
      expect(repo.lastAnswerReason, '');
    });

    testWidgets('sending from host discovery refreshes the feed the tab renders', (
      tester,
    ) async {
      useDevice(tester, const Size(420, 1200));
      final repo = TestRepo();
      var reads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            venueScopeProvider.overrideWith(() => _Scope(venue())),
            notificationBadgeProvider.overrideWith(_Badge.new),
            isOfflineProvider.overrideWithValue(false),
            currentUserProvider.overrideWithValue(_user),
            isPlatformAdminProvider.overrideWithValue(false),
            experienceRepositoryProvider.overrideWithValue(repo),
            experiencesProvider.overrideWith((ref, status) async => const []),
            eventRequestsProvider.overrideWith(
              (ref, key) async => const <ExperienceRequest>[],
            ),
            collabProposalsProvider.overrideWith((ref, key) {
              reads++;
              return Future.value(const <CollabProposal>[]);
            }),
            discoverHostsProvider.overrideWith(
              (ref, key) async => const [
                DiscoverableHost(id: 'h1', name: 'Ava Chen', handle: 'ava'),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            onGenerateRoute: (settings) => MaterialPageRoute(
              settings: settings,
              builder: (_) => const ExperiencesSectionScreen(),
            ),
            initialRoute: '/experiences?tab=proposals',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = reads;

      await tester.tap(find.widgetWithText(OutlinedButton, 'Find a host').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Proposal title'),
        'Chef table with Ava',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Message to the host'),
        'A six seat dinner on the roof.',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(Form),
          matching: find.text('Send proposal'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.proposeCalls, 1);
      expect(
        reads,
        greaterThan(before),
        reason: 'the send must invalidate the feed the tab renders, not a '
            'direction-scoped key nothing watches',
      );
    });

    testWidgets('a declined incoming proposal names this venue as the decider', (
      tester,
    ) async {
      useDevice(tester, const Size(420, 900));
      await tester.pumpWidget(
        harness(
          ProposalsTab(onFindHost: () {}),
          proposals: [proposal(status: ProposalStatus.declined)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next: Declined by your venue'), findsOneWidget);
      expect(find.text('Next: Declined by Ava Chen'), findsNothing);
    });

    testWidgets('a declined outgoing proposal still names the host', (
      tester,
    ) async {
      useDevice(tester, const Size(420, 900));
      await tester.pumpWidget(
        harness(
          ProposalsTab(onFindHost: () {}),
          proposals: [
            proposal(
              direction: ProposalDirection.outgoing,
              status: ProposalStatus.declined,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next: Declined by Ava Chen'), findsOneWidget);
    });
  });

  group('Section shell', () {
    Future<void> pumpSection(WidgetTester tester, String route) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            venueScopeProvider.overrideWith(() => _Scope(venue())),
            notificationBadgeProvider.overrideWith(_Badge.new),
            isOfflineProvider.overrideWithValue(false),
            currentUserProvider.overrideWithValue(_user),
            isPlatformAdminProvider.overrideWithValue(false),
            experienceRepositoryProvider.overrideWithValue(TestRepo()),
            experiencesProvider.overrideWith((ref, status) async => const []),
            eventRequestsProvider.overrideWith(
              (ref, key) async => const <ExperienceRequest>[],
            ),
            collabProposalsProvider.overrideWith(
              (ref, key) async => const <CollabProposal>[],
            ),
            discoverHostsProvider.overrideWith((ref, key) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            onGenerateRoute: (settings) => MaterialPageRoute(
              settings: settings,
              builder: (_) => const ExperiencesSectionScreen(),
            ),
            initialRoute: route,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the section keeps exactly three primary tabs', (tester) async {
      useDevice(tester, const Size(420, 900));
      await pumpSection(tester, '/experiences?tab=experiences');

      expect(find.byType(SectionTabs), findsOneWidget);
      for (final label in const ['Requests', 'Proposals', 'Experiences']) {
        expect(
          find.descendant(of: find.byType(TabBar), matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Hosts')),
        findsNothing,
      );
    });

    testWidgets('a saved ?tab=hosts link still opens host discovery', (
      tester,
    ) async {
      useDevice(tester, const Size(420, 900));
      await pumpSection(tester, '/experiences?tab=hosts');

      expect(find.text('Find a host'), findsWidgets);
      expect(
        find.textContaining('Professional hosts you can propose'),
        findsOneWidget,
      );
    });
  });
}
