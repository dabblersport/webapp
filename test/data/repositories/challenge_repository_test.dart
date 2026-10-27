import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/core/errors/challenge_failures.dart';
import 'package:dabbler/l10n/app_localizations_ar.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/data/repositories/challenge_repository_impl.dart';

import '../../helpers/supabase_test_client.dart';

/// KAN-680: `createChallenge` sends the five named params of the 5-argument
/// `rpc_challenge_create` (KAN-678) and maps its three server errors.
/// Runs against a mock HTTP client; the live database is never called.
void main() {
  late List<http.Request> sent;
  late ChallengeRepositoryImpl repo;
  late http.Response Function(http.Request) respond;

  setUp(() {
    sent = [];
    respond = (r) => jsonListResponse([
      {'id': 'c-1', 'title': 'Padel night', 'visibility': 'public'},
    ], request: r);
    final client = buildTestSupabaseClient((request) async {
      sent.add(request);
      return respond(request);
    });
    repo = ChallengeRepositoryImpl(
      SupabaseService(client, SupabaseErrorMapper()),
    );
  });

  Future<dynamic> create({String sport = 'padel', String? description}) =>
      repo.createChallenge(
        profileType: 'organiser',
        title: 'Padel night',
        visibility: 'public',
        sport: sport,
        description: description,
      );

  test('calls rpc_challenge_create with the five named params', () async {
    final result = await create(description: 'Friendly');

    expect(result.isSuccess, isTrue);
    expect(sent, hasLength(1));
    expect(
      sent.single.url.pathSegments.last,
      SupabaseConfig.rpcChallengeCreateFn,
    );
    expect(jsonDecode(sent.single.body), {
      'p_profile_type': 'organiser',
      'p_title': 'Padel night',
      'p_visibility': 'public',
      'p_sport': 'padel',
      'p_description': 'Friendly',
    });
    expect(result.requireValue.id, 'c-1');
  });

  test('a blank sport is rejected before any call', () async {
    for (final blank in ['', '   ']) {
      final result = await create(sport: blank);
      expect(result.isFailure, isTrue);
      expect(result.requireError, isA<ChallengeSportRequiredFailure>());
    }
    expect(sent, isEmpty);
  });

  Future<void> expectMapped(String serverCode, Type type) async {
    respond = (r) =>
        postgrestErrorResponse(message: serverCode, code: 'P0001', request: r);
    final result = await create();
    expect(result.isFailure, isTrue);
    expect(result.requireError.runtimeType, type);
  }

  test('maps sport_required, invalid_sport and organiser_required', () async {
    await expectMapped('sport_required', ChallengeSportRequiredFailure);
    await expectMapped('invalid_sport', ChallengeInvalidSportFailure);
    await expectMapped('organiser_required', ChallengeOrganiserRequiredFailure);
  });

  test(
    'an unrelated server error is not mapped to a challenge failure',
    () async {
      respond = (r) => postgrestErrorResponse(
        message: 'visibility_invalid',
        code: 'P0001',
        request: r,
      );
      final result = await create();
      expect(result.isFailure, isTrue);
      expect(result.requireError, isNot(isA<ChallengeCreateFailure>()));
    },
  );

  test('each failure has English and Arabic copy', () {
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();
    for (final f in <ChallengeCreateFailure>[
      const ChallengeSportRequiredFailure(),
      const ChallengeInvalidSportFailure(),
      const ChallengeOrganiserRequiredFailure(),
    ]) {
      expect(f.localizedMessage(en), isNotEmpty);
      expect(f.localizedMessage(ar), isNotEmpty);
      expect(f.localizedMessage(ar), isNot(f.localizedMessage(en)));
    }
  });
}
