import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/auth_onboarding/data/onboarding_intention_store.dart';
import 'package:dabbler/features/auth_onboarding/data/unified_onboarding_client.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_intention.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_state.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-650: the intention model, its carry-through, the unified RPC client and
/// the typed-error messages. No screen is involved.
void main() {
  const uuid = '11111111-2222-3333-4444-555555555555';

  group('OnboardingIntention', () {
    test('stable keys and the fixed persona mapping', () {
      expect(OnboardingIntention.values.map((i) => i.key), [
        'connect_play',
        'play_organise',
        'organise',
        'host_games',
      ]);
      expect(OnboardingIntention.connectPlay.targetPersona, 'contributor');
      expect(OnboardingIntention.playOrganise.targetPersona, 'contributor');
      expect(OnboardingIntention.organise.targetPersona, 'contributor');
      expect(OnboardingIntention.hostGames.targetPersona, 'partner');
    });

    test('fromKey never invents a choice and never reads a label', () {
      expect(
        OnboardingIntention.fromKey('host_games'),
        OnboardingIntention.hostGames,
      );
      expect(OnboardingIntention.fromKey(null), isNull);
      expect(OnboardingIntention.fromKey(''), isNull);
      expect(OnboardingIntention.fromKey('Host games'), isNull);
      expect(OnboardingIntention.fromKey('compete'), isNull);
    });

    test('is separate from persona on the freezed onboarding data', () {
      const data = OnboardingData(
        personaType: 'player',
        onboardingIntention: OnboardingIntention.hostGames,
      );
      expect(data.personaType, 'player');
      expect(data.onboardingIntention, OnboardingIntention.hostGames);
      expect(
        data.copyWith(personaType: 'host').onboardingIntention,
        OnboardingIntention.hostGames,
      );
    });
  });

  group('carry-through', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('survives navigation: toMap/fromMap carries the key only', () {
      final data = RegistrationOnboardingData(
        email: 'a@b.co',
        onboardingIntention: OnboardingIntention.playOrganise,
      );
      final map = data.toMap();
      expect(map['onboardingIntention'], 'play_organise');
      expect(
        RegistrationOnboardingData.fromMap(map).onboardingIntention,
        OnboardingIntention.playOrganise,
      );
      // The legacy persona field is untouched by it.
      expect(map['intention'], isNull);
    });

    test('a map without or with a bad key has no intention, not a default', () {
      final none = RegistrationOnboardingData.fromMap({'email': 'a@b.co'});
      expect(none.onboardingIntention, isNull);
      expect(none.hasOnboardingIntention, isFalse);
      final label = RegistrationOnboardingData.fromMap({
        'email': 'a@b.co',
        'onboardingIntention': 'Connect & play',
      });
      expect(label.onboardingIntention, isNull);
    });

    test('a choice made before sign-in survives email and phone auth', () {
      final notifier = OnboardingDataNotifier();
      notifier.setOnboardingIntention(OnboardingIntention.organise);
      expect(notifier.state, isNull);
      notifier.initWithEmail('a@b.co');
      expect(notifier.state!.onboardingIntention, OnboardingIntention.organise);
      notifier.initWithPhone('+971500000000');
      expect(notifier.state!.onboardingIntention, OnboardingIntention.organise);
    });

    test('a choice made after sign-in lands on the state', () {
      final notifier = OnboardingDataNotifier()..initWithEmail('a@b.co');
      notifier.setOnboardingIntention(OnboardingIntention.hostGames);
      expect(
        notifier.state!.onboardingIntention,
        OnboardingIntention.hostGames,
      );
    });

    test(
      'Google/Apple continuation: state restarted from the stored key',
      () async {
        final first = OnboardingDataNotifier();
        first.setOnboardingIntention(OnboardingIntention.connectPlay);
        await Future<void>.delayed(Duration.zero);
        // App restarted: a new notifier has nothing in memory.
        final second = OnboardingDataNotifier();
        expect(second.onboardingIntention, isNull);
        await second.restoreOnboardingIntention();
        expect(second.onboardingIntention, OnboardingIntention.connectPlay);
        second.initWithEmail('a@b.co');
        expect(
          second.state!.onboardingIntention,
          OnboardingIntention.connectPlay,
        );
      },
    );

    test('the store keeps the key, never a label', () async {
      await const OnboardingIntentionStore().save(
        OnboardingIntention.hostGames,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(OnboardingIntentionStore.prefsKey), 'host_games');
    });

    test('clear drops it everywhere', () async {
      final notifier = OnboardingDataNotifier()..initWithEmail('a@b.co');
      notifier.setOnboardingIntention(OnboardingIntention.organise);
      // Let the unawaited save settle first, so clear() is the last write.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.clear();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.onboardingIntention, isNull);
      expect(await const OnboardingIntentionStore().load(), isNull);
    });

    test('toUnifiedInput needs the intention; no silent default', () {
      final base = RegistrationOnboardingData(
        email: 'a@b.co',
        displayName: 'Sam',
        username: 'sam',
        age: 30,
      );
      expect(base.toUnifiedInput(), isNull);
      final input = base
          .copyWith(onboardingIntention: OnboardingIntention.organise)
          .toUnifiedInput();
      expect(input!.intention, OnboardingIntention.organise);
    });
  });

  group('rpc_onboard_unified_profile client', () {
    late List<http.Request> requests;

    UnifiedOnboardingClient clientFor(
      http.Response Function(http.Request) respond, {
      String? userId = 'auth-owner-id',
    }) {
      requests = [];
      final mock = MockClient((r) async {
        requests.add(r);
        return http.Response(
          respond(r).body,
          respond(r).statusCode,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      });
      final supabase = SupabaseClient(
        'http://localhost:54321',
        'anon-key',
        httpClient: mock,
      );
      return UnifiedOnboardingClient(
        supabase,
        resolveCountryCode: (c) async => c == 'United Arab Emirates' ? 'AE' : c,
        currentUserId: () => userId,
      );
    }

    const input = UnifiedOnboardingInput(
      displayName: 'Sam',
      username: 'sam',
      age: 30,
      gender: 'male',
      intention: OnboardingIntention.hostGames,
      preferredSport: 'sport-uuid',
      interests: ['s1', 's2'],
      country: 'United Arab Emirates',
      city: 'Dubai',
    );

    test('constant is the contract name', () {
      expect(
        SupabaseConfig.rpcOnboardUnifiedProfileFn,
        'rpc_onboard_unified_profile',
      );
    });

    test(
      'calls the exact RPC with the exact parameter map and returns the uuid',
      () async {
        final client = clientFor((r) => http.Response(jsonEncode(uuid), 200));
        final result = await client.onboard(input);

        expect(result.isSuccess, isTrue);
        expect(result.requireValue, uuid);
        expect(requests, hasLength(1));
        final r = requests.single;
        expect(r.method, 'POST');
        expect(
          r.url.path,
          '/rest/v1/rpc/${SupabaseConfig.rpcOnboardUnifiedProfileFn}',
        );
        expect(jsonDecode(r.body), {
          'p_user_id': 'auth-owner-id',
          'p_display_name': 'Sam',
          'p_username': 'sam',
          'p_age': 30,
          'p_gender': 'male',
          'p_onboarding_intention': 'host_games',
          'p_preferred_sport': 'sport-uuid',
          'p_interests': ['s1', 's2'],
          'p_country': 'AE',
          'p_city': 'Dubai',
        });
      },
    );

    test(
      'makes no legacy RPC, extension insert or profile_tiers insert',
      () async {
        final client = clientFor((r) => http.Response(jsonEncode(uuid), 200));
        await client.onboard(input);
        final paths = requests.map((r) => r.url.path).toList();
        expect(paths, ['/rest/v1/rpc/rpc_onboard_unified_profile']);
        expect(paths.any((p) => p.contains('rpc_onboard_profile')), isFalse);
        expect(paths.any((p) => p.contains('profile_tiers')), isFalse);
        expect(paths.any((p) => p.contains('extension')), isFalse);
        expect(requests.every((r) => r.method == 'POST'), isTrue);
      },
    );

    test('optional values are explicit nulls, empty lists are null', () async {
      final client = clientFor((r) => http.Response(jsonEncode(uuid), 200));
      await client.onboard(
        const UnifiedOnboardingInput(
          displayName: 'Sam',
          username: 'sam',
          age: 30,
          intention: OnboardingIntention.connectPlay,
          preferredSport: '',
          interests: [],
        ),
      );
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'p_user_id',
        'p_display_name',
        'p_username',
        'p_age',
        'p_gender',
        'p_onboarding_intention',
        'p_preferred_sport',
        'p_interests',
        'p_country',
        'p_city',
      });
      expect(body['p_gender'], isNull);
      expect(body['p_preferred_sport'], isNull);
      expect(body['p_interests'], isNull);
      expect(body['p_onboarding_intention'], 'connect_play');
    });

    test('retry reuses the same input and the same intention key', () async {
      var calls = 0;
      final client = clientFor((r) {
        calls++;
        return calls == 1
            ? http.Response(
                jsonEncode({'code': 'P0001', 'message': 'timeout-ish'}),
                400,
              )
            : http.Response(jsonEncode(uuid), 200);
      });
      final first = await client.onboard(input);
      expect(first.isFailure, isTrue);
      final second = await client.onboard(input);
      expect(second.requireValue, uuid);
      expect(requests[0].body, requests[1].body);
    });

    test('no signed-in user: no request is made', () async {
      final client = clientFor(
        (r) => http.Response(jsonEncode(uuid), 200),
        userId: null,
      );
      final result = await client.onboard(input);
      expect(result.requireError.error, UnifiedOnboardingError.unknown);
      expect(requests, isEmpty);
    });

    test('each typed error code maps to its own error', () async {
      for (final error in UnifiedOnboardingError.values) {
        if (error == UnifiedOnboardingError.unknown) continue;
        final client = clientFor(
          (r) => http.Response(
            jsonEncode({'code': 'P0001', 'message': error.code}),
            400,
          ),
        );
        final result = await client.onboard(input);
        expect(result.requireError.error, error, reason: error.code);
      }
    });

    test('a code in details or hint is found too', () {
      expect(
        UnifiedOnboardingError.fromPostgrest(
          const PostgrestException(
            message: 'raise',
            details: 'persona_change_not_supported',
          ),
        ),
        UnifiedOnboardingError.personaChangeNotSupported,
      );
      expect(
        UnifiedOnboardingError.fromPostgrest(
          const PostgrestException(
            message: 'raise',
            hint: 'single_profile_required',
          ),
        ),
        UnifiedOnboardingError.singleProfileRequired,
      );
    });

    test('an unknown code falls back to unknown', () async {
      final client = clientFor(
        (r) => http.Response(
          jsonEncode({
            'code': '42P01',
            'message': 'relation "x" does not exist',
          }),
          400,
        ),
      );
      final result = await client.onboard(input);
      expect(result.requireError.error, UnifiedOnboardingError.unknown);
    });
  });

  group('localized error messages', () {
    test(
      'eight distinct EN messages, a generic fallback, no raw DB text',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final named = UnifiedOnboardingError.values
            .where((e) => e != UnifiedOnboardingError.unknown)
            .toList();
        expect(named, hasLength(8));
        final messages = named.map((e) => e.message(l10n)).toList();
        expect(messages.toSet(), hasLength(8));
        for (final m in messages) {
          expect(m.trim(), isNotEmpty);
          expect(m, isNot(contains('_')));
        }
        final generic = UnifiedOnboardingError.unknown.message(l10n);
        expect(generic, l10n.onb_error_generic);
        expect(messages, isNot(contains(generic)));
      },
    );

    test('Arabic loads for every error', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      for (final e in UnifiedOnboardingError.values) {
        expect(e.message(l10n).trim(), isNotEmpty);
      }
    });
  });

  group('copy', () {
    test('EN strings are exactly as specified', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.onb_intention_title, 'What brings you to Dabbler?');
      expect(
        l10n.onb_intention_subtitle,
        'Choose what brings you here. Your choice helps us understand your goals.',
      );
      expect(OnboardingIntention.values.map((i) => i.label(l10n)).toList(), [
        'Connect & play',
        'Play & organise',
        'Organise',
        'Host games',
      ]);
      expect(l10n.onb_intention_continue, 'Continue');
    });

    test('AR reuses approved wording for Organise and Continue', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(l10n.onb_intention_organise, 'نظّم');
      expect(l10n.onb_intention_continue, 'المتابعة');
    });
  });
}
