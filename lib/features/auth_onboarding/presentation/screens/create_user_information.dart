import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/constants.dart';
import 'package:dabbler/core/services/user_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/birth_date_sheet.dart';

class RegistrationData {
  String email;
  String? name;
  int? age;
  String? gender;
  List<String>? sports;
  String? intent;

  RegistrationData({
    required this.email,
    this.name,
    this.age,
    this.gender,
    this.sports,
    this.intent,
  });

  RegistrationData copyWith({
    String? name,
    int? age,
    String? gender,
    List<String>? sports,
    String? intent,
  }) {
    return RegistrationData(
      email: email,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      sports: sports ?? this.sports,
      intent: intent ?? this.intent,
    );
  }

  // Convert to Map for GoRouter serialization
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'sports': sports,
      'intent': intent,
    };
  }

  // Create from Map for GoRouter deserialization
  static RegistrationData fromMap(Map<String, dynamic> map) {
    return RegistrationData(
      email: map['email'] as String,
      name:
          map['name']
              as String?, // Fixed: was 'display_name', should be 'name' to match toMap()
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      sports: map['sports'] != null ? List<String>.from(map['sports']) : null,
      intent: map['intent'] as String?,
    );
  }
}

class CreateUserInformation extends ConsumerStatefulWidget {
  final String? email;
  final String? phone;
  final bool forceNew; // when true, ignore any existing authenticated session

  const CreateUserInformation({
    super.key,
    this.email,
    this.phone,
    this.forceNew = false,
  }) : assert(
         // For standard email/phone onboarding we expect one of them,
         // but for OAuth flows (Google) we may rely on the authenticated user,
         // so allow both null when forceNew is false.
         email != null || phone != null || forceNew == false,
         'Either email or phone must be provided',
       );

  @override
  ConsumerState<CreateUserInformation> createState() =>
      _CreateUserInformationState();
}

class _CreateUserInformationState extends ConsumerState<CreateUserInformation> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedBirthDate;
  String _selectedGender = '';

  bool _isLoading = false;
  bool _isLoadingData = true;

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  // Avatar assets removed from this screen; avatar selection handled elsewhere.

  @override
  void initState() {
    super.initState();
    _initializeRegistrationForm();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Initializes the form by clearing any cached data, checking auth status,
  /// and loading existing data only if the user is already authenticated.
  Future<void> _initializeRegistrationForm() async {
    if (mounted) setState(() => _isLoadingData = true);

    // 1. Clear any cached user data to ensure a fresh start for registration.
    // This prevents stale data (like a name) from appearing.
    await _userService.clearUserForNewRegistration();

    try {
      // 2. Check for a valid email OR phone from the previous screen or authenticated user.
      String? email = widget.email;
      String? phone = widget.phone;

      // If email/phone not provided but user is authenticated (e.g., Google OAuth),
      // get it from the authenticated user
      if ((email == null || email.isEmpty) &&
          (phone == null || phone.isEmpty) &&
          _authService.isAuthenticated()) {
        final currentUser = _authService.getCurrentUser();
        email = currentUser?.email;
        phone = currentUser?.phone;
      }

      if ((email == null || email.isEmpty) &&
          (phone == null || phone.isEmpty) &&
          mounted) {
        context.go(RoutePaths.authWelcome);
        return;
      }

      // Update widget.email/phone for use in the rest of the method
      // We'll use local variables email/phone instead of widget.email/phone

      // 3. Check if user is already authenticated (e.g., editing their profile).
      if (!widget.forceNew && _authService.isAuthenticated()) {
        final currentEmail = _authService.getCurrentUserEmail();
        final currentPhone = _authService.getCurrentUser()?.phone;

        // Use resolved email/phone (from widget or authenticated user)
        final resolvedEmail = email ?? currentEmail;
        final resolvedPhone = phone ?? currentPhone;

        // Check if current session matches either email or phone
        bool matchesSession = false;
        if (resolvedEmail != null && currentEmail != null) {
          final normalizedCurrent = currentEmail.trim().toLowerCase();
          final normalizedTarget = resolvedEmail.trim().toLowerCase();
          matchesSession = normalizedCurrent == normalizedTarget;
        } else if (resolvedPhone != null) {
          // For phone users during onboarding after OTP verification,
          // normalize phone numbers by removing '+' prefix for comparison
          if (currentPhone != null) {
            final normalizedCurrent = currentPhone.replaceAll('+', '');
            final normalizedTarget = resolvedPhone.replaceAll('+', '');
            matchesSession = normalizedCurrent == normalizedTarget;
          } else {
            // Phone user but currentPhone is null - likely just verified OTP
            // Trust the session for onboarding flow
            matchesSession = true;
          }
        } else {}

        if (matchesSession) {
          // Same user -> check if they have a profile
          // If no profile exists, treat as new registration (not profile edit)
          final existingProfile = await _authService.getUserProfile(
            fields: ['id'],
          );
          if (existingProfile != null) {
            // User has profile -> treat as profile edit
            await _loadExistingUserData();
          } else {
            // User authenticated but no profile -> treat as new registration
            if (mounted) {
              setState(() {
                _selectedGender = '';
                _selectedBirthDate = null;
                _isLoadingData = false;
              });
            }
          }
        } else {
          // Different authenticated account than the email/phone we want to register.
          try {
            await _authService.signOut();
          } catch (e) {}
          // Proceed as fresh registration
          if (mounted) {
            setState(() {
              _selectedGender = '';
              _selectedBirthDate = null;
              _isLoadingData = false;
            });
          }
        }
      } else {
        // 4. This is the standard new user registration path.
        if (mounted) {
          setState(() {
            _selectedGender = '';
            _selectedBirthDate = null;
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  /// Loads existing data for an authenticated user who is editing their profile.
  Future<void> _loadExistingUserData() async {
    try {
      final userProfile = await _authService.getUserProfile();

      if (userProfile != null && mounted) {
        // Populate the form for authenticated users (editing profiles)
        setState(() {
          // Note: We don't store age/gender in Supabase yet, so these will be empty
          _selectedGender = ''; // Keep empty
        });
      } else {
        // No existing profile, ensure fields are empty
        setState(() {
          _selectedGender = '';
        });
      }
    } catch (e) {
      // Handle error silently - user will enter data manually
      // Ensure fields are empty even if there's an error
      setState(() {
        _selectedGender = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    // Validate all fields before proceeding
    if (!_formKey.currentState!.validate()) {
      showOnboardingError(
        context,
        AppLocalizations.of(context).create_info_error_fill_required,
      );
      return;
    }

    // Additional validation checks
    if (_selectedBirthDate == null) {
      showOnboardingError(
        context,
        AppLocalizations.of(context).create_info_error_select_birth,
      );
      return;
    }

    final ageValue = _calculateAge(_selectedBirthDate!);

    // Age must be >= 16
    if (ageValue < 16) {
      showOnboardingError(
        context,
        AppLocalizations.of(context).create_info_error_min_age,
      );
      return;
    }

    if (ageValue > AppConstants.maxAge) {
      showOnboardingError(
        context,
        AppLocalizations.of(
          context,
        ).create_info_error_max_age(AppConstants.maxAge),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Initialize or update onboarding data provider
      final onboardingNotifier = ref.read(onboardingDataProvider.notifier);

      // Get email/phone from widget or authenticated user
      final resolvedEmail = widget.email ?? _authService.getCurrentUserEmail();
      final resolvedPhone =
          widget.phone ?? _authService.getCurrentUser()?.phone;

      // Initialize with email or phone if not already done
      if (ref.read(onboardingDataProvider) == null) {
        if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
          onboardingNotifier.initWithEmail(resolvedEmail);
        } else if (resolvedPhone != null && resolvedPhone.isNotEmpty) {
          onboardingNotifier.initWithPhone(resolvedPhone);
        }
      }

      // Store user info in provider
      // Gender is optional — store null when nothing was selected.
      onboardingNotifier.setUserInfo(
        age: ageValue,
        gender: _selectedGender.isEmpty ? null : _selectedGender,
      );

      // Navigate to intention selection screen
      if (mounted) {
        context.push(RoutePaths.intentSelection);
      }
    } catch (e) {
      if (mounted) {
        showOnboardingError(
          context,
          AppLocalizations.of(context).create_info_error_occurred(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Removed _handleSkip method - information is now required

  /// Calculate age from birth date
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Get a random avatar URL based on selected gender
  // (Removed unused _getRandomAvatarUrl helper after refactor; default avatar remains constant.)

  /// Check if all required fields are filled and valid (gender is optional)
  bool _areAllFieldsValid() {
    return _selectedBirthDate != null;
  }

  /// Opens the DS birth-date sheet (calendar with a year list).
  Future<void> _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showBirthDateSheet(
      context: context,
      initialDate:
          _selectedBirthDate ??
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime.now().subtract(
        const Duration(days: 36500),
      ), // 100 years ago
      lastDate: DateTime.now().subtract(
        const Duration(days: 4745),
      ), // 13 years ago
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const OnboardingLoading();

    final l10n = AppLocalizations.of(context);
    return OnboardingStepFrame(
      onBack: () => context.pop(),
      step: 1,
      stepLabel: 'Step 1 of 5',
      title: l10n.create_info_title,
      subtitle: l10n.create_info_subtitle,
      ctaLabel: l10n.create_info_continue,
      ctaLoading: _isLoading,
      onCta: (_isLoading || !_areAllFieldsValid()) ? null : _handleSubmit,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space8,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBirthDateField(context),
              const SizedBox(height: DabblerSpacing.space6),
              _buildGenderGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDateField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final age = _selectedBirthDate != null
        ? _calculateAge(_selectedBirthDate!)
        : null;
    return DabblerTextField(
      variant: DabblerTextFieldVariant.select,
      label: l10n.create_info_birth_date,
      placeholder: l10n.create_info_birth_date_placeholder,
      value: age != null ? l10n.create_info_age_display(age) : null,
      onPressed: () => _showDatePicker(context),
    );
  }

  Widget _buildGenderGrid(BuildContext context) {
    final colors = DabblerColors.of(context);
    const genders = [('male', 'Male', 'man'), ('female', 'Female', 'woman')];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).create_info_gender,
          style: onboardingType(
            context,
            DabblerType.footnote,
            colors.textSecondary,
            weight: DabblerType.medium,
          ),
        ),
        const SizedBox(height: DabblerSpacing.space3),
        Row(
          children: [
            for (final g in genders) ...[
              if (g != genders.first)
                const SizedBox(width: DabblerSpacing.space4),
              Expanded(
                child: OnboardingOptionCard(
                  selected: _selectedGender == g.$1,
                  semanticLabel: g.$2,
                  // Tapping the selected option clears it — gender is optional.
                  onTap: () => setState(
                    () => _selectedGender = _selectedGender == g.$1 ? '' : g.$1,
                  ),
                  child: SizedBox(
                    height: 66,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DabblerIcon(
                          g.$3,
                          size: DabblerSizing.iconLg,
                          weight: _selectedGender == g.$1
                              ? DabblerIconWeight.bold
                              : DabblerIconWeight.linear,
                          color: _selectedGender == g.$1
                              ? colors.brandPrimary
                              : colors.textSecondary,
                        ),
                        const SizedBox(height: DabblerSpacing.space2),
                        Text(
                          g.$2,
                          style: onboardingType(
                            context,
                            DabblerType.subheadline,
                            colors.textPrimary,
                            weight: DabblerType.medium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
