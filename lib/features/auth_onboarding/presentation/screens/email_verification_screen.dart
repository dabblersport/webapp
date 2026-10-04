import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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
        _errorMessage = AppLocalizations.of(
          context,
        ).email_verify_no_email_error;
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
        _successMessage = AppLocalizations.of(context).email_verify_spam_note;
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
    final l10n = AppLocalizations.of(context);
    final email = _userEmail;

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(title: l10n.email_verify_appbar),
      bottomBar: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space4,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
        ),
        child: DabblerButton(
          label: l10n.email_verify_different_account,
          tone: DabblerButtonTone.text,
          size: DabblerButtonSize.full,
          fullWidth: true,
          onPressed: () => context.go(RoutePaths.authWelcome),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerText(l10n.email_verify_title, style: DabblerType.title1),
            const DabblerGap.v(DabblerSpacing.space4),
            DabblerText(
              email != null
                  ? l10n.email_verify_body_with_email(email)
                  : l10n.email_verify_body_no_email,
            ),
            const DabblerGap.v(DabblerSpacing.space8),
            DabblerText(
              l10n.email_verify_instruction,
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
            const DabblerGap.v(DabblerSpacing.space10),
            DabblerButton(
              label: l10n.email_verify_confirmed_btn,
              icon: 'tick-circle',
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: _isChecking,
              onPressed: _checkEmailConfirmed,
            ),
            const DabblerGap.v(DabblerSpacing.space4),
            DabblerButton(
              label: l10n.email_verify_resend_btn,
              icon: 'sms',
              tone: DabblerButtonTone.outlined,
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: _isResending,
              onPressed: _resendEmail,
            ),
            const DabblerGap.v(DabblerSpacing.space8),
            if (_errorMessage != null)
              DabblerBanner(
                tone: DabblerBannerTone.error,
                message: _errorMessage,
              ),
            if (_successMessage != null)
              DabblerBanner(
                tone: DabblerBannerTone.success,
                message: _successMessage,
              ),
          ],
        ),
      ),
    );
  }
}
