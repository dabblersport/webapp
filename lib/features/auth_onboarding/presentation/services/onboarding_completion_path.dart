import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/data/unified_onboarding_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';

/// KAN-648: which write completes onboarding.
enum OnboardingCompletionPath {
  /// New account: `rpc_onboard_unified_profile`.
  unified,

  /// An explicitly existing legacy profile resuming its old flow:
  /// `createProfileStep`. A persona is never guessed for it.
  legacyContinuation,
}

/// The unified RPC is for a new account that made the four-intention choice.
/// A legacy profile resuming (KAN-602's resume state) or a flow that never
/// recorded an intention stays on the legacy continuation.
OnboardingCompletionPath onboardingCompletionPath(
  RegistrationOnboardingData data, {
  required bool resumingLegacyProfile,
}) {
  if (resumingLegacyProfile || data.onboardingIntention == null) {
    return OnboardingCompletionPath.legacyContinuation;
  }
  return OnboardingCompletionPath.unified;
}

/// Following (interests) always contains the Primary sport.
List<String>? interestsWithPrimary(RegistrationOnboardingData data) {
  final primary = data.preferredSport;
  final interests = data.interests;
  if (primary == null || primary.isEmpty) return interests;
  final list = [...?interests];
  if (!list.contains(primary)) list.insert(0, primary);
  return list;
}

/// The unified-RPC input, with Primary in Following and the resolved
/// location. Null while a required field is missing.
UnifiedOnboardingInput? unifiedInputFor(
  RegistrationOnboardingData data, {
  String? country,
  String? city,
}) {
  final base = data.toUnifiedInput();
  if (base == null) return null;
  return UnifiedOnboardingInput(
    displayName: base.displayName,
    username: base.username,
    age: base.age,
    gender: base.gender,
    intention: base.intention,
    preferredSport: base.preferredSport,
    interests: interestsWithPrimary(data),
    country: country ?? base.country,
    city: city ?? base.city,
  );
}

/// The writes completion performs, behind one seam so the screen can be
/// tested without a live Supabase client.
abstract class OnboardingCompletionGateway {
  Future<void> syncAuthMetadata({
    required String displayName,
    required String username,
  });

  Future<Result<String, UnifiedOnboardingFailure>> onboardUnified(
    UnifiedOnboardingInput input,
  );

  Future<void> ensureAvatar(String profileId);

  /// The legacy continuation: `createProfileStep`.
  Future<void> createLegacy({
    required RegistrationOnboardingData data,
    String? country,
    String? city,
  });
}

class AuthServiceCompletionGateway implements OnboardingCompletionGateway {
  const AuthServiceCompletionGateway();

  @override
  Future<void> syncAuthMetadata({
    required String displayName,
    required String username,
  }) => AuthService().syncOnboardingAuthMetadata(
    displayName: displayName,
    username: username,
  );

  @override
  Future<Result<String, UnifiedOnboardingFailure>> onboardUnified(
    UnifiedOnboardingInput input,
  ) => AuthService().onboardUnifiedProfile(input);

  @override
  Future<void> ensureAvatar(String profileId) =>
      AuthService().ensureOnboardingAvatar(profileId);

  @override
  Future<void> createLegacy({
    required RegistrationOnboardingData data,
    String? country,
    String? city,
  }) => AuthService().createProfileStep(
    displayName: data.displayName ?? '',
    username: data.username ?? '',
    age: data.age ?? 18,
    gender: data.gender,
    intention: data.intention ?? 'player',
    preferredSport: data.preferredSport ?? '',
    interests: data.interests,
    country: country,
    city: city,
    password: null,
  );
}

final onboardingCompletionGatewayProvider =
    Provider<OnboardingCompletionGateway>(
      (ref) => const AuthServiceCompletionGateway(),
    );
