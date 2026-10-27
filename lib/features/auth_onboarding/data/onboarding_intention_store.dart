import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_intention.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-650: keeps the chosen intention across an interrupted onboarding (app
/// killed between the choice and the account being created). Stores the
/// stable key, never a label. Storage is a convenience: every call is
/// guarded and the flow works without it.
class OnboardingIntentionStore {
  const OnboardingIntentionStore();

  static const prefsKey = 'onboarding.intention';

  Future<void> save(OnboardingIntention intention) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, intention.key);
    } catch (_) {}
  }

  Future<OnboardingIntention?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return OnboardingIntention.fromKey(prefs.getString(prefsKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
    } catch (_) {}
  }
}
