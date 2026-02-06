import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/design_system/layouts/single_section_layout.dart';
import 'package:dabbler/themes/material3_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';
import 'package:dabbler/features/profile/services/image_upload_service.dart';
import 'package:dabbler/core/utils/validators.dart';

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

  String? _avatarPath;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  String? _selectedGender;
  String? _selectedLanguage;

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

      final response = await Supabase.instance.client
          .from(SupabaseConfig.usersTable) // 'profiles' table
          .select()
          .eq('user_id', user!.id) // Match by user_id FK
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        _displayNameController.text =
            (response['display_name'] as String?) ?? '';
        _usernameController.text = (response['username'] as String?) ?? '';
        _bioController.text = (response['bio'] as String?) ?? '';
        _cityController.text = (response['city'] as String?) ?? '';
        _countryController.text = (response['country'] as String?) ?? '';
        _ageController.text = response['age'] != null
            ? response['age'].toString()
            : '';
        _interestsController.text = (response['interests'] as String?) ?? '';
        _selectedGender = (response['gender'] as String?)?.toLowerCase();
        _selectedLanguage = response['language'] as String?;
        _avatarPath = response['avatar_url'] as String?;
        _avatarUrl = _avatarPath == null
            ? null
            : Supabase.instance.client.storage
                  .from(SupabaseConfig.avatarsBucket)
                  .getPublicUrl(_avatarPath!);
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
    final colorScheme = Theme.of(context).colorScheme;
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
                      ? colorScheme.categoryProfile.withValues(alpha: 0.55)
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
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.categoryProfile.withValues(alpha: 0.15)
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
                      ? colorScheme.categoryProfile
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Iconsax.tick_circle_copy,
                color: colorScheme.categoryProfile,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
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
          style: readOnly
              ? TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))
              : null,
        ),
      ],
    );
  }

  Widget _buildLanguageSelect(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedLanguage,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Select language',
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
    final colorScheme = Theme.of(context).colorScheme;

    return SingleSectionLayout(
      category: 'profile',
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.categoryProfile,
                ),
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
                            backgroundColor: colorScheme.categoryProfile
                                .withValues(alpha: 0.0),
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
                          AppAvatar(
                            imageUrl: _avatarUrl,
                            fallbackText:
                                _displayNameController.text.trim().isNotEmpty
                                ? _displayNameController.text
                                : 'User',
                            size: 100,
                            showBadge: false,
                            fallbackBackgroundColor: colorScheme.categoryProfile
                                .withValues(alpha: 0.14),
                            fallbackForegroundColor:
                                colorScheme.onPrimaryContainer,
                            borderColor: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.18),
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
                                  color: colorScheme.categoryProfile,
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

                    // Age
                    _buildTextField(
                      context,
                      label: 'Age',
                      controller: _ageController,
                      hintText: 'Your age',
                      keyboardType: TextInputType.number,
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

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: colorScheme.categoryProfile,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor: colorScheme.categoryProfile
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
      // Parse age if provided
      int? age;
      if (_ageController.text.trim().isNotEmpty) {
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

      // Update city and country directly (not in AuthService yet)
      final user = _authService.getCurrentUser();
      if (user != null) {
        await Supabase.instance.client
            .from(SupabaseConfig.usersTable)
            .update({
              'city': _cityController.text.trim().isEmpty
                  ? null
                  : _cityController.text.trim(),
              'country': _countryController.text.trim().isEmpty
                  ? null
                  : _countryController.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', user.id);
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
}
