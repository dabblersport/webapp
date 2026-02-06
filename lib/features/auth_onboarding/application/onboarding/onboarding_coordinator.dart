import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingRouteDecision {
  final String path;
  final Object? extra;

  const OnboardingRouteDecision({required this.path, this.extra});
}

/// Single source of truth for post-auth routing.
///
/// After successful authentication (OTP verification or OAuth), this coordinator
/// determines the next step:
/// - If profile exists in public.profiles → user is onboarded → go to home
/// - If no profile exists → user needs onboarding → go to create_user_information
///
/// This is intentionally READ + ROUTE ONLY:
/// - Reads Supabase auth session
/// - Reads profile existence from DB
/// - Does NOT write onboarding data or mutate profile state
class OnboardingCoordinator {
  final SupabaseClient _client;

  OnboardingCoordinator({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<OnboardingRouteDecision> decidePostAuthRoute({
    String? identifier,
    IdentifierType? identifierType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const OnboardingRouteDecision(path: RoutePaths.landing);
    }

    try {
      // Check if user has a profile in public.profiles
      final profiles = await _client
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .timeout(const Duration(seconds: 5));

      final profileList = List<Map<String, dynamic>>.from(profiles as List);

      // If profile exists, user has completed onboarding → go to home
      if (profileList.isNotEmpty) {
        return const OnboardingRouteDecision(path: RoutePaths.home);
      }

      // No profile exists → user needs to complete onboarding
      // Redirect to create user info screen to create profile
      final extra = _buildCreateUserInfoExtra(
        identifier: identifier,
        identifierType: identifierType,
      );

      return OnboardingRouteDecision(
        path: RoutePaths.createUserInfo,
        extra: extra,
      );
    } catch (_) {
      // Safe fallback: let the router's redirect logic enforce onboarding gating.
      return const OnboardingRouteDecision(path: RoutePaths.home);
    }
  }

  Object? _buildCreateUserInfoExtra({
    required String? identifier,
    required IdentifierType? identifierType,
  }) {
    if (identifier == null || identifier.trim().isEmpty) return null;

    final type = identifierType ?? IdentifierDetector.detect(identifier).type;

    if (type == IdentifierType.email) {
      return {'email': identifier};
    }

    if (type == IdentifierType.phone) {
      return {'phone': identifier};
    }

    return null;
  }
}
