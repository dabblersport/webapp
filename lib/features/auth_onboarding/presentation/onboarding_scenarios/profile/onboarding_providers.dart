import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/features/profile/services/onboarding_controller.dart';
import 'package:dabbler/features/profile/services/onboarding_gamification.dart';

final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final onboardingControllerProvider =
    ChangeNotifierProvider<OnboardingController>((ref) {
      final supabase = ref.read(_supabaseClientProvider);
      return OnboardingController(supabase: supabase);
    });

final onboardingGamificationProvider = Provider<OnboardingGamification>((ref) {
  final supabase = ref.read(_supabaseClientProvider);
  return OnboardingGamification(supabase: supabase);
});
