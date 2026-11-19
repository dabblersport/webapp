// KAN-1014: the removal sheet's choices, the organiser's banned list, and the
// neutral copy a banned join gets.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/bans/data/bans_repository.dart';
import 'package:dabbler/features/bans/domain/ban_models.dart';
import 'package:dabbler/features/bans/presentation/banned_people_group.dart';
import 'package:dabbler/features/bans/presentation/remove_with_ban_sheet.dart';
import 'package:dabbler/features/games/presentation/controllers/join_action_toast.dart';
import 'package:dabbler/features/meetups/data/mappers/meetup_failures.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_error_text.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/profile_render_support.dart';

class _FakeBans implements BansRepository {
  _FakeBans(this.bans);
  List<OrganiserBan> bans;
  final lifted = <String>[];

  @override
  Future<Result<List<OrganiserBan>, Failure>> listMyBans() async =>
      Ok(List.of(bans));

  @override
  Future<Result<void, Failure>> liftBan(String banId) async {
    lifted.add(banId);
    bans = bans.where((b) => b.banId != banId).toList();
    return const Ok(null);
  }
}

final _bans = [
  OrganiserBan(
    banId: 'b1',
    scope: BanScope.organiser,
    createdAt: DateTime.utc(2026, 11, 2),
    displayName: 'Lina Haddad',
  ),
  OrganiserBan(
    banId: 'b2',
    scope: BanScope.event,
    createdAt: DateTime.utc(2026, 11, 1),
    displayName: 'Omar Saleh',
    eventTitle: 'Sunday Kickabout',
  ),
  OrganiserBan(
    banId: 'b3',
    scope: BanScope.event,
    createdAt: DateTime.utc(2026, 10, 1),
    displayName: 'Sara Ali',
    eventTitle: 'Tuesday Padel',
    seriesId: 's1',
  ),
];

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  Future<_FakeBans> pumpList(WidgetTester tester, List<OrganiserBan> b) async {
    final repo = _FakeBans(b);
    await pumpProfileScreen(
      tester,
      const Scaffold(body: BannedPeopleGroup()),
      const Locale('en'),
      overrides: [bansRepositoryProvider.overrideWithValue(repo)],
    );
    return repo;
  }

  testWidgets('banned list renders name, scope label and title', (
    tester,
  ) async {
    await pumpList(tester, _bans);
    expect(find.text('Lina Haddad'), findsOneWidget);
    expect(find.textContaining('All your events'), findsOneWidget);
    expect(find.textContaining('Event: Sunday Kickabout'), findsOneWidget);
    expect(find.textContaining('Series: Tuesday Padel'), findsOneWidget);
    expect(find.textContaining('Nov 2, 2026'), findsOneWidget);
  });

  testWidgets('banned list empty state', (tester) async {
    await pumpList(tester, const []);
    expect(find.text(en.ban_list_empty), findsOneWidget);
  });

  testWidgets('unban confirms, lifts and refreshes', (tester) async {
    final repo = await pumpList(tester, _bans);
    await tester.tap(find.byKey(const ValueKey<String>('ban-unban-b2')));
    await settleProfile(tester);
    expect(find.text('Unban Omar Saleh?'), findsOneWidget);
    expect(repo.lifted, isEmpty);
    await tester.tap(find.text('Unban').last);
    await settleProfile(tester);
    expect(repo.lifted, ['b2']);
    expect(find.text('Omar Saleh'), findsNothing);
    expect(find.text('Lina Haddad'), findsOneWidget);
  });

  Future<RemovalChoice?> Function() openSheet(
    WidgetTester tester, {
    required bool isSeries,
  }) {
    RemovalChoice? result;
    var done = false;
    return () async {
      await pumpProfileScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () async {
                result = await showRemoveWithBanSheet(
                  context: context,
                  name: 'Lina',
                  description: 'body',
                  isSeries: isSeries,
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
        const Locale('en'),
      );
      await tester.tap(find.text('open'));
      await settleProfile(tester);
      return done ? result : null;
    };
  }

  for (final scope in BanScope.values) {
    testWidgets('game sheet (series) returns ${scope.wire}', (tester) async {
      RemovalChoice? got;
      await pumpProfileScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () async => got = await showRemoveWithBanSheet(
                context: context,
                name: 'Lina',
                description: 'body',
                isSeries: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
        const Locale('en'),
      );
      await tester.tap(find.text('open'));
      await settleProfile(tester);
      expect(find.text('Remove only'), findsOneWidget);
      expect(find.text('Remove and ban from this series'), findsOneWidget);
      expect(find.text('Remove and ban from this event'), findsNothing);
      expect(find.text('Remove and ban from all my events'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey<String>('ban-scope-${scope.wire}')));
      await tester.pump();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('ban-reason')),
          matching: find.byType(EditableText),
        ),
        '  rude  ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('ban-remove-confirm')),
      );
      await settleProfile(tester);
      expect(got?.scope, scope);
      expect(got?.reason, 'rude');
    });
  }

  testWidgets('non-series sheet says "this event"', (
    tester,
  ) async {
    await openSheet(tester, isSeries: false)();
    expect(find.text('Remove and ban from this event'), findsOneWidget);
    expect(find.text('Remove and ban from this series'), findsNothing);
  });

  test('banned join maps to the neutral message, both surfaces', () {
    expect(joinRefusalMessage(en, 'banned'), "You can't join this event.");
    final f = MeetupFailures.from(
      Exception('PostgrestException(message: banned, code: P0001)'),
    );
    expect(f.code, 'banned');
    expect(meetupErrorText(en, f, 'fallback'), "You can't join this event.");
  });
}
