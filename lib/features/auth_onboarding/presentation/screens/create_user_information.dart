import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/constants.dart';
import 'package:dabbler/core/services/user_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
      final colorScheme = Theme.of(context).colorScheme;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).create_info_error_fill_required,
          ),
          backgroundColor: colorScheme.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Additional validation checks
    if (_selectedBirthDate == null) {
      final colorScheme = Theme.of(context).colorScheme;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).create_info_error_select_birth,
          ),
          backgroundColor: colorScheme.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final ageValue = _calculateAge(_selectedBirthDate!);

    // Age must be >= 16
    if (ageValue < 16) {
      final colorScheme = Theme.of(context).colorScheme;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).create_info_error_min_age),
          backgroundColor: colorScheme.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (ageValue > AppConstants.maxAge) {
      final colorScheme = Theme.of(context).colorScheme;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).create_info_error_max_age(AppConstants.maxAge),
          ),
          backgroundColor: colorScheme.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedGender.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).create_info_error_select_gender,
          ),
          backgroundColor: colorScheme.error,
          duration: Duration(seconds: 3),
        ),
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
      onboardingNotifier.setUserInfo(age: ageValue, gender: _selectedGender);

      // Navigate to intention selection screen
      if (mounted) {
        context.push(RoutePaths.intentSelection);
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).create_info_error_occurred(e.toString()),
            ),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
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

  /// Check if all required fields are filled and valid
  bool _areAllFieldsValid() {
    return _selectedBirthDate != null && _selectedGender.isNotEmpty;
  }

  /// Show native date picker
  Future<void> _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
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
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
          children: [
            OnboardingTopBar(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OnboardingScreenHead(
                        eyebrow: 'Step 1 of 5',
                        title: AppLocalizations.of(context).create_info_title,
                        subtitle: AppLocalizations.of(
                          context,
                        ).create_info_subtitle,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBirthDateCard(context),
                            const SizedBox(height: 16),
                            _buildGenderGrid(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            OnboardingBottomBar(
              child: OnboardingCTAButton(
                label: AppLocalizations.of(context).create_info_continue,
                onPressed: (_isLoading || !_areAllFieldsValid())
                    ? null
                    : _handleSubmit,
                isLoading: _isLoading,
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDateCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final age = _selectedBirthDate != null
        ? _calculateAge(_selectedBirthDate!)
        : null;
    final ageText = age != null
        ? l10n.create_info_age_display(age)
        : l10n.create_info_birth_date_placeholder;

    return GestureDetector(
      onTap: () => _showDatePicker(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _selectedBirthDate != null
              ? colorScheme.primary.withValues(alpha: 0.07)
              : colorScheme.surfaceContainerLowest,
          border: Border.all(
            color: _selectedBirthDate != null
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: _selectedBirthDate != null ? 2 : 1.5,
          ),
          boxShadow: _selectedBirthDate != null
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.onPrimaryContainer],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Iconsax.calendar_1_copy,
                color: colorScheme.onPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.create_info_birth_date,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ageText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _selectedBirthDate != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              color: _selectedBirthDate != null
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const genders = [
      ('male', 'Male', Iconsax.man_copy),
      ('female', 'Female', Iconsax.woman_copy),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).create_info_gender,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: genders.map((g) {
            final value = g.$1;
            final label = g.$2;
            final icon = g.$3;
            final selected = _selectedGender == value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: value != 'other' ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.08)
                          : colorScheme.surfaceContainerLowest,
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: selected ? 2 : 1.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          size: 28,
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
