import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/design_system/design_system.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for database fields only
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // State variables for database fields only
  String? _selectedGender;
  List<String> _selectedSports = [];

  // Available options
  final List<String> _sportsOptions = [
    'Football',
    'Basketball',
    'Tennis',
    'Swimming',
    'Running',
    'Cycling',
    'Golf',
    'Volleyball',
    'Baseball',
    'Soccer',
    'Cricket',
    'Badminton',
    'Table Tennis',
    'Boxing',
    'Martial Arts',
  ];

  bool _isLoading = false;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.getCurrentUser();
      if (user?.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found. Please log in again.'),
            ),
          );
        }
        return;
      }

      // Fetch from database
      final response = await Supabase.instance.client
          .from(SupabaseConfig.usersTable) // 'profiles' table
          .select()
          .eq('user_id', user!.id) // Match by user_id FK
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        // Get display name from database (only field that exists now)
        final displayName = (response['display_name'] as String?)?.trim() ?? '';

        // Only seed if user hasn't typed anything yet
        if (_displayNameController.text.isEmpty && displayName.isNotEmpty) {
          _displayNameController.text = displayName;
        }
        if (_emailController.text.isEmpty) {
          _emailController.text = (response['email'] as String?) ?? '';
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = (response['phone'] as String?) ?? '';
        }

        // Set gender
        _selectedGender = (response['gender'] as String?)?.toLowerCase();

        // Set sports
        if (response['sports'] != null) {
          final sports = response['sports'];
          if (sports is List) {
            _selectedSports = sports.cast<String>();
          }
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

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.updateUserProfile(
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        gender: _selectedGender,
        sports: _selectedSports.isNotEmpty ? _selectedSports : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return TwoSectionLayout(
      category: 'profile', // Orange category color
      topSection: _buildTopSection(context, textTheme, colorScheme),
      bottomSection: _buildBottomSection(context, textTheme, colorScheme),
    );
  }

  Widget _buildTopSection(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          'Edit Profile',
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Update your personal information',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onPrimary.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPersonalDetailsSection(textTheme, colorScheme),
          const SizedBox(height: 24),
          _buildSportsPreferencesSection(textTheme, colorScheme),
          const SizedBox(height: 24),
          _buildContactSection(textTheme, colorScheme),
          const SizedBox(height: 32),
          _buildSaveButton(colorScheme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsSection(
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Iconsax.user_edit_copy,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Personal Details',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _displayNameController,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Display Name',
                hintText: 'Enter your display name',
                prefixIcon: Icon(
                  Iconsax.user_copy,
                  color: colorScheme.onSurfaceVariant,
                ),
              ).applyDefaults(Theme.of(context).inputDecorationTheme),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name is required and cannot be empty';
                }
                if (value.trim().length < 2) {
                  return 'Display name must be at least 2 characters';
                }
                if (value.trim().length > 50) {
                  return 'Display name must be 50 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              dropdownColor: colorScheme.surfaceContainer,
              decoration: InputDecoration(
                labelText: 'Gender',
                hintText: 'Select your gender',
                prefixIcon: Icon(
                  Iconsax.profile_2user_copy,
                  color: colorScheme.onSurfaceVariant,
                ),
              ).applyDefaults(Theme.of(context).inputDecorationTheme),
              items: [
                DropdownMenuItem(
                  value: 'male',
                  child: Text(
                    'Male',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'female',
                  child: Text(
                    'Female',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportsPreferencesSection(
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.cup_copy, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sports Preferences',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Select the sports you play',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sportsOptions.map((sport) {
                final isSelected = _selectedSports.contains(sport);
                return FilterChip(
                  label: Text(sport),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSports.add(sport);
                      } else {
                        _selectedSports.remove(sport);
                      }
                    });
                  },
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.onPrimaryContainer,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  labelStyle: textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(TextTheme textTheme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.direct_copy, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Contact Information',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              enabled: false,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Email address',
                prefixIcon: Icon(
                  Iconsax.sms_copy,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Read-only',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ).applyDefaults(Theme.of(context).inputDecorationTheme),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                prefixIcon: Icon(
                  Iconsax.call_copy,
                  color: colorScheme.onSurfaceVariant,
                ),
              ).applyDefaults(Theme.of(context).inputDecorationTheme),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return FilledButton(
      onPressed: _updateProfile,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
      ),
      child: const Text('Save Changes'),
    );
  }
}
