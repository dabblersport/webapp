import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_intention.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The codes `rpc_onboard_unified_profile` can raise (S2 contract).
enum UnifiedOnboardingError {
  legacyProfileRequiresExistingFlow('legacy_profile_requires_existing_flow'),
  profileMigrationRequired('profile_migration_required'),
  personaChangeNotSupported('persona_change_not_supported'),
  singleProfileRequired('single_profile_required'),
  personaConversionBlocked('persona_conversion_blocked'),
  personaWriteViaRpcOnly('persona_write_via_rpc_only'),
  onboardingIntentionMismatch('onboarding_intention_mismatch'),
  contributorSportsIncomplete('contributor_sports_incomplete'),

  /// Anything else: shown as the generic message, never as database text.
  unknown('unknown');

  const UnifiedOnboardingError(this.code);
  final String code;

  /// Finds the contract code in a Postgres error. The code can arrive as the
  /// message, the details, the hint or the SQLSTATE-style code field.
  static UnifiedOnboardingError fromPostgrest(PostgrestException e) {
    final fields = [e.message, e.details?.toString(), e.hint, e.code];
    for (final error in values) {
      if (error == unknown) continue;
      if (fields.any((f) => f != null && f.contains(error.code))) return error;
    }
    return unknown;
  }

  /// A human message in the current locale. No raw database text.
  String message(AppLocalizations l10n) => switch (this) {
    legacyProfileRequiresExistingFlow =>
      l10n.onb_error_legacy_profile_requires_existing_flow,
    profileMigrationRequired => l10n.onb_error_profile_migration_required,
    personaChangeNotSupported => l10n.onb_error_persona_change_not_supported,
    singleProfileRequired => l10n.onb_error_single_profile_required,
    personaConversionBlocked => l10n.onb_error_persona_conversion_blocked,
    personaWriteViaRpcOnly => l10n.onb_error_persona_write_via_rpc_only,
    onboardingIntentionMismatch => l10n.onb_error_onboarding_intention_mismatch,
    contributorSportsIncomplete => l10n.onb_error_contributor_sports_incomplete,
    unknown => l10n.onb_error_generic,
  };
}

class UnifiedOnboardingFailure {
  const UnifiedOnboardingFailure(this.error, {this.cause});
  final UnifiedOnboardingError error;
  final Object? cause;
}

/// Everything the unified RPC needs. Held unchanged so a retry sends the same
/// input and the same intention key.
class UnifiedOnboardingInput {
  const UnifiedOnboardingInput({
    required this.displayName,
    required this.username,
    required this.age,
    required this.intention,
    this.gender,
    this.preferredSport,
    this.interests,
    this.country,
    this.city,
  });

  final String displayName;
  final String username;
  final int age;
  final String? gender;
  final OnboardingIntention intention;
  final String? preferredSport;
  final List<String>? interests;
  final String? country;
  final String? city;
}

/// KAN-650: the one server call that creates a new account's profile.
/// It does not set `onboard`, call the legacy onboarding RPC, or write
/// extension or tier rows: the server does all of that in one transaction.
class UnifiedOnboardingClient {
  UnifiedOnboardingClient(
    this._client, {
    required Future<String?> Function(String? country) resolveCountryCode,
    String? Function()? currentUserId,
  }) : _resolveCountryCode = resolveCountryCode,
       _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final Future<String?> Function(String? country) _resolveCountryCode;
  final String? Function() _currentUserId;

  /// The server's new profile id, or the typed reason it refused.
  Future<Result<String, UnifiedOnboardingFailure>> onboard(
    UnifiedOnboardingInput input,
  ) {
    return Result.guard(() async {
      final userId = _currentUserId();
      if (userId == null) {
        throw const UnifiedOnboardingFailure(UnifiedOnboardingError.unknown);
      }
      final countryCode = await _resolveCountryCode(input.country);
      final response = await _client.rpc(
        SupabaseConfig.rpcOnboardUnifiedProfileFn,
        params: {
          'p_user_id': userId,
          'p_display_name': input.displayName,
          'p_username': input.username,
          'p_age': input.age,
          'p_gender': input.gender,
          'p_onboarding_intention': input.intention.key,
          'p_preferred_sport':
              (input.preferredSport == null || input.preferredSport!.isEmpty)
              ? null
              : input.preferredSport,
          'p_interests': (input.interests == null || input.interests!.isEmpty)
              ? null
              : input.interests,
          'p_country': countryCode,
          'p_city': input.city,
        },
      );
      if (response is! String || response.isEmpty) {
        throw const UnifiedOnboardingFailure(UnifiedOnboardingError.unknown);
      }
      return response;
    }, _toFailure);
  }

  static UnifiedOnboardingFailure _toFailure(Object e) {
    if (e is UnifiedOnboardingFailure) return e;
    if (e is PostgrestException) {
      return UnifiedOnboardingFailure(
        UnifiedOnboardingError.fromPostgrest(e),
        cause: e,
      );
    }
    return UnifiedOnboardingFailure(UnifiedOnboardingError.unknown, cause: e);
  }
}
