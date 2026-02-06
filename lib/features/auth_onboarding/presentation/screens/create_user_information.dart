import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/constants.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/core/utils/helpers.dart';

import 'package:dabbler/widgets/onboarding_progress.dart';
import 'package:dabbler/core/services/user_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/authentication/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  final _nameController = TextEditingController();
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
    _nameController.dispose();
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
        context.go(RoutePaths.phoneInput);
        return;
      }

      final identifier = email ?? phone ?? '';

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
                _nameController.text = '';
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
              _nameController.text = '';
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
            _nameController.text = '';
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
          _nameController.text = userProfile['display_name'] ?? '';
          // Note: We don't store age/gender in Supabase yet, so these will be empty
          _selectedGender = ''; // Keep empty
        });
      } else {
        // No existing profile, ensure fields are empty
        setState(() {
          _nameController.text = '';
          _selectedGender = '';
        });
      }
    } catch (e) {
      // Handle error silently - user will enter data manually
      // Ensure fields are empty even if there's an error
      setState(() {
        _nameController.text = '';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Additional validation checks
    final name = _nameController.text.trim();

    if (name.length < AppConstants.minNameLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Name must be at least ${AppConstants.minNameLength} characters long',
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your birth date'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final ageValue = _calculateAge(_selectedBirthDate!);

    // Age must be >= 16
    if (ageValue < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 16 years old to register'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (ageValue > AppConstants.maxAge) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Age must be between 16 and ${AppConstants.maxAge} years',
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: AppColors.error,
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
      onboardingNotifier.setUserInfo(
        displayName: name,
        age: ageValue,
        gender: _selectedGender,
      );

      // Navigate to intention selection screen
      if (mounted) {
        context.push(RoutePaths.intentSelection);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: AppColors.error,
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
    final name = _nameController.text.trim();

    return name.length >= AppConstants.minNameLength &&
        _selectedBirthDate != null &&
        _selectedGender.isNotEmpty;
  }

  /// Build Ant Design style birth date picker
  Widget _buildBirthDatePicker(BuildContext context) {
    final ageText = _selectedBirthDate != null
        ? '${_calculateAge(_selectedBirthDate!)} years old'
        : 'Select your birth date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Birth Date',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showDatePicker(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedBirthDate != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: _selectedBirthDate != null ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.calendar_copy,
                  color: _selectedBirthDate != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ageText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _selectedBirthDate != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Icon(
                //   Icons.calendar_today,
                //   color: Theme.of(context).colorScheme.onSurfaceVariant,
                //   size: 21,
                // ),
              ],
            ),
          ),
        ),
        if (_selectedBirthDate != null) ...[
          const SizedBox(height: 8),
          // Text(
          //   'Born on ${_formatDate(_selectedBirthDate!)}',
          //   style: Theme.of(context).textTheme.bodySmall?.copyWith(
          //     color: Theme.of(context).colorScheme.primary,
          //     fontStyle: FontStyle.italic,
          //   ),
          // ),
        ],
      ],
    );
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

  /// Build Ant Design style gender select
  Widget _buildGenderSelect(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedGender.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: _selectedGender.isNotEmpty ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            children: [
              'male',
              'female',
            ].map((gender) => _buildGenderOption(context, gender)).toList(),
          ),
        ),
      ],
    );
  }

  /// Build individual gender option
  Widget _buildGenderOption(BuildContext context, String gender) {
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppHelpers.capitalize(gender),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Iconsax.tick_circle_copy,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    return SingleSectionLayout(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Header Container: Logo, Title, and Stepper
            Column(
              children: [
                SizedBox(height: 24.0),
                // Logo
                Center(
                  child: SvgPicture.asset(
                    'assets/images/dabbler_logo.svg',
                    width: 80,
                    height: 88,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: 12.0),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/dabbler_text_logo.svg',
                    width: 110,
                    height: 21,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: 16.0),
                // Onboarding Progress
                const OnboardingProgress(currentStep: 1),
                SizedBox(height: 24.0),
                // Header
                Text(
                  'We would like to know you',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.0),
                Text(
                  'Tell us a bit about yourself',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Form Container: Inputs and CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name Input
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        hintText: 'Choose a name',
                      ),
                      validator: AppValidators.validateName,
                    ),
                    SizedBox(height: 12.0),

                    // Birth Date Picker
                    _buildBirthDatePicker(context),
                    SizedBox(height: 12.0),

                    // Gender Selection
                    _buildGenderSelect(context),
                    SizedBox(height: 24.0),

                    // Continue Button
                    FilledButton(
                      onPressed: (_isLoading || !_areAllFieldsValid())
                          ? null
                          : _handleSubmit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: Text(
                        _isLoading
                            ? 'Continuing...'
                            : _areAllFieldsValid()
                            ? 'Continue'
                            : 'Fill all fields to continue',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
