import 'package:dabbler/features/profile/presentation/models/contributor_profile_data.dart';
import 'package:dabbler/features/profile/presentation/providers/contributor_profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

const String _me = 'user-me';
const String _other = 'user-other';
const String _profile = 'profile-1';

final DateTime _now = DateTime.utc(2026, 10, 29, 12);
final DateTime _past = _now.subtract(const Duration(days: 3));
final DateTime _soon = _now.add(const Duration(days: 1));
final DateTime _later = _now.add(const Duration(days: 5));

ContributorEntity _game(
  String id, {
  DateTime? at,
  String? sport,
  bool organiser = false,
  bool plays = false,
  bool cancelled = false,
}) => ContributorEntity(
  kind: ContributorEntityKind.game,
  id: id,
  startAt: at ?? _past,
  sportId: sport,
  isOrganiser: organiser,
  takesPart: plays,
  isCancelled: cancelled,
);

ContributorEntity _meetup(
  String id, {
  DateTime? at,
  String? sport,
  bool organiser = false,
  bool going = false,
}) => ContributorEntity(
  kind: ContributorEntityKind.meetup,
  id: id,
  startAt: at ?? _soon,
  sportId: sport,
  isOrganiser: organiser,
  takesPart: going,
);

void main() {
  group('Dual role (plays and organises)', () {
    test('a game the user created and joined counts once everywhere', () {
      final ContributorScope s = buildContributorScope(
        games: <ContributorEntity>[
          _game('g1', organiser: true, plays: true),
          _game('g1', organiser: true, plays: true),
          _game('g2', plays: true),
          _game('g3', at: _soon, organiser: true),
        ],
        meetups: const <ContributorEntity>[],
        now: _now,
      );
      expect(s.counts.played, 2, reason: 'g1 and g2, g1 not double counted');
      expect(s.counts.organised, 2, reason: 'g1 and g3');
      expect(s.counts.upcoming, 1, reason: 'g3');
      expect(s.activity.map((ContributorEntity e) => e.id), <String>[
        'g3',
        'g1',
        'g2',
      ], reason: 'hero union is deduplicated, most recent first');
    });

    test('a game and a meetup sharing an id are two different entities', () {
      final ContributorScope s = buildContributorScope(
        games: <ContributorEntity>[_game('x', at: _later, plays: true)],
        meetups: <ContributorEntity>[_meetup('x', at: _soon, going: true)],
        now: _now,
      );
      expect(s.upcoming, hasLength(2));
      expect(s.upcoming.map((ContributorEntity e) => e.key), <String>[
        'meetup:x',
        'game:x',
      ], reason: 'merged by kind+id, then chronological');
      expect(s.counts.upcoming, 1, reason: 'counts are games only');
    });

    test('the same meetup read twice (hosted and going) merges to one', () {
      final ContributorScope s = buildContributorScope(
        games: const <ContributorEntity>[],
        meetups: <ContributorEntity>[
          _meetup('m1', organiser: true),
          _meetup('m1', going: true),
        ],
        now: _now,
      );
      expect(s.upcoming, hasLength(1));
      expect(s.upcoming.single.isOrganiser, isTrue);
      expect(s.upcoming.single.takesPart, isTrue);
    });

    test('cancelled entities never reach counts or lists', () {
      final ContributorScope s = buildContributorScope(
        games: <ContributorEntity>[
          _game('c1', plays: true, cancelled: true),
          _game('c2', at: _soon, organiser: true, cancelled: true),
        ],
        meetups: const <ContributorEntity>[],
        now: _now,
      );
      expect(s.hasNoHistory, isTrue);
      expect(
        (s.counts.played, s.counts.organised, s.counts.upcoming),
        (0, 0, 0),
      );
    });
  });

  group('Sport scoping', () {
    final List<ContributorEntity> games = <ContributorEntity>[
      _game('f1', sport: 'football', plays: true),
      _game('f2', sport: 'football', at: _soon, organiser: true),
      _game('p1', sport: 'padel', plays: true),
      _game('p2', sport: 'padel', organiser: true),
    ];

    test('all sports counts everything', () {
      final ContributorScope s = buildContributorScope(
        games: games,
        meetups: const <ContributorEntity>[],
        now: _now,
      );
      expect(s.counts.played, 2);
      expect(s.counts.organised, 2);
      expect(s.counts.upcoming, 1);
    });

    test('a sport scopes Played, Organised and Upcoming together', () {
      final ContributorScope s = buildContributorScope(
        games: games,
        meetups: const <ContributorEntity>[],
        sportId: 'padel',
        now: _now,
      );
      expect(s.counts.played, 1);
      expect(s.counts.organised, 1, reason: 'Organised is not dropped');
      expect(s.counts.upcoming, 0);
      expect(s.organisedGames.single.id, 'p2');
    });

    test('a sport with no games is an honest zero, not hidden data', () {
      final ContributorScope s = buildContributorScope(
        games: games,
        meetups: const <ContributorEntity>[],
        sportId: 'tennis',
        now: _now,
      );
      expect(s.hasNoHistory, isTrue);
      expect(s.counts.played, 0);
    });

    test('meetups are scoped by sport too', () {
      final ContributorScope s = buildContributorScope(
        games: const <ContributorEntity>[],
        meetups: <ContributorEntity>[
          _meetup('m1', sport: 'padel', going: true),
          _meetup('m2', sport: 'football', going: true),
        ],
        sportId: 'padel',
        now: _now,
      );
      expect(s.upcoming.single.id, 'm1');
    });
  });

  group('No history', () {
    test('keeps the sport profiles so Primary sport can still show', () {
      final ContributorProfileData d = ContributorProfileData(
        profileId: _profile,
        isOwner: true,
        games: const SourceData<List<ContributorEntity>>(<ContributorEntity>[]),
        meetups: const SourceData<List<ContributorEntity>>(
          <ContributorEntity>[],
        ),
        sports: const SourceData<List<ContributorSport>>(<ContributorSport>[
          ContributorSport(sportId: 's-football', sportKey: 'football'),
        ]),
      );
      final ContributorScope s = d.scope(now: _now)!;
      expect(s.hasNoHistory, isTrue);
      expect(s.counts.played, 0);
      expect(d.sportsOrEmpty.single.sportKey, 'football');
    });
  });

  group('Gaps are named, never zeros', () {
    test('Show-up rate, Minutes, Partners, Mutuals are gaps by default', () {
      const ContributorProfileData d = ContributorProfileData(
        profileId: _profile,
        isOwner: true,
        games: SourceData<List<ContributorEntity>>(<ContributorEntity>[]),
        meetups: SourceData<List<ContributorEntity>>(<ContributorEntity>[]),
        sports: SourceData<List<ContributorSport>>(<ContributorSport>[]),
      );
      expect(d.showUpRate, isA<SourceGap<double>>());
      expect(d.showUpRate.valueOrNull, isNull);
      expect(d.minutesPlayed.valueOrNull, isNull);
      expect(d.partners.valueOrNull, isNull);
      expect(d.mutuals.valueOrNull, isNull);
      expect(d.needsAttention.valueOrNull, isNull);
      expect(
        (d.showUpRate as SourceGap<double>).gap.id,
        ContributorGaps.showUpRate.id,
      );
    });
  });

  group('Source failures', () {
    ContributorProfileData data({
      required SourceState<List<ContributorEntity>> games,
      required SourceState<List<ContributorEntity>> meetups,
    }) => ContributorProfileData(
      profileId: _profile,
      isOwner: true,
      games: games,
      meetups: meetups,
      sports: const SourceData<List<ContributorSport>>(<ContributorSport>[]),
    );

    test('both event sources failing yields no scope, not a zero', () {
      final ContributorProfileData d = data(
        games: SourceFailed<List<ContributorEntity>>(StateError('g')),
        meetups: SourceFailed<List<ContributorEntity>>(StateError('m')),
      );
      expect(d.eventsUnavailable, isTrue);
      expect(d.scope(now: _now), isNull);
    });

    test('meetups failing leaves games readable', () {
      final ContributorProfileData d = data(
        games: SourceData<List<ContributorEntity>>(<ContributorEntity>[
          _game('g1', plays: true),
        ]),
        meetups: SourceFailed<List<ContributorEntity>>(StateError('m')),
      );
      expect(d.eventsUnavailable, isFalse);
      expect(d.scope(now: _now)!.counts.played, 1);
    });
  });

  group('loadContributorProfile reads', () {
    late List<http.Request> sent;
    late Map<String, http.Response Function(http.Request)> routes;

    setUp(() {
      sent = <http.Request>[];
      routes = <String, http.Response Function(http.Request)>{
        'v_game_card': (http.Request r) =>
            jsonListResponse(<Map<String, dynamic>>[], request: r),
        'v_meetup_list': (http.Request r) =>
            jsonListResponse(<Map<String, dynamic>>[], request: r),
        'sport_profiles': (http.Request r) =>
            jsonListResponse(<Map<String, dynamic>>[], request: r),
        'game_roster': (http.Request r) =>
            jsonListResponse(<Map<String, dynamic>>[], request: r),
      };
    });

    Future<ContributorProfileData> load({required String target}) {
      return loadContributorProfile(
        buildTestSupabaseClient((http.Request r) async {
          sent.add(r);
          final String table = r.url.pathSegments.last;
          return routes[table]!(r);
        }),
        viewerUserId: _me,
        targetUserId: target,
        profileId: _profile,
      );
    }

    Map<String, dynamic> gameRow(String id, {String? start, String? sport}) =>
        <String, dynamic>{
          'id': id,
          'title': 'Game $id',
          'start_at': start ?? _past.toIso8601String(),
          'is_cancelled': false,
          'is_creator': false,
          'is_joined': true,
          'creator_profile_id': 'someone-else',
          'sport_id': sport ?? 'football',
        };

    test(
      'owner: counts are the whole result, not a first-page length',
      () async {
        routes['v_game_card'] = (http.Request r) => jsonListResponse(
          <Map<String, dynamic>>[for (int i = 0; i < 1200; i++) gameRow('g$i')],
          request: r,
        );
        final ContributorProfileData d = await load(target: _me);
        expect(d.isOwner, isTrue);
        expect(d.scope(now: _now)!.counts.played, 1200);
      },
    );

    test(
      'owner reads RSVP going; visitor never asks for the viewer RSVP',
      () async {
        await load(target: _me);
        final String ownerMeetupQuery = sent
            .firstWhere(
              (http.Request r) => r.url.path.endsWith('v_meetup_list'),
            )
            .url
            .query;
        expect(ownerMeetupQuery, contains('my_rsvp_status.eq.going'));

        sent.clear();
        final ContributorProfileData v = await load(target: _other);
        final String visitorMeetupQuery = sent
            .firstWhere(
              (http.Request r) => r.url.path.endsWith('v_meetup_list'),
            )
            .url
            .query;
        expect(visitorMeetupQuery, isNot(contains('my_rsvp_status')));
        expect(v.isOwner, isFalse);
      },
    );

    test('visitor: owner-private organiser queue is never read', () async {
      final ContributorProfileData v = await load(target: _other);
      final SourceState<int> n = v.needsAttention;
      expect(n, isA<SourceGap<int>>());
      expect((n as SourceGap<int>).gap.id, 'owner-private');
    });

    test('visitor: roster is read for the target user, active only', () async {
      await load(target: _other);
      final http.Request roster = sent.firstWhere(
        (http.Request r) => r.url.path.endsWith('game_roster'),
      );
      expect(roster.url.query, contains('user_id=eq.$_other'));
      expect(roster.url.query, contains('status=eq.active'));
    });

    test(
      'visitor: a roster game and a created game both appear, deduped',
      () async {
        routes['game_roster'] = (http.Request r) =>
            jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'game_id': 'g1'},
            ], request: r);
        routes['v_game_card'] = (http.Request r) =>
            jsonListResponse(<Map<String, dynamic>>[
              gameRow('g1')..['creator_profile_id'] = _profile,
              gameRow('g2')..['creator_profile_id'] = _profile,
            ], request: r);
        final ContributorProfileData d = await load(target: _other);
        final ContributorScope s = d.scope(now: _now)!;
        expect(s.counts.played, 1, reason: 'only g1 is on the roster');
        expect(s.counts.organised, 2);
      },
    );

    test(
      'a failed games read is a SourceFailed; other sections survive',
      () async {
        routes['v_game_card'] = (http.Request r) =>
            postgrestErrorResponse(message: 'boom', status: 500, request: r);
        routes['sport_profiles'] = (http.Request r) =>
            jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'sport_id': 's1', 'sport': 'padel'},
            ], request: r);
        final ContributorProfileData d = await load(target: _me);
        expect(d.games, isA<SourceFailed<List<ContributorEntity>>>());
        expect(d.meetups, isA<SourceData<List<ContributorEntity>>>());
        expect(d.sports.valueOrNull!.single.sportKey, 'padel');
        expect(d.scope(now: _now), isNotNull, reason: 'meetups still readable');
      },
    );

    test('a failed sports read does not hide the games', () async {
      routes['sport_profiles'] = (http.Request r) =>
          postgrestErrorResponse(message: 'denied', status: 403, request: r);
      routes['v_game_card'] = (http.Request r) =>
          jsonListResponse(<Map<String, dynamic>>[gameRow('g1')], request: r);
      final ContributorProfileData d = await load(target: _me);
      expect(d.sports, isA<SourceFailed<List<ContributorSport>>>());
      expect(d.scope(now: _now)!.counts.played, 1);
    });

    test('meetups: hosting is organising, going is taking part', () {
      final List<ContributorEntity> out = meetupRowsToEntities(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm1',
            'start_at': _soon.toIso8601String(),
            'creator_profile_id': _profile,
            'my_rsvp_status': null,
          },
          <String, dynamic>{
            'id': 'm2',
            'start_at': _soon.toIso8601String(),
            'creator_profile_id': 'x',
            'my_rsvp_status': 'going',
          },
          <String, dynamic>{
            'id': 'm3',
            'start_at': _soon.toIso8601String(),
            'creator_profile_id': 'x',
            'my_rsvp_status': 'interested',
          },
        ],
        isOwn: true,
        profileId: _profile,
      );
      expect(out[0].isOrganiser, isTrue);
      expect(out[1].takesPart, isTrue);
      expect(out[2].takesPart, isFalse, reason: 'interested is not attending');
    });

    test('a visitor never inherits the viewer RSVP as the profile\'s', () {
      final List<ContributorEntity> out = meetupRowsToEntities(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm2',
            'start_at': _soon.toIso8601String(),
            'creator_profile_id': 'x',
            'my_rsvp_status': 'going',
          },
        ],
        isOwn: false,
        profileId: _profile,
      );
      expect(out.single.takesPart, isFalse);
    });
  });
}
