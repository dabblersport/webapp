import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/constants.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/core/utils/helpers.dart';
import 'package:dabbler/widgets/input_field.dart';
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
         email != null || phone != null,
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
      // 2. Check for a valid email OR phone from the previous screen.
      if ((widget.email == null || widget.email!.isEmpty) &&
          (widget.phone == null || widget.phone!.isEmpty) &&
          mounted) {
        debugPrint(
          '❌ [DEBUG] CreateUserInformation: No email or phone provided, redirecting to phone input.',
        );
        context.go(RoutePaths.phoneInput);
        return;
      }

      final identifier = widget.email ?? widget.phone ?? '';
      debugPrint(
        '📧 [DEBUG] CreateUserInformation: Initializing form for: $identifier',
      );

      // 3. Check if user is already authenticated (e.g., editing their profile).
      if (!widget.forceNew && _authService.isAuthenticated()) {
        final currentEmail = _authService.getCurrentUserEmail();
        final currentPhone = _authService.getCurrentUser()?.phone;

        debugPrint('🔍 [DEBUG] CreateUserInformation: Session check:');
        debugPrint('  widget.email: ${widget.email}');
        debugPrint('  widget.phone: ${widget.phone}');
        debugPrint('  currentEmail: $currentEmail');
        debugPrint('  currentPhone: $currentPhone');

        // Check if current session matches either email or phone
        bool matchesSession = false;
        if (widget.email != null && currentEmail != null) {
          final normalizedCurrent = currentEmail.trim().toLowerCase();
          final normalizedTarget = widget.email!.trim().toLowerCase();
          matchesSession = normalizedCurrent == normalizedTarget;
          debugPrint('  Email match check: $matchesSession');
        } else if (widget.phone != null) {
          // For phone users during onboarding after OTP verification,
          // normalize phone numbers by removing '+' prefix for comparison
          if (currentPhone != null) {
            final normalizedCurrent = currentPhone.replaceAll('+', '');
            final normalizedTarget = widget.phone!.replaceAll('+', '');
            matchesSession = normalizedCurrent == normalizedTarget;
            debugPrint(
              '  Phone match check: $matchesSession ($normalizedCurrent == $normalizedTarget)',
            );
          } else {
            // Phone user but currentPhone is null - likely just verified OTP
            // Trust the session for onboarding flow
            matchesSession = true;
            debugPrint(
              '  Phone user in onboarding - trusting session (currentPhone is null)',
            );
          }
        } else {
          debugPrint('  No match possible - missing data');
        }

        if (matchesSession) {
          // Same user -> treat as profile edit
          print(
            '✅ [DEBUG] CreateUserInformation: Authenticated user matches; loading existing data.',
          );
          await _loadExistingUserData();
        } else {
          // Different authenticated account than the email/phone we want to register.
          print(
            '⚠️ [DEBUG] CreateUserInformation: Authenticated session differs from registration. Signing out to start fresh.',
          );
          try {
            await _authService.signOut();
          } catch (e) {
            print(
              '❌ [DEBUG] CreateUserInformation: Error signing out mismatched user: $e',
            );
          }
          // Proceed as fresh registration
          print(
            '🆕 [DEBUG] CreateUserInformation: Proceeding with empty form for new registration.',
          );
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
        print(
          '🆕 [DEBUG] CreateUserInformation: New user, ensuring form is empty.',
        );
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
      print('❌ [DEBUG] CreateUserInformation: Error during initialization: $e');
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
      print('Error loading user data: $e');
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
      print('👤 [DEBUG] CreateUserInformation: Collecting user information');
      print(
        '📋 [DEBUG] CreateUserInformation: Name: $name, Age: $ageValue, Gender: $_selectedGender',
      );

      // Initialize or update onboarding data provider
      final onboardingNotifier = ref.read(onboardingDataProvider.notifier);

      // Initialize with email or phone if not already done
      if (ref.read(onboardingDataProvider) == null) {
        if (widget.email != null) {
          onboardingNotifier.initWithEmail(widget.email!);
        } else if (widget.phone != null) {
          onboardingNotifier.initWithPhone(widget.phone!);
        }
      }

      // Store user info in provider
      onboardingNotifier.setUserInfo(
        displayName: name,
        age: ageValue,
        gender: _selectedGender,
      );

      print(
        '✅ [DEBUG] CreateUserInformation: User info stored in onboarding provider',
      );

      // Navigate to intention selection screen
      if (mounted) {
        context.push(RoutePaths.intentSelection);
      }
    } catch (e) {
      print('❌ [DEBUG] CreateUserInformation: Error in _handleSubmit: $e');
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showDatePicker(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedBirthDate != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              color: _selectedBirthDate != null
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05)
                  : Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  color: _selectedBirthDate != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ageText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _selectedBirthDate != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: _selectedBirthDate != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
                // Icon(
                //   LucideIcons.calendar,
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

  /// Show date picker dialog
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedGender.isNotEmpty
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            color: _selectedGender.isNotEmpty
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppHelpers.capitalize(gender),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                LucideIcons.check,
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

    return TwoSectionLayout(
      topSection: _buildTopSection(),
      bottomSection: _buildBottomSection(),
    );
  }

  Widget _buildTopSection() {
    return Column(
      children: [
        SizedBox(height: AppSpacing.huge),
        // Logo
        SvgPicture.asset(
          'assets/images/dabbler_logo.svg',
          width: 80,
          height: 88,
        ),
        SizedBox(height: AppSpacing.md),
        SvgPicture.asset(
          'assets/images/dabbler_text_logo.svg',
          width: 110,
          height: 21,
        ),
        SizedBox(height: AppSpacing.lg),
        // Onboarding Progress
        OnboardingProgress(),
        SizedBox(height: AppSpacing.xl),
        // Header
        Text(
          'We would like to know you',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          'Tell us a bit about yourself',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textLight70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name Input
          CustomInputField(
            controller: _nameController,
            label: 'Display Name',
            hintText: 'Choose a name',
            validator: AppValidators.validateName,
          ),
          SizedBox(height: AppSpacing.md),

          // Birth Date Picker
          _buildBirthDatePicker(context),
          SizedBox(height: AppSpacing.md),

          // Gender Selection
          _buildGenderSelect(context),
          SizedBox(height: AppSpacing.xl),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isLoading || !_areAllFieldsValid())
                  ? null
                  : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _areAllFieldsValid()
                    ? AppColors.primaryPurple
                    : AppColors.buttonDisabled,
                foregroundColor: _areAllFieldsValid()
                    ? AppColors.buttonForeground
                    : AppColors.buttonDisabledForeground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.buttonBorderRadius,
                  ),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.buttonForeground,
                        ),
                      ),
                    )
                  : Text(
                      _areAllFieldsValid()
                          ? 'Continue'
                          : 'Fill all fields to continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
