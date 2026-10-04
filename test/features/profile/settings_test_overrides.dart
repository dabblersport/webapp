/// Provider overrides that give the Settings root the data states the design
/// frame shows: privacy, notification, block, country and persona data all
/// loaded, without touching Supabase.
library;

import 'dart:convert';

import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/controllers/privacy_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakePrivacy extends PrivacyController {
  _FakePrivacy() : super() {
    state = const PrivacyState(settings: PrivacySettings());
  }

  @override
  Future<void> loadPrivacySettings(String userId) async {}
}

class FakeNotificationSettings
    extends StateNotifier<NotificationSettingsState>
    implements NotificationSettingsController {
  FakeNotificationSettings(NotificationSettings settings)
    : super(NotificationSettingsState(settings: settings, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeCountry extends StateNotifier<AsyncValue<String>>
    implements SelectedCountryNotifier {
  _FakeCountry(String country) : super(AsyncValue.data(country));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePersona extends PersonaServiceNotifier {
  _FakePersona(SupabaseClient client) : super(client) {
    state = const PersonaState(
      activeProfiles: [
        ActivePersonaProfile(
          profileId: 'p1',
          personaType: PersonaType.player,
          displayName: 'Dabbler',
        ),
      ],
    );
  }

  @override
  Future<void> fetchUserPersonas() async {}
}

/// All the overrides, with the country the tile shows.
List<Override> settingsDataOverrides({String country = 'Egypt'}) => [
  privacyControllerProvider.overrideWith((ref) => _FakePrivacy()),
  notificationSettingsControllerProvider.overrideWith(
    (ref) => FakeNotificationSettings(
      const NotificationSettings(
        userId: 'u1',
        pushEnabled: true,
        emailEnabled: true,
        quietStartMin: 23 * 60,
        quietEndMin: 7 * 60,
      ),
    ),
  ),
  blockedUsersWithProfilesProvider.overrideWith(
    (ref) async => [
      {'id': 'a'},
      {'id': 'b'},
      {'id': 'c'},
    ],
  ),
  selectedCountryProvider.overrideWith((ref) => _FakeCountry(country)),
  personaServiceProvider.overrideWith(
    (ref) => _FakePersona(Supabase.instance.client),
  ),
];

/// Signs a fake user into the test Supabase client (no network: the session is
/// recovered from a hand-built, far-future token) so identity rows show an
/// email like the design frame does.
Future<void> signInFakeUser({String email = 'dabbler.pro@proton.me'}) async {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime(2100).millisecondsSinceEpoch ~/ 1000;
  final token =
      '${b64({'alg': 'none', 'typ': 'JWT'})}.${b64({'sub': 'u1', 'exp': exp})}.sig';
  final session = {
    'access_token': token,
    'refresh_token': 'r',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'user': {
      'id': 'u1',
      'aud': 'authenticated',
      'email': email,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
  await Supabase.instance.client.auth.recoverSession(jsonEncode(session));
}
