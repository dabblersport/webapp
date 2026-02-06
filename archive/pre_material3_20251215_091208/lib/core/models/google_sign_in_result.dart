/// Result of Google sign-in flow, indicating which path the user should take
sealed class GoogleSignInResult {
  const GoogleSignInResult();
}

/// New Google user with email only - needs full onboarding flow
class GoogleSignInResultGoToOnboarding extends GoogleSignInResult {
  final String email;

  const GoogleSignInResultGoToOnboarding({required this.email});
}

/// New Google user with email only - needs username onboarding (deprecated - use GoToOnboarding)
class GoogleSignInResultGoToSetUsername extends GoogleSignInResult {
  final String email;
  final String suggestedUsername;

  const GoogleSignInResultGoToSetUsername({
    required this.email,
    required this.suggestedUsername,
  });
}

/// New Google user with email + phone - needs phone OTP verification
class GoogleSignInResultGoToPhoneOtp extends GoogleSignInResult {
  final String phone;
  final String email;

  const GoogleSignInResultGoToPhoneOtp({
    required this.phone,
    required this.email,
  });
}

/// Existing user who previously logged in with Google - direct login
class GoogleSignInResultGoToHome extends GoogleSignInResult {
  const GoogleSignInResultGoToHome();
}

/// Existing user with non-Google account - requires password
class GoogleSignInResultRequirePassword extends GoogleSignInResult {
  final String email;

  const GoogleSignInResultRequirePassword({required this.email});
}

/// Error occurred during Google sign-in flow
class GoogleSignInResultError extends GoogleSignInResult {
  final String message;

  const GoogleSignInResultError({required this.message});
}
