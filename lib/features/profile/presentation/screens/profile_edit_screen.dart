import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/features/profile/services/image_upload_service.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/core/constants/adaptive_destinations.dart';

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

  String? _profileId;
  String? _avatarPath;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  String? _selectedGender;
  String? _selectedLanguage;
  DateTime? _dateOfBirth;

  // Sports & Preferences state
  Set<String> _selectedInterests = {}; // sport UUIDs (profiles.interests)
  Map<String, SkillLevel> _selectedSports = {}; // sportKey -> skillLevel
  String? _preferredSport; // UUID from sports.id (profiles.preferred_sport)
  String? _primarySport; // UUID from sports.id (profiles.primary_sport)
  List<Sport> _availableSports = []; // Loaded from Supabase
  Map<String, Sport> _sportsByKey = {}; // sport_key -> Sport lookup
  Map<String, Sport> _sportsById = {}; // sports.id -> Sport lookup
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

  String get _currentAvatarDisplayName {
    final displayName = _displayNameController.text.trim();
    return displayName.isNotEmpty ? displayName : 'User';
  }

  bool get _supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _isLoading = false;
  late AuthService _authService;

  Future<Map<String, dynamic>?> _fetchPreferredProfileRow(String userId) async {
    final activeRows = await Supabase.instance.client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('updated_at', ascending: false)
        .limit(1);

    if (activeRows.isNotEmpty) {
      return activeRows.first;
    }

    final playerRows = await Supabase.instance.client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('user_id', userId)
        .eq('persona_type', 'player')
        .order('updated_at', ascending: false)
        .limit(1);

    if (playerRows.isNotEmpty) {
      return playerRows.first;
    }

    final fallbackRows = await Supabase.instance.client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(1);

    if (fallbackRows.isEmpty) {
      return null;
    }

    return fallbackRows.first;
  }

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Load available sports from Supabase
      final sportsRows = await Supabase.instance.client
          .from('sports')
          .select()
          .eq('is_active', true)
          .order('name_en');
      _availableSports = sportsRows.map((r) => Sport.fromMap(r)).toList();
      _sportsByKey = {
        for (final s in _availableSports)
          if (s.sportKey != null) s.sportKey!: s,
      };
      _sportsById = {for (final s in _availableSports) s.id: s};

      final user = _authService.getCurrentUser();
      if (user?.id == null) return;

      final response = await _fetchPreferredProfileRow(user!.id);

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

        // Load interests (uuid[])
        final rawInterests = response['interests'];
        if (rawInterests is List) {
          _selectedInterests = rawInterests.cast<String>().toSet();
        }
        _selectedGender = (response['gender'] as String?)?.toLowerCase();
        _selectedLanguage = response['language'] as String?;
        _avatarPath = response['avatar_url'] as String?;
        _avatarUrl = resolveAvatarUrl(_avatarPath) ?? _avatarPath;

        // Load preferred & primary sport
        _preferredSport = response['preferred_sport'] as String?;
        _primarySport = response['primary_sport'] as String?;

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
        final sportKey = sport['sport'] as String?;
        final skillLevelInt = sport['skill_level'] as int?;
        if (sportKey != null && skillLevelInt != null) {
          final skillLevel = _intToSkillLevel(skillLevelInt);
          // sport column is a text key; use _sportsByKey to resolve
          final resolvedSport = _sportsByKey[sportKey];
          final normalizedSportKey = resolvedSport?.sportKey ?? sportKey;
          sportsMap[normalizedSportKey] = skillLevel;
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
    } catch (_) {
      // user_preferences table does not exist in this environment — non-critical
      debugPrint('[profile] user_preferences unavailable, skipping load');
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

  Sport? _resolveSport(String sportReference) {
    return _sportsByKey[sportReference] ?? _sportsById[sportReference];
  }

  String _sportDisplayName(String sportReference) {
    final sport = _resolveSport(sportReference);
    if (sport == null) {
      return _formatSportName(sportReference);
    }

    return '${sport.emoji ?? ''} ${sport.nameEn}'.trim();
  }

  List<Sport> _sortSportsByCategory(Iterable<Sport> sports) {
    final sortedSports = sports.toList();
    sortedSports.sort((a, b) {
      final categoryCompare = _sportCategoryLabel(
        a.category,
      ).compareTo(_sportCategoryLabel(b.category));
      if (categoryCompare != 0) {
        return categoryCompare;
      }

      return a.nameEn.compareTo(b.nameEn);
    });
    return sortedSports;
  }

  Map<String, List<Sport>> _groupSportsByCategory(Iterable<Sport> sports) {
    final groupedSports = <String, List<Sport>>{};

    for (final sport in _sortSportsByCategory(sports)) {
      final category = _sportCategoryLabel(sport.category);
      groupedSports.putIfAbsent(category, () => <Sport>[]).add(sport);
    }

    return groupedSports;
  }

  String _sportCategoryLabel(String? category) {
    final normalized = category?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Other Sports';
    }

    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  int _selectedSportsCountForCategory(List<Sport> sports) {
    return sports
        .where((sport) => _selectedInterests.contains(sport.id))
        .length;
  }

  void _toggleInterestSportSelection(Sport sport, bool selected) {
    if (selected) {
      _selectedInterests.add(sport.id);
      final key =
          sport.sportKey ?? sport.nameEn.toLowerCase().replaceAll(' ', '_');
      if (!_selectedSports.containsKey(key)) {
        _selectedSports[key] = SkillLevel.beginner;
      }
      if (_selectedInterests.length == 1) {
        _preferredSport ??= sport.id;
        _primarySport ??= sport.id;
      }
      return;
    }

    _selectedInterests.remove(sport.id);
    final key =
        sport.sportKey ?? sport.nameEn.toLowerCase().replaceAll(' ', '_');
    _selectedSports.remove(key);
    if (_preferredSport == sport.id) {
      _preferredSport = _selectedInterests.isNotEmpty
          ? _selectedInterests.first
          : null;
    }
    if (_primarySport == sport.id) {
      _primarySport = _selectedInterests.isNotEmpty
          ? _selectedInterests.first
          : null;
    }
  }

  Future<void> _showCategorySportsDrawer(
    BuildContext context, {
    required String category,
    required List<Sport> sports,
  }) async {
    final colorScheme = context.getCategoryTheme('main');

    await showAdaptiveSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      maxDialogWidth: 460,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final sheetTheme = Theme.of(sheetContext);

            void handleToggle(Sport sport, bool selected) {
              setState(() {
                _toggleInterestSportSelection(sport, selected);
              });
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: sheetTheme.textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedSportsCountForCategory(sports)} of ${sports.length} selected',
                                style: sheetTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select sports you want to add to your interests in this category.',
                      style: sheetTheme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (itemContext, index) {
                          final sport = sports[index];
                          final isSelected = _selectedInterests.contains(
                            sport.id,
                          );
                          final isPrimary = _primarySport == sport.id;
                          final isPreferred = _preferredSport == sport.id;
                          final displayName =
                              '${sport.emoji ?? ''} ${sport.nameEn}'.trim();

                          return Material(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.1)
                                : colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => handleToggle(sport, !isSelected),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: sheetTheme
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: colorScheme.onSurface,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          if (isPrimary || isPreferred)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                isPrimary
                                                    ? 'Primary sport'
                                                    : 'Preferred sport',
                                                style: sheetTheme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      isSelected
                                          ? Iconsax.tick_circle_copy
                                          : Iconsax.add_circle_copy,
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _buildAvatarChoices(String userId) {
    final profileSeed = _profileId ?? 'draft';
    return List.generate(
      12,
      (index) => buildDsAvatarReference(
        'profile:$profileSeed:user:$userId:option:${index + 1}',
      ),
    );
  }

  Future<void> _showAvatarOptionsDrawer() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to update your avatar')),
        );
      }
      return;
    }

    final avatarChoices = _buildAvatarChoices(user.id);

    await showAdaptiveSheet<void>(
      context: context,
      backgroundColor: context.getCategoryTheme('main').surface,
      builder: (sheetContext) {
        final colorScheme = sheetContext.getCategoryTheme('main');

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your avatar',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick one of 12 generated avatars or upload your own photo.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: avatarChoices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemBuilder: (gridContext, index) {
                  final avatarReference = avatarChoices[index];
                  final isSelected = _avatarPath == avatarReference;

                  return InkWell(
                    onTap: _isUploadingAvatar
                        ? null
                        : () async {
                            Navigator.of(sheetContext).pop();
                            await _selectDsAvatar(avatarReference);
                          },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.12)
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: DSAvatar(
                        size: AvatarSize.large,
                        customDimension: 58,
                        imageUrl: avatarReference,
                        displayName: _currentAvatarDisplayName,
                        context: AvatarContext.profile,
                        hasBorder: false,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Upload options',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildAvatarActionTile(
                sheetContext,
                icon: Iconsax.folder_open_copy,
                title: 'From file',
                subtitle: 'Choose an image file from your device',
                onTap: _isUploadingAvatar
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _pickAndUploadAvatarFromFile();
                      },
              ),
              const SizedBox(height: 12),
              _buildAvatarActionTile(
                sheetContext,
                icon: Iconsax.gallery_copy,
                title: 'From gallery',
                subtitle: 'Pick a photo from your gallery',
                onTap: _isUploadingAvatar
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _pickAndUploadAvatarFromSource(
                          ImageSource.gallery,
                        );
                      },
              ),
              if (_supportsCamera) ...[
                const SizedBox(height: 12),
                _buildAvatarActionTile(
                  sheetContext,
                  icon: Iconsax.camera_copy,
                  title: 'Take a photo',
                  subtitle: 'Open the camera and capture a new avatar',
                  onTap: _isUploadingAvatar
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await _pickAndUploadAvatarFromSource(
                            ImageSource.camera,
                          );
                        },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function()? onTap,
  }) {
    final colorScheme = context.getCategoryTheme('main');

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDsAvatar(String avatarReference) async {
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

    setState(() => _isUploadingAvatar = true);

    try {
      await _authService.updateUserProfile(
        avatarUrl: avatarReference,
        profileId: _profileId,
      );

      if (!mounted) return;
      setState(() {
        _avatarPath = avatarReference;
        _avatarUrl = avatarReference;
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

  Future<void> _pickAndUploadAvatarFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await XFile(file.path!).readAsBytes();
      }
      if (bytes == null) {
        throw Exception('Could not read the selected file');
      }

      await _uploadAvatarBytes(bytes: bytes, originalFileName: file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting avatar: $e')));
      }
    }
  }

  Future<void> _pickAndUploadAvatarFromSource(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      await _uploadAvatarBytes(bytes: bytes, originalFileName: picked.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting avatar: $e')));
      }
    }
  }

  Future<void> _uploadAvatarBytes({
    required Uint8List bytes,
    required String originalFileName,
  }) async {
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
      setState(() => _isUploadingAvatar = true);

      final uploadService = ImageUploadService();
      final uploadResult = await uploadService.uploadProfileImageBytes(
        userId: user.id,
        bytes: bytes,
        originalFileName: originalFileName,
      );

      await _authService.updateUserProfile(
        avatarUrl: uploadResult.path,
        profileId: _profileId,
      );

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
    super.dispose();
  }

  Widget _buildGenderSelect(BuildContext context) {
    final colorScheme = context.getCategoryTheme('main');
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
    final colorScheme = context.getCategoryTheme('main');
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
    final colorScheme = context.getCategoryTheme('main');
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
            color: context.getCategoryTheme('main').onSurface,
          ),
        ),
        const SizedBox(height: 6),
        _buildAdaptiveSelectField<String>(
          context,
          title: 'Language',
          hintText: 'Select language',
          value: _selectedLanguage,
          options: _languageOptions
              .map(
                (lang) => _AdaptiveSelectOption<String>(
                  value: lang,
                  label: languageNames[lang] ?? lang,
                ),
              )
              .toList(),
          onSelected: (value) {
            setState(() => _selectedLanguage = value);
          },
        ),
      ],
    );
  }

  // ============================================================================
  // INTERESTS SECTION (sport UUID chips)
  // ============================================================================

  Widget _buildInterestsSection(BuildContext context) {
    final colorScheme = context.getCategoryTheme('main');
    final sportsByCategory = _groupSportsByCategory(_availableSports);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.heart_copy, color: colorScheme.categoryMain, size: 20),
            const SizedBox(width: 8),
            Text(
              'Interests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedInterests.length} selected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select sports you\'re interested in. Adding a sport here also creates a sport profile for it.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sportsByCategory.entries.map((entry) {
            final category = entry.key;
            final sports = entry.value;
            final selectedCount = _selectedSportsCountForCategory(sports);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showCategorySportsDrawer(
                    context,
                    category: category,
                    sports: sports,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedCount > 0
                            ? colorScheme.primary.withValues(alpha: 0.45)
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$selectedCount of ${sports.length} selected',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: selectedCount > 0
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: selectedCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Iconsax.arrow_right_3_copy,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
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

  Widget _buildPreferredSportDropdown(BuildContext context) {
    final theme = Theme.of(context);

    // Only show sports that are in interests
    final interestSports = _sortSportsByCategory(
      _availableSports.where((s) => _selectedInterests.contains(s.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Sport',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.getCategoryTheme('main').onSurface,
          ),
        ),
        const SizedBox(height: 6),
        _buildAdaptiveSelectField<String>(
          context,
          title: 'Preferred Sport',
          hintText: 'Select preferred sport',
          value: interestSports.any((s) => s.id == _preferredSport)
              ? _preferredSport
              : null,
          enabled: interestSports.isNotEmpty,
          emptyMessage: 'Select at least one interest first.',
          options: interestSports
              .map(
                (sport) => _AdaptiveSelectOption<String>(
                  value: sport.id,
                  label: '${sport.emoji ?? ''} ${sport.nameEn}'.trim(),
                  group: _sportCategoryLabel(sport.category),
                ),
              )
              .toList(),
          onSelected: (value) {
            setState(() => _preferredSport = value);
          },
        ),
      ],
    );
  }

  Widget _buildPrimarySportDropdown(BuildContext context) {
    final theme = Theme.of(context);

    // Only show sports that are in interests
    final interestSports = _sortSportsByCategory(
      _availableSports.where((s) => _selectedInterests.contains(s.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Primary Sport',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.getCategoryTheme('main').onSurface,
          ),
        ),
        const SizedBox(height: 6),
        _buildAdaptiveSelectField<String>(
          context,
          title: 'Primary Sport',
          hintText: 'Select primary sport',
          value: interestSports.any((s) => s.id == _primarySport)
              ? _primarySport
              : null,
          enabled: interestSports.isNotEmpty,
          emptyMessage: 'Select at least one interest first.',
          options: interestSports
              .map(
                (sport) => _AdaptiveSelectOption<String>(
                  value: sport.id,
                  label: '${sport.emoji ?? ''} ${sport.nameEn}'.trim(),
                  group: _sportCategoryLabel(sport.category),
                ),
              )
              .toList(),
          onSelected: (value) {
            setState(() => _primarySport = value);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.getCategoryTheme('main');

    final logoWidget = SvgPicture.asset(
      'assets/images/dabbler_text_logo.svg',
      width: 100,
      height: 18,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
    );

    final content = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _isLoading
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
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
                              displayName: _currentAvatarDisplayName,
                              context: AvatarContext.profile,
                              onTap: _isUploadingAvatar
                                  ? null
                                  : _showAvatarOptionsDrawer,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _isUploadingAvatar
                                    ? null
                                    : _showAvatarOptionsDrawer,
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

                      // Interests (sport chips)
                      _buildInterestsSection(context),

                      const SizedBox(height: 24),

                      // Preferred & Primary Sport dropdowns
                      _buildPreferredSportDropdown(context),
                      const SizedBox(height: 16),
                      _buildPrimarySportDropdown(context),

                      const SizedBox(height: 24),

                      // Sports Section (skill levels)
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
      ),
    );

    final width = MediaQuery.of(context).size.width;
    if (width >= AdaptiveBreakpoints.compact) {
      return AdaptiveScaffold(
        currentIndex: 6,
        destinations: kAdaptiveDestinations,
        onDestinationSelected: (i) =>
            onAdaptiveDestinationSelected(context, i, activeIndex: 6),
        headerWidget: logoWidget,
        body: content,
      );
    }
    return content;
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
        profileId: _profileId,
        age: age,
        gender: _selectedGender,
        language: _selectedLanguage,
      );

      // Update city, country, preferred_sport, primary_sport, interests directly
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
              'preferred_sport': _preferredSport,
              'primary_sport': _primarySport,
              'interests': _selectedInterests.toList(),
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
      // Build desired sport key -> skill level map
      // The trigger trgfn_set_sport_profile_sport_id expects `sport` to be a
      // text key (e.g. "football") and auto-resolves sport_id from the sports table.
      final desiredKeys = <String>{};
      final sportsData = <Map<String, dynamic>>[];
      for (final sportId in _selectedInterests) {
        final sport = _sportsById[sportId];
        if (sport == null) continue;
        final key =
            sport.sportKey ?? sport.nameEn.toLowerCase().replaceAll(' ', '_');
        final skillLevel = _selectedSports[key] ?? SkillLevel.beginner;
        desiredKeys.add(key);
        sportsData.add({
          'profile_id': profileId,
          'sport': key,
          'skill_level': _skillLevelToInt(skillLevel),
        });
      }

      // Fetch existing rows — sport column stores the text key
      final existing = await Supabase.instance.client
          .from('sport_profiles')
          .select('sport')
          .eq('profile_id', profileId);

      final existingKeys = existing
          .map<String>((r) => r['sport'] as String)
          .toSet();

      // Delete removed sports
      final toDelete = existingKeys.difference(desiredKeys);
      if (toDelete.isNotEmpty) {
        await Supabase.instance.client
            .from('sport_profiles')
            .delete()
            .eq('profile_id', profileId)
            .inFilter('sport', toDelete.toList());
      }

      // Insert only newly added sports
      final toInsert = sportsData
          .where((r) => !existingKeys.contains(r['sport']))
          .toList();
      if (toInsert.isNotEmpty) {
        await Supabase.instance.client.from('sport_profiles').insert(toInsert);
      }

      // Update skill level for sports that already existed
      for (final row in sportsData) {
        if (existingKeys.contains(row['sport'])) {
          await Supabase.instance.client
              .from('sport_profiles')
              .update({'skill_level': row['skill_level']})
              .eq('sport', row['sport'] as String)
              .eq('profile_id', profileId);
        }
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
    } catch (_) {
      // user_preferences table does not exist in this environment — non-critical
      debugPrint('[profile] user_preferences unavailable, skipping save');
    }
  }

  // ============================================================================
  // SPORTS SECTION
  // ============================================================================

  Widget _buildSportsSection(BuildContext context) {
    final colorScheme = context.getCategoryTheme('main');

    // Only show skill levels for sports in interests
    final interestSportEntries = <String, SkillLevel>{};
    for (final sport in _availableSports) {
      if (!_selectedInterests.contains(sport.id)) continue;
      final key =
          sport.sportKey ?? sport.nameEn.toLowerCase().replaceAll(' ', '_');
      interestSportEntries[key] = _selectedSports[key] ?? SkillLevel.beginner;
    }

    if (interestSportEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Iconsax.medal_star_copy,
              color: colorScheme.categoryMain,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Skill Levels',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Set your skill level for each sport in your interests.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
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
              ...interestSportEntries.entries.map((entry) {
                return _buildSportSkillRow(context, entry.key, entry.value);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSportSkillRow(
    BuildContext context,
    String sport,
    SkillLevel currentLevel,
  ) {
    final colorScheme = context.getCategoryTheme('main');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _sportDisplayName(sport),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          _buildCompactAdaptiveSelect<SkillLevel>(
            context,
            title: '${_sportDisplayName(sport)} skill level',
            value: currentLevel,
            options: SkillLevel.values
                .map(
                  (level) => _AdaptiveSelectOption<SkillLevel>(
                    value: level,
                    label: _formatSkillLevel(level),
                  ),
                )
                .toList(),
            onSelected: (newLevel) {
              setState(() {
                _selectedSports[sport] = newLevel;
              });
            },
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
    final colorScheme = context.getCategoryTheme('main');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Iconsax.calendar_1_copy,
              color: colorScheme.categoryMain,
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
                foregroundColor: colorScheme.categoryMain,
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
    final colorScheme = context.getCategoryTheme('main');
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
              color: colorScheme.categoryMain.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                dayName.substring(0, 2),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.categoryMain,
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

    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.getCategoryTheme('main').surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = context.getCategoryTheme('main');

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
                        selectedColor: colorScheme.categoryMain,
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
                            SizedBox(
                              width: double.infinity,
                              child: _buildCompactAdaptiveSelect<int>(
                                context,
                                title: 'Start Time',
                                value: startHour,
                                options: List.generate(
                                  24,
                                  (h) => _AdaptiveSelectOption<int>(
                                    value: h,
                                    label: _formatHour(h),
                                  ),
                                ),
                                onSelected: (hour) {
                                  setModalState(() => startHour = hour);
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
                            SizedBox(
                              width: double.infinity,
                              child: _buildCompactAdaptiveSelect<int>(
                                context,
                                title: 'End Time',
                                value: endHour,
                                options: List.generate(
                                  24,
                                  (h) => _AdaptiveSelectOption<int>(
                                    value: h,
                                    label: _formatHour(h),
                                  ),
                                ),
                                onSelected: (hour) {
                                  setModalState(() => endHour = hour);
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
                        backgroundColor: colorScheme.categoryMain,
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

  Future<T?> _showAdaptivePicker<T>(
    BuildContext context, {
    required String title,
    required List<_AdaptiveSelectOption<T>> options,
    T? currentValue,
    String? emptyMessage,
  }) {
    final colorScheme = context.getCategoryTheme('main');
    final groupedOptions = <String, List<_AdaptiveSelectOption<T>>>{};
    var hasGroups = false;

    for (final option in options) {
      final group = option.group?.trim();
      if (group != null && group.isNotEmpty) {
        hasGroups = true;
        groupedOptions
            .putIfAbsent(group, () => <_AdaptiveSelectOption<T>>[])
            .add(option);
      }
    }

    final initialExpandedGroups = <String>{
      if (currentValue != null)
        for (final entry in groupedOptions.entries)
          if (entry.value.any((option) => option.value == currentValue))
            entry.key,
    };

    return showAdaptiveSheet<T>(
      context: context,
      backgroundColor: colorScheme.surface,
      maxDialogWidth: 420,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        Widget buildOptionTile(_AdaptiveSelectOption<T> option) {
          final isSelected = option.value == currentValue;

          return Material(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.of(sheetContext).pop(option.value);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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
            ),
          );
        }

        final expandedGroups = <String>{...initialExpandedGroups};

        Widget buildGroupedOptions() {
          return StatefulBuilder(
            builder: (groupContext, setGroupState) {
              return ListView.separated(
                shrinkWrap: true,
                itemCount: groupedOptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (groupContext, index) {
                  final groupEntry = groupedOptions.entries.elementAt(index);
                  final groupName = groupEntry.key;
                  final groupItems = groupEntry.value;
                  final isExpanded = expandedGroups.contains(groupName);
                  final selectedInGroup = groupItems.any(
                    (option) => option.value == currentValue,
                  );

                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedInGroup
                            ? colorScheme.primary.withValues(alpha: 0.5)
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setGroupState(() {
                              if (isExpanded) {
                                expandedGroups.remove(groupName);
                              } else {
                                expandedGroups.add(groupName);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    groupName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                if (selectedInGroup)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Iconsax.tick_circle_copy,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                                  ),
                                Icon(
                                  isExpanded
                                      ? Iconsax.arrow_up_2_copy
                                      : Iconsax.arrow_down_1_copy,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: groupItems.map((option) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: buildOptionTile(option),
                                );
                              }).toList(),
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

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Text(
                      emptyMessage ?? 'No options available yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: hasGroups
                        ? buildGroupedOptions()
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              return buildOptionTile(options[index]);
                            },
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  _AdaptiveSelectOption<T>? _findSelectedOption<T>(
    List<_AdaptiveSelectOption<T>> options,
    T? value,
  ) {
    if (value == null) {
      return null;
    }

    for (final option in options) {
      if (option.value == value) {
        return option;
      }
    }

    return null;
  }

  Widget _buildAdaptiveSelectField<T>(
    BuildContext context, {
    required String title,
    required String hintText,
    required List<_AdaptiveSelectOption<T>> options,
    required T? value,
    required ValueChanged<T> onSelected,
    bool enabled = true,
    String? emptyMessage,
  }) {
    final theme = Theme.of(context);
    final colorScheme = context.getCategoryTheme('main');
    final borderRadius = BorderRadius.circular(999);
    final selectedOption = _findSelectedOption(options, value);

    Future<void> handleTap() async {
      if (!enabled) {
        return;
      }

      final selectedValue = await _showAdaptivePicker<T>(
        context,
        title: title,
        options: options,
        currentValue: value,
        emptyMessage: emptyMessage,
      );

      if (selectedValue != null) {
        onSelected(selectedValue);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? handleTap : null,
        borderRadius: borderRadius,
        child: InputDecorator(
          isEmpty: selectedOption == null,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: enabled
                ? colorScheme.surface
                : colorScheme.surfaceContainerLow,
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
            disabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedOption?.label ?? hintText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: selectedOption != null
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Iconsax.arrow_down_1_copy,
                size: 18,
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAdaptiveSelect<T>(
    BuildContext context, {
    required String title,
    required T value,
    required List<_AdaptiveSelectOption<T>> options,
    required ValueChanged<T> onSelected,
  }) {
    final colorScheme = context.getCategoryTheme('main');
    final selectedOption = _findSelectedOption(options, value);

    Future<void> handleTap() async {
      final selectedValue = await _showAdaptivePicker<T>(
        context,
        title: title,
        options: options,
        currentValue: value,
      );

      if (selectedValue != null) {
        onSelected(selectedValue);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: handleTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedOption?.label ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Iconsax.arrow_down_1_copy,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = context.getCategoryTheme('main');
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
    final colorScheme = context.getCategoryTheme('main');
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

class _AdaptiveSelectOption<T> {
  const _AdaptiveSelectOption({
    required this.value,
    required this.label,
    this.group,
  });

  final T value;
  final String label;
  final String? group;
}
