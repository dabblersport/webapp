import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, this.onboardingData});

  /// Optional onboarding data passed from the email signup flow
  /// Contains keys: email, displayName, age, gender, intention,
  /// preferredSport, interests (List<String>), username
  final Map<String, dynamic>? onboardingData;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic>? _storedOnboardingData;

  SupabaseClient get _client => Supabase.instance.client;

  static const String _onboardingDataKey = 'pending_email_onboarding_data';

  @override
  void initState() {
    super.initState();
    _loadStoredOnboardingData();
    _saveOnboardingDataIfPresent();
  }

  Future<void> _loadStoredOnboardingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = prefs.getString(_onboardingDataKey);
      if (dataJson != null) {
        setState(() {
          _storedOnboardingData = Map<String, dynamic>.from(
            json.decode(dataJson) as Map,
          );
        });
      }
    } catch (e) {}
  }

  Future<void> _saveOnboardingDataIfPresent() async {
    if (widget.onboardingData != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _onboardingDataKey,
          json.encode(widget.onboardingData),
        );
        setState(() {
          _storedOnboardingData = widget.onboardingData;
        });
      } catch (e) {}
    }
  }

  Future<void> _clearStoredOnboardingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingDataKey);
    } catch (e) {}
  }

  Map<String, dynamic>? get _onboardingData {
    return widget.onboardingData ?? _storedOnboardingData;
  }

  String? get _userEmail {
    final currentEmail = _client.auth.currentUser?.email;
    if (currentEmail != null && currentEmail.isNotEmpty) {
      return currentEmail;
    }
    final data = _onboardingData;
    if (data != null) {
      final extraEmail = data['email'] as String?;
      if (extraEmail != null && extraEmail.isNotEmpty) {
        return extraEmail;
      }
    }
    return null;
  }

  Future<void> _resendEmail() async {
    final email = _userEmail;
    if (email == null || email.isEmpty) {
      setState(() {
        _errorMessage = 'No email found for the current user.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      setState(() {
        _successMessage =
            'If you don\'t see the email, please check your spam folder or request a new link from the sign-in screen.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend confirmation email: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _checkEmailConfirmed() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Refresh session first in case they got one from email confirmation link
      try {
        await _client.auth.refreshSession();
      } catch (_) {
        // Session refresh failed, might not be authenticated yet
      }

      final response = await _client.auth.getUser();
      final user = response.user;

      if (user == null) {
        // User is not authenticated - they need to sign in first
        final email = _userEmail;
        if (email != null && mounted) {
          // Redirect to sign in screen with their email
          context.go(RoutePaths.enterPassword, extra: email);
          return;
        }
        setState(() {
          _errorMessage =
              'Please sign in first. After confirming your email, you need to sign in with your password.';
        });
        return;
      }

      // Check if user is authenticated (has active session)
      final isAuthenticated = _client.auth.currentSession != null;
      if (!isAuthenticated) {
        // Session expired or not present - redirect to sign in
        final email = _userEmail ?? user.email;
        if (email != null && mounted) {
          context.go(RoutePaths.enterPassword, extra: email);
          return;
        }
        setState(() {
          _errorMessage =
              'Your session has expired. Please sign in with your password to continue.';
        });
        return;
      }

      if (user.emailConfirmedAt == null) {
        setState(() {
          _errorMessage =
              'Your email is not confirmed yet. Please click the link in your inbox and try again.';
        });
        return;
      }

      // Email is confirmed - ensure profile exists
      try {
        final authService = AuthService();

        // Check if profile already exists
        final existingProfile = await authService.getUserProfile(
          fields: ['id'],
        );

        if (existingProfile == null) {
          final data = _onboardingData ?? const <String, dynamic>{};

          final displayName =
              (data['displayName'] as String?) ??
              (user.email != null ? user.email!.split('@').first : 'Player');
          final username =
              (data['username'] as String?) ??
              displayName.toLowerCase().replaceAll(' ', '');
          final age = (data['age'] as int?) ?? 18;
          final gender = (data['gender'] as String?) ?? 'unspecified';
          final intention =
              (data['intention'] as String?) ?? 'compete'; // default player
          final preferredSport =
              (data['preferredSport'] as String?) ?? 'football';
          final interestsList = data['interests'] is List
              ? data['interests'] as List
              : null;
          final interestsString = interestsList?.whereType<String>().join(',');

          await authService.createProfile(
            userId: user.id,
            displayName: displayName,
            username: username,
            age: age,
            gender: gender,
            intention: intention,
            preferredSport: preferredSport,
            interests: interestsString,
          );

          // Clear stored onboarding data after successful profile creation
          await _clearStoredOnboardingData();
        } else {}

        // Optionally mark profile as verified in public.profiles
        try {
          if (SupabaseConfig.enableEmailConfirmations) {
            await _client
                .from(SupabaseConfig.usersTable)
                .update({'verified': true})
                .eq('user_id', user.id);
          }
        } catch (e) {
          // Non-critical: profile can remain unverified even if email is confirmed
        }
      } catch (e) {
        setState(() {
          _errorMessage =
              'Email confirmed but failed to create your profile: $e';
        });
        return;
      }

      if (!mounted) return;

      // Email confirmed and profile created - navigate to home
      context.go(RoutePaths.home);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to check email status: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _userEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm your email'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Check your inbox',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                email != null
                    ? 'We\'ve sent a confirmation link to $email.\n\nPlease confirm your email to finish setting up your account.'
                    : 'We\'ve sent a confirmation link to your email.\n\nPlease confirm your email to finish setting up your account.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'After confirming your email, come back to the app and tap "I\'ve confirmed my email" to continue.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkEmailConfirmed,
                icon: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('I\'ve confirmed my email'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isResending ? null : _resendEmail,
                icon: _isResending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.email_outlined),
                label: const Text('Resend confirmation email'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              if (_successMessage != null)
                Text(
                  _successMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(RoutePaths.phoneInput),
                child: const Text('Use a different account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
