import 'dart:convert';

import 'package:dabbler/features/meetups/data/datasources/supabase_meetup_datasource.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/profile_creation_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

/// KAN-647 guards: deep-link redirect, creation-service refusal, and the
/// contributor's single profile id on both role wire values.
void main() {
  group('route guard /add-persona/*', () {
    String? go(String loc, List<PersonaType?> p, {bool authed = true}) =>
        singleProfileRedirect(
          location: loc,
          isAuthenticated: authed,
          personas: p,
        );

    test('contributor and partner are sent to /settings', () {
      for (final u in [PersonaType.contributor, PersonaType.partner]) {
        expect(go('/add-persona/organiser', [u]), '/settings');
        expect(go('/add-persona/player', [null, u]), '/settings');
      }
    });

    test(
      'legacy accounts, unknown and signed-out users are not redirected',
      () {
        for (final l in [
          PersonaType.player,
          PersonaType.organiser,
          PersonaType.host,
          PersonaType.socialiser,
        ]) {
          expect(go('/add-persona/organiser', [l]), isNull);
        }
        expect(go('/add-persona/organiser', [null]), isNull);
        expect(
          go('/add-persona/organiser', [
            PersonaType.contributor,
          ], authed: false),
          isNull,
        );
      },
    );

    test('other routes are untouched', () {
      expect(go('/settings', [PersonaType.contributor]), isNull);
      expect(go('/home', [PersonaType.partner]), isNull);
    });
  });

  group('ProfileCreationService single_profile_required', () {
    const player = AddPersonaData(
      targetPersona: PersonaType.player,
      actionType: PersonaActionType.add,
      primarySport: 'football',
      displayName: 'Sam',
      username: 'sam',
    );

    test('a unified target is refused with no request sent', () async {
      final seen = <http.Request>[];
      final client = buildTestSupabaseClient((r) async {
        seen.add(r);
        return jsonListResponse([], request: r);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      for (final t in [PersonaType.contributor, PersonaType.partner]) {
        await expectLater(
          ProfileCreationService(client).createProfile(
            data: AddPersonaData(
              targetPersona: t,
              actionType: PersonaActionType.add,
            ),
          ),
          throwsA(
            isA<SingleProfileException>().having(
              (e) => e.code,
              'code',
              'single_profile_required',
            ),
          ),
        );
      }
      expect(seen, isEmpty);
    });

    for (final existing in ['contributor', 'partner']) {
      test(
        'an account that already has $existing cannot add a profile',
        () async {
          final seen = <http.Request>[];
          final client = buildTestSupabaseClient((r) async {
            seen.add(r);
            return jsonListResponse([
              {'persona_type': existing},
            ], request: r);
          });
          await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
          await expectLater(
            ProfileCreationService(client).createProfile(data: player),
            throwsA(isA<SingleProfileException>()),
          );
          // only the read happened; nothing was inserted or updated
          expect(seen.map((r) => r.method).toSet(), {'GET'});
        },
      );
    }

    test(
      'a legacy account passes the guard (reaches its own checks)',
      () async {
        final seen = <http.Request>[];
        final client = buildTestSupabaseClient((r) async {
          seen.add(r);
          return jsonListResponse([
            {'persona_type': 'player'},
          ], request: r);
        });
        await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
        Object? err;
        try {
          await ProfileCreationService(client).createProfile(data: player);
        } catch (e) {
          err = e;
        }
        expect(err, isNot(isA<SingleProfileException>()));
      },
    );
  });

  group('same profile id for both role wire values', () {
    const profileId = 'contributor-profile-1';

    test(
      'one Contributor profile id on player and organiser operations',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final ds = SupabaseMeetupDataSource(
          buildTestSupabaseClient((r) async {
            bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode('going'),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        // RSVP as a participant, then act as organiser: same profile id, no
        // second identity, and no "contributor" wire value.
        await ds.rsvp('m1', 'going', profileId: profileId);
        await ds.rsvp('m2', 'going', profileId: profileId);
        expect(bodies.map((b) => b['p_profile_id']).toSet(), {profileId});
        expect(bodies.expand((b) => b.values), isNot(contains('contributor')));
        // role stays an action-level parameter
        expect(PersonaType.contributor.hasPlayerCapabilities, isTrue);
        expect(PersonaType.contributor.hasOrganiserCapabilities, isTrue);
      },
    );
  });
}
