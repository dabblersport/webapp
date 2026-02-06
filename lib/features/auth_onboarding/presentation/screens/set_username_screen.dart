import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/domain/services/profile_creation_service.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart';
import 'dart:async';

/// Mode for set username screen - onboarding vs adding a new persona
enum SetUsernameMode {
  /// During initial onboarding flow
  onboarding,

  /// During add persona flow (existing user adding/converting profile)
  addPersona,
}

class SetUsernameScreen extends ConsumerStatefulWidget {
  final SetUsernameMode mode;

  const SetUsernameScreen({super.key, this.mode = SetUsernameMode.onboarding});

  @override
  ConsumerState<SetUsernameScreen> createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends ConsumerState<SetUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mode == SetUsernameMode.addPersona) {
        // ADD PERSONA: Pre-fill display name from existing primary profile
        final personaState = ref.read(personaServiceProvider);
        final primaryProfile = personaState.primaryProfile;

        if (primaryProfile != null &&
            primaryProfile.displayName != null &&
            primaryProfile.displayName!.isNotEmpty) {
          _displayNameController.text = primaryProfile.displayName!;
        }
      } else {
        // ONBOARDING: Verify authentication status for debugging
        final authService = AuthService();
        authService.getCurrentUser();
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (username.length < 3) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        bool usernameExists;

        if (widget.mode == SetUsernameMode.addPersona) {
          // ADD PERSONA: Use ProfileCreationService
          final service = ProfileCreationService(Supabase.instance.client);
          final isAvailable = await service.isUsernameAvailable(username);
          usernameExists = !isAvailable;
        } else {
          // ONBOARDING: Use AuthService
          final authService = AuthService();
          usernameExists = await authService.checkUsernameExists(username);
        }

        if (mounted) {
          setState(() {
            _usernameError = usernameExists ? 'Username already taken' : null;
            _isCheckingUsername = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _usernameError = 'Error checking username';
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_usernameError!), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final displayName = _displayNameController.text.trim();
      final username = _usernameController.text.trim();

      // Validate inputs
      if (username.isEmpty) {
        throw Exception('Username cannot be empty. Please enter a username.');
      }
      if (displayName.isEmpty) {
        throw Exception(
          'Display name cannot be empty. Please enter a display name.',
        );
      }

      if (widget.mode == SetUsernameMode.addPersona) {
        // ADD PERSONA MODE: Use ProfileCreationService
        await _handleAddPersonaSubmit(displayName, username);
      } else {
        // ONBOARDING MODE: Use AuthService
        await _handleOnboardingSubmit(displayName, username);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOnboardingSubmit(
    String displayName,
    String username,
  ) async {
    final onboardingData = ref.read(onboardingDataProvider);
    if (onboardingData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing onboarding data. Please start over.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all required fields (excluding displayName as we collect it here)
    if (onboardingData.age == null ||
        onboardingData.gender == null ||
        onboardingData.intention == null ||
        onboardingData.preferredSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing required information. Please complete all steps.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authService = AuthService();
    final currentUser = authService.getCurrentUser();

    if (currentUser == null) {
      throw Exception(
        'Your session has expired. Please verify your phone number again.',
      );
    }

    // Get selected location (country and city) from provider
    final locationState = ref.read(selectedLocationProvider);
    final country = locationState.maybeWhen(
      data: (loc) => loc.country,
      orElse: () => null,
    );
    final city = locationState.maybeWhen(
      data: (loc) => loc.city,
      orElse: () => null,
    );

    // Complete onboarding - updates profile, creates sport/organiser profile, syncs to auth.users
    await authService.completeOnboarding(
      displayName: displayName,
      username: username,
      age: onboardingData.age!,
      gender: onboardingData.gender!,
      intention: onboardingData.intention!,
      preferredSport: onboardingData.preferredSport!,
      interests: onboardingData.interestsString,
      country: country,
      city: city,
      password: null, // Phone/Google users don't set password here
    );

    // Clear onboarding data
    ref.read(onboardingDataProvider.notifier).clear();

    // Refresh auth state to load the new profile
    await ref.read(simpleAuthProvider.notifier).refreshAuthState();

    // Navigate to welcome screen with persona context
    if (mounted) {
      context.go(
        RoutePaths.welcome,
        extra: {
          'displayName': displayName,
          'personaType': onboardingData.intention ?? 'player',
          'isFirstTime': true,
        },
      );
    }
  }

  Future<void> _handleAddPersonaSubmit(
    String displayName,
    String username,
  ) async {
    final addPersonaData = ref.read(addPersonaDataProvider);
    if (addPersonaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing data. Please start over.'),
          backgroundColor: Colors.red,
        ),
      );
      context.go('/settings');
      return;
    }

    // Update provider with identity data
    ref
        .read(addPersonaDataProvider.notifier)
        .setIdentity(displayName: displayName, username: username);

    // Get updated data with identity
    final completeData = ref.read(addPersonaDataProvider)!;

    // Create the profile
    final service = ProfileCreationService(Supabase.instance.client);
    await service.createProfile(
      data: completeData,
      deactivateProfileId: completeData.existingProfileId,
    );

    // Clear add persona data
    ref.read(addPersonaDataProvider.notifier).clear();

    // Refresh persona service to update available personas
    await ref.read(personaServiceProvider.notifier).fetchUserPersonas();

    // Navigate to welcome screen with add persona context
    if (mounted) {
      context.go(
        RoutePaths.welcome,
        extra: {
          'displayName': displayName,
          'personaType': completeData.targetPersona.name,
          'isFirstTime': false,
          'isConversion': completeData.isConversion,
        },
      );
    }
  }

  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String? Function(String?) validator,
    required dynamic tokens,
    required ThemeData theme,
    Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: tokens.main.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          validator: validator,
          style: theme.textTheme.titleMedium?.copyWith(
            color: tokens.main.onSurface,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.titleMedium?.copyWith(
              color: tokens.main.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: tokens.main.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: tokens.main.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: tokens.main.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: tokens.main.error, width: 2),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    // For add persona mode, get the persona data
    final addPersonaData = widget.mode == SetUsernameMode.addPersona
        ? ref.watch(addPersonaDataProvider)
        : null;

    // Get mode-specific content
    final title = widget.mode == SetUsernameMode.addPersona
        ? (addPersonaData?.isConversion == true
              ? 'Complete Your Conversion'
              : 'Complete Your New Profile')
        : 'Identify yourself';

    final subtitle = widget.mode == SetUsernameMode.addPersona
        ? 'Choose a display name and username for your ${addPersonaData?.targetPersona.displayName ?? ''} profile'
        : 'Choose how others should call you and set a username';

    final buttonText = widget.mode == SetUsernameMode.addPersona
        ? (addPersonaData?.isConversion == true
              ? 'Complete Conversion'
              : 'Create Profile')
        : 'Complete';

    return Scaffold(
      backgroundColor: tokens.main.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: ClipRRect(
          borderRadius: AppRadius.extraExtraLarge,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.main.secondaryContainer),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: AppSpacing.xxxl),

                                // Flow indicator for add persona mode
                                if (widget.mode == SetUsernameMode.addPersona &&
                                    addPersonaData != null)
                                  _buildFlowIndicator(
                                    theme,
                                    tokens,
                                    addPersonaData,
                                  ),

                                // Title
                                Text(
                                  title,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: tokens.main.onSecondaryContainer,
                                  ),
                                ),

                                const SizedBox(height: AppSpacing.xl),

                                // Subtitle
                                Text(
                                  subtitle,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: tokens.main.onSecondaryContainer,
                                      ),
                                ),

                                const SizedBox(height: AppSpacing.xxxl),

                                // Display Name Field
                                _buildInputField(
                                  context,
                                  controller: _displayNameController,
                                  label: 'Display Name',
                                  hintText: 'Enter your display name',
                                  tokens: tokens,
                                  theme: theme,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Display name is required';
                                    }
                                    if (value.trim().length < 2) {
                                      return 'Display name must be at least 2 characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: AppSpacing.lg),

                                // Username Field
                                _buildInputField(
                                  context,
                                  controller: _usernameController,
                                  label: 'Username',
                                  hintText: 'Choose a unique username',
                                  tokens: tokens,
                                  theme: theme,
                                  onChanged: _checkUsernameAvailability,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Username is required';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Username must be at least 3 characters';
                                    }
                                    if (!RegExp(
                                      r'^[a-zA-Z0-9_]+$',
                                    ).hasMatch(value)) {
                                      return 'Username can only contain letters, numbers, and underscores';
                                    }
                                    return null;
                                  },
                                  suffixIcon: _isCheckingUsername
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : _usernameError == null &&
                                            _usernameController.text.isNotEmpty
                                      ? Icon(
                                          Iconsax.tick_circle_copy,
                                          color: tokens.main.primary,
                                        )
                                      : null,
                                ),

                                if (_usernameError != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.md,
                                    ),
                                    child: Text(
                                      _usernameError!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: tokens.main.error),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.xxxl),
                                const Spacer(),

                                // Submit Button
                                FilledButton(
                                  onPressed: _isLoading ? null : _handleSubmit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(
                                      AppButtonSize.extraLargeHeight,
                                    ),
                                    padding: AppButtonSize.extraLargePadding,
                                    shape: const StadiumBorder(),
                                    backgroundColor: tokens.main.primary,
                                    foregroundColor: tokens.main.onPrimary,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: AppSpacing.xxl,
                                          width: AppSpacing.xxl,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  tokens.main.onPrimary,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          buttonText,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: tokens.main.onPrimary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                ),

                                // Back button for add persona mode
                                if (widget.mode ==
                                    SetUsernameMode.addPersona) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  Center(
                                    child: TextButton(
                                      onPressed: () => context.pop(),
                                      child: Text(
                                        'Back',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: tokens.main.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: AppSpacing.xl),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlowIndicator(
    ThemeData theme,
    dynamic tokens,
    AddPersonaData data,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: data.isConversion
                  ? tokens.main.tertiaryContainer ??
                        tokens.main.primary.withOpacity(0.15)
                  : tokens.main.primary.withOpacity(0.15),
              borderRadius: AppRadius.small,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.isConversion
                      ? Icons.swap_horiz
                      : Icons.add_circle_outline,
                  size: 18,
                  color: tokens.main.primary,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  data.isConversion
                      ? 'Converting to ${data.targetPersona.displayName}'
                      : 'Adding ${data.targetPersona.displayName} profile',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.main.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
