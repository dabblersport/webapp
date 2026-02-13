import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/features/profile/services/image_upload_service.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';

/// Screen for editing user profile information
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _ageController = TextEditingController();
  final _interestsController = TextEditingController();

  String? _profileId;
  String? _avatarPath;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  String? _selectedGender;
  String? _selectedLanguage;
  DateTime? _dateOfBirth;

  // Sports & Preferences state
  Map<String, SkillLevel> _selectedSports = {}; // sportKey -> skillLevel
  String? _primarySport;
  List<_TimeSlot> _weeklyAvailability = [];

  List<String> get _genderOptions {
    const base = ['male', 'female'];
    final current = _selectedGender;
    if (current != null && current.isNotEmpty && !base.contains(current)) {
      return [...base, current];
    }
    return base;
  }

  List<String> get _languageOptions => ['en', 'ar', 'fr', 'es', 'de'];

  bool _isLoading = false;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.getCurrentUser();
      if (user?.id == null) return;

      // Prefer player persona, fall back to most recently updated row
      var response = await Supabase.instance.client
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('user_id', user!.id)
          .eq('persona_type', 'player')
          .maybeSingle();

      response ??= await Supabase.instance.client
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        _profileId = response['id'] as String?;
        _displayNameController.text =
            (response['display_name'] as String?) ?? '';
        _usernameController.text = (response['username'] as String?) ?? '';
        _bioController.text = (response['bio'] as String?) ?? '';
        _cityController.text = (response['city'] as String?) ?? '';
        _countryController.text = (response['country'] as String?) ?? '';
        _ageController.text = response['age'] != null
            ? response['age'].toString()
            : '';

        // Load date of birth if stored
        final dobString = response['date_of_birth'] as String?;
        if (dobString != null) {
          try {
            _dateOfBirth = DateTime.parse(dobString);
          } catch (e) {
            debugPrint('Error parsing date of birth: $e');
          }
        }

        _interestsController.text = (response['interests'] as String?) ?? '';
        _selectedGender = (response['gender'] as String?)?.toLowerCase();
        _selectedLanguage = response['language'] as String?;
        _avatarPath = response['avatar_url'] as String?;
        _avatarUrl = _avatarPath == null
            ? null
            : Supabase.instance.client.storage
                  .from(SupabaseConfig.avatarsBucket)
                  .getPublicUrl(_avatarPath!);

        // Load primary sport
        _primarySport = response['preferred_sport'] as String?;

        // Load sports profiles
        if (_profileId != null) {
          await _loadSportsProfiles(_profileId!);
          await _loadUserPreferences(user.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSportsProfiles(String profileId) async {
    try {
      final sportsResponse = await Supabase.instance.client
          .from('sport_profiles')
          .select()
          .eq('profile_id', profileId);

      final sportsMap = <String, SkillLevel>{};
      for (final sport in sportsResponse) {
        final sportKey = sport['sport_key'] as String?;
        final skillLevelInt = sport['skill_level'] as int?;
        if (sportKey != null && skillLevelInt != null) {
          // Map 1-10 skill level to SkillLevel enum (1-3: beginner, 4-5: intermediate, 6-8: advanced, 9-10: expert)
          final skillLevel = _intToSkillLevel(skillLevelInt);
          sportsMap[sportKey] = skillLevel;
        }
      }
      if (mounted) {
        setState(() {
          _selectedSports = sportsMap;
        });
      }
    } catch (e) {
      // Sports loading failed - not critical
      debugPrint('Error loading sports profiles: $e');
    }
  }

  Future<void> _loadUserPreferences(String userId) async {
    try {
      final prefsResponse = await Supabase.instance.client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (prefsResponse != null) {
        // Load weekly availability
        final weeklyAvailJson = prefsResponse['weekly_availability'];
        if (weeklyAvailJson != null && weeklyAvailJson is List) {
          final slots = <_TimeSlot>[];
          for (final slot in weeklyAvailJson) {
            if (slot is Map) {
              final dayOfWeek = slot['dayOfWeek'] as int?;
              final startHour = slot['startHour'] as int?;
              final endHour = slot['endHour'] as int?;
              if (dayOfWeek != null && startHour != null && endHour != null) {
                slots.add(
                  _TimeSlot(
                    dayOfWeek: dayOfWeek,
                    startHour: startHour,
                    endHour: endHour,
                  ),
                );
              }
            }
          }
          if (mounted) {
            setState(() {
              _weeklyAvailability = slots;
            });
          }
        }
      }
    } catch (e) {
      // Preferences loading failed - not critical
      debugPrint('Error loading preferences: $e');
    }
  }

  SkillLevel _intToSkillLevel(int level) {
    if (level <= 3) return SkillLevel.beginner;
    if (level <= 5) return SkillLevel.intermediate;
    if (level <= 8) return SkillLevel.advanced;
    return SkillLevel.expert;
  }

  int _skillLevelToInt(SkillLevel level) {
    switch (level) {
      case SkillLevel.beginner:
        return 2;
      case SkillLevel.intermediate:
        return 5;
      case SkillLevel.advanced:
        return 7;
      case SkillLevel.expert:
        return 9;
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;

    final user = _authService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to update your avatar')),
        );
      }
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final uploadService = ImageUploadService();
      final bytes = await picked.readAsBytes();
      final uploadResult = await uploadService.uploadProfileImageBytes(
        userId: user.id,
        bytes: bytes,
        originalFileName: picked.name,
      );

      await _authService.updateUserProfile(avatarUrl: uploadResult.path);

      if (!mounted) return;
      setState(() {
        _avatarPath = uploadResult.path;
        _avatarUrl = uploadResult.url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating avatar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _ageController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Widget _buildGenderSelect(BuildContext context) {
    final colorScheme = context.getCategoryTheme('profile');
    final selected = _selectedGender ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        // Gender is not editable from this screen.
        AbsorbPointer(
          absorbing: true,
          child: Opacity(
            opacity: 0.65,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected.isNotEmpty
                      ? colorScheme.primary.withValues(alpha: 0.55)
                      : colorScheme.outlineVariant,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface,
              ),
              child: Column(
                children: _genderOptions
                    .map((gender) => _buildGenderOption(context, gender))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption(BuildContext context, String gender) {
    final colorScheme = context.getCategoryTheme('profile');
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                gender[0].toUpperCase() + gender.substring(1),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Iconsax.tick_circle_copy,
                color: colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    String? helperText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = context.getCategoryTheme('profile');
    final borderRadius = BorderRadius.circular(maxLines > 1 ? 20 : 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: readOnly
              ? theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                )
              : theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            helperText: helperText,
            helperStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
        ),
      ],
    );
  }

  Widget _buildLanguageSelect(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = context.getCategoryTheme('profile');
    final borderRadius = BorderRadius.circular(999);
    final languageNames = {
      'en': 'English',
      'ar': 'Arabic',
      'fr': 'French',
      'es': 'Spanish',
      'de': 'German',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedLanguage,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Select language',
            hintStyle: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
          items: _languageOptions.map((lang) {
            return DropdownMenuItem<String>(
              value: lang,
              child: Text(languageNames[lang] ?? lang),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedLanguage = value);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.getCategoryTheme('profile');

    return SingleSectionLayout(
      category: 'profile',
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => context.pop(),
                          icon: const Icon(Iconsax.arrow_left_copy),
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.primary.withValues(
                              alpha: 0.0,
                            ),
                            foregroundColor: colorScheme.onSurface,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit Profile',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: Stack(
                        children: [
                          DSAvatar(
                            size: AvatarSize.large,
                            imageUrl: _avatarUrl,
                            displayName:
                                _displayNameController.text.trim().isNotEmpty
                                ? _displayNameController.text
                                : 'User',
                            context: AvatarContext.profile,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _isUploadingAvatar
                                  ? null
                                  : _pickAndUploadAvatar,
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surfaceContainerLowest,
                                    width: 3,
                                  ),
                                ),
                                child: _isUploadingAvatar
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.onPrimary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.camera_alt,
                                        color: colorScheme.onPrimary,
                                        size: 16,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Display Name
                    _buildTextField(
                      context,
                      label: 'Display Name',
                      controller: _displayNameController,
                      hintText: 'Choose a name',
                      validator: AppValidators.validateName,
                    ),

                    const SizedBox(height: 16),

                    // Username (read-only)
                    _buildTextField(
                      context,
                      label: 'Username',
                      controller: _usernameController,
                      hintText: 'Your username',
                      readOnly: true,
                      helperText: 'Username cannot be changed',
                    ),

                    const SizedBox(height: 16),

                    // Bio
                    _buildTextField(
                      context,
                      label: 'Bio',
                      controller: _bioController,
                      hintText: 'Tell us about yourself',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Date of Birth
                    _buildDatePickerField(context),

                    const SizedBox(height: 16),

                    // Age (auto-calculated, read-only)
                    _buildTextField(
                      context,
                      label: 'Age',
                      controller: _ageController,
                      hintText: 'Your age',
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      helperText: _dateOfBirth != null
                          ? 'Calculated from date of birth'
                          : 'Select date of birth to auto-fill',
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final age = int.tryParse(value);
                        if (age == null || age < 13 || age > 120) {
                          return 'Enter a valid age (13-120)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    _buildGenderSelect(context),

                    const SizedBox(height: 16),

                    // City
                    _buildTextField(
                      context,
                      label: 'City',
                      controller: _cityController,
                      hintText: 'Your city',
                    ),

                    const SizedBox(height: 16),

                    // Country
                    _buildTextField(
                      context,
                      label: 'Country',
                      controller: _countryController,
                      hintText: 'Your country',
                    ),

                    const SizedBox(height: 16),

                    // Language
                    _buildLanguageSelect(context),

                    const SizedBox(height: 16),

                    // Interests
                    _buildTextField(
                      context,
                      label: 'Interests',
                      controller: _interestsController,
                      hintText: 'Your interests (comma-separated)',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 24),

                    // Sports Section
                    _buildSportsSection(context),

                    const SizedBox(height: 24),

                    // Weekly Availability Section
                    _buildAvailabilitySection(context),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor: colorScheme.primary
                              .withValues(alpha: 0.4),
                          disabledForegroundColor: colorScheme.onPrimary
                              .withValues(alpha: 0.75),
                        ),
                        child: const Text('Save changes'),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Calculate age from date of birth
      int? age;
      if (_dateOfBirth != null) {
        final now = DateTime.now();
        age = now.year - _dateOfBirth!.year;
        if (now.month < _dateOfBirth!.month ||
            (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
          age--;
        }
      } else if (_ageController.text.trim().isNotEmpty) {
        age = int.tryParse(_ageController.text.trim());
      }

      await _authService.updateUserProfile(
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        age: age,
        gender: _selectedGender,
        language: _selectedLanguage,
        interests: _interestsController.text.trim().isEmpty
            ? null
            : _interestsController.text.trim(),
      );

      // Update city, country, and preferred_sport directly (not in AuthService yet)
      final user = _authService.getCurrentUser();
      if (user != null && _profileId != null) {
        await Supabase.instance.client
            .from(SupabaseConfig.usersTable)
            .update({
              'city': _cityController.text.trim().isEmpty
                  ? null
                  : _cityController.text.trim(),
              'country': _countryController.text.trim().isEmpty
                  ? null
                  : _countryController.text.trim(),
              'preferred_sport': _primarySport,
              'date_of_birth': _dateOfBirth?.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _profileId!);

        await _saveSportsProfiles(_profileId!);
        await _saveUserPreferences(user.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSportsProfiles(String profileId) async {
    try {
      // Delete existing sports
      await Supabase.instance.client
          .from('sport_profiles')
          .delete()
          .eq('profile_id', profileId);

      // Insert new sports
      if (_selectedSports.isNotEmpty) {
        final sportsData = _selectedSports.entries.map((entry) {
          return {
            'profile_id': profileId,
            'sport_key': entry.key,
            'skill_level': _skillLevelToInt(entry.value),
          };
        }).toList();

        await Supabase.instance.client
            .from('sport_profiles')
            .insert(sportsData);
      }
    } catch (e) {
      debugPrint('Error saving sports profiles: $e');
    }
  }

  Future<void> _saveUserPreferences(String userId) async {
    try {
      // Prepare weekly availability JSON
      final weeklyAvailJson = _weeklyAvailability.map((slot) {
        return {
          'dayOfWeek': slot.dayOfWeek,
          'startHour': slot.startHour,
          'endHour': slot.endHour,
        };
      }).toList();

      // Prepare preferred game types (same as selected sports keys)
      final preferredGameTypes = _selectedSports.keys.toList();

      // Check if preferences exist
      final existing = await Supabase.instance.client
          .from('user_preferences')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await Supabase.instance.client
            .from('user_preferences')
            .update({
              'weekly_availability': weeklyAvailJson,
              'preferred_game_types': preferredGameTypes,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      } else {
        // Insert new
        await Supabase.instance.client.from('user_preferences').insert({
          'user_id': userId,
          'weekly_availability': weeklyAvailJson,
          'preferred_game_types': preferredGameTypes,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
    }
  }

  // ============================================================================
  // SPORTS SECTION
  // ============================================================================

  Widget _buildSportsSection(BuildContext context) {
    final colorScheme = context.getCategoryTheme('profile');
    final availableSports = FeatureFlags.enabledSports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Iconsax.medal_star_copy,
              color: colorScheme.categorySports,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Your Sports',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedSports.length} selected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select sports you play and set your skill level. Choose one as your primary sport.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        // Sports chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableSports.map((sport) {
            final isSelected = _selectedSports.containsKey(sport);
            final isPrimary = _primarySport == sport;
            return _buildSportChip(context, sport, isSelected, isPrimary);
          }).toList(),
        ),

        // Selected sports with skill levels
        if (_selectedSports.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Skill Levels',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ..._selectedSports.entries.map((entry) {
                  return _buildSportSkillRow(context, entry.key, entry.value);
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSportChip(
    BuildContext context,
    String sport,
    bool isSelected,
    bool isPrimary,
  ) {
    final colorScheme = context.getCategoryTheme('profile');
    final displayName = _formatSportName(sport);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayName),
          if (isPrimary) ...[
            const SizedBox(width: 4),
            Icon(Iconsax.star_1_copy, size: 14, color: colorScheme.onPrimary),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedSports[sport] = SkillLevel.beginner;
            // If first sport, set as primary
            if (_selectedSports.length == 1) {
              _primarySport = sport;
            }
          } else {
            _selectedSports.remove(sport);
            // If removed sport was primary, set another as primary
            if (_primarySport == sport) {
              _primarySport = _selectedSports.isNotEmpty
                  ? _selectedSports.keys.first
                  : null;
            }
          }
        });
      },
      selectedColor: isPrimary
          ? colorScheme.categorySports
          : colorScheme.categorySports.withValues(alpha: 0.3),
      checkmarkColor: isPrimary
          ? colorScheme.onPrimary
          : colorScheme.categorySports,
      labelStyle: TextStyle(
        color: isSelected
            ? (isPrimary ? colorScheme.onPrimary : colorScheme.categorySports)
            : colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? colorScheme.categorySports
            : colorScheme.outlineVariant,
      ),
    );
  }

  Widget _buildSportSkillRow(
    BuildContext context,
    String sport,
    SkillLevel currentLevel,
  ) {
    final colorScheme = context.getCategoryTheme('profile');
    final isPrimary = _primarySport == sport;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Primary star button
          GestureDetector(
            onTap: () {
              setState(() {
                _primarySport = sport;
              });
            },
            child: Icon(
              isPrimary ? Iconsax.star_1_copy : Iconsax.star_copy,
              size: 20,
              color: isPrimary
                  ? colorScheme.categorySports
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formatSportName(sport),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // Skill level dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: DropdownButton<SkillLevel>(
              value: currentLevel,
              underline: const SizedBox(),
              isDense: true,
              items: SkillLevel.values.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(
                    _formatSkillLevel(level),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }).toList(),
              onChanged: (newLevel) {
                if (newLevel != null) {
                  setState(() {
                    _selectedSports[sport] = newLevel;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatSportName(String sport) {
    return sport
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatSkillLevel(SkillLevel level) {
    switch (level) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
      case SkillLevel.expert:
        return 'Expert';
    }
  }

  // ============================================================================
  // AVAILABILITY SECTION
  // ============================================================================

  Widget _buildAvailabilitySection(BuildContext context) {
    final colorScheme = context.getCategoryTheme('profile');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Iconsax.calendar_1_copy,
              color: colorScheme.categoryActivities,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Weekly Availability',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddAvailabilityDialog(context),
              icon: const Icon(Iconsax.add_copy, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.categoryActivities,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Set your available times for games and activities.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        if (_weeklyAvailability.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.calendar_add_copy,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No availability set. Add times when you\'re free to play.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: _weeklyAvailability.asMap().entries.map((entry) {
                final index = entry.key;
                final slot = entry.value;
                return _buildAvailabilitySlotRow(context, slot, index);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAvailabilitySlotRow(
    BuildContext context,
    _TimeSlot slot,
    int index,
  ) {
    final colorScheme = context.getCategoryTheme('profile');
    final dayName = _getDayName(slot.dayOfWeek);
    final timeRange =
        '${_formatHour(slot.startHour)} - ${_formatHour(slot.endHour)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: index > 0
            ? Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.categoryActivities.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                dayName.substring(0, 2),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.categoryActivities,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  timeRange,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _weeklyAvailability.removeAt(index);
              });
            },
            icon: Icon(Iconsax.trash_copy, size: 20, color: colorScheme.error),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _showAddAvailabilityDialog(BuildContext context) {
    int selectedDay = 1; // Monday
    int startHour = 9;
    int endHour = 17;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.getCategoryTheme('profile').surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = context.getCategoryTheme('profile');

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Availability',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Day selector
                  Text(
                    'Day',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      final isSelected = selectedDay == day;
                      return ChoiceChip(
                        label: Text(_getDayName(day).substring(0, 3)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => selectedDay = day);
                          }
                        },
                        selectedColor: colorScheme.categoryActivities,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Time range
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outline),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<int>(
                                value: startHour,
                                underline: const SizedBox(),
                                isExpanded: true,
                                items: List.generate(24, (h) {
                                  return DropdownMenuItem(
                                    value: h,
                                    child: Text(_formatHour(h)),
                                  );
                                }),
                                onChanged: (h) {
                                  if (h != null) {
                                    setModalState(() => startHour = h);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outline),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<int>(
                                value: endHour,
                                underline: const SizedBox(),
                                isExpanded: true,
                                items: List.generate(24, (h) {
                                  return DropdownMenuItem(
                                    value: h,
                                    child: Text(_formatHour(h)),
                                  );
                                }),
                                onChanged: (h) {
                                  if (h != null) {
                                    setModalState(() => endHour = h);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (startHour >= endHour) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'End time must be after start time',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _weeklyAvailability.add(
                            _TimeSlot(
                              dayOfWeek: selectedDay,
                              startHour: startHour,
                              endHour: endHour,
                            ),
                          );
                          // Sort by day of week
                          _weeklyAvailability.sort(
                            (a, b) => a.dayOfWeek.compareTo(b.dayOfWeek),
                          );
                        });
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.categoryActivities,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('Add Availability'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getDayName(int dayOfWeek) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[(dayOfWeek - 1) % 7];
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  Widget _buildDatePickerField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = context.getCategoryTheme('profile');
    final borderRadius = BorderRadius.circular(999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showDatePicker(context),
          borderRadius: borderRadius,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: borderRadius,
              border: Border.all(
                color: _dateOfBirth != null
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: _dateOfBirth != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.calendar_copy,
                  color: _dateOfBirth != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                        : 'Select your date of birth',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _dateOfBirth != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_dateOfBirth != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _dateOfBirth = null;
                        _ageController.clear();
                      });
                    },
                    child: Icon(
                      Iconsax.close_circle_copy,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final colorScheme = context.getCategoryTheme('profile');
    final now = DateTime.now();
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day);
    final firstDate = DateTime(now.year - 100);
    final lastDate = DateTime(now.year - 13);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : (initialDate.isAfter(lastDate) ? lastDate : initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: colorScheme.surface,
              onSurface: colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = picked;
        // Calculate and update age
        final age = now.year - picked.year;
        final adjustedAge =
            (now.month < picked.month ||
                (now.month == picked.month && now.day < picked.day))
            ? age - 1
            : age;
        _ageController.text = adjustedAge.toString();
      });
    }
  }
}

// Helper class for time slots
class _TimeSlot {
  final int dayOfWeek;
  final int startHour;
  final int endHour;

  const _TimeSlot({
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
  });
}
