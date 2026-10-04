import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/birth_date_sheet.dart';
import 'package:dabbler/features/profile/services/image_upload_service.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_availability.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_avatar_sheet.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_fields.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_models.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_edit/profile_edit_sports.dart';

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
  List<ProfileEditTimeSlot> _weeklyAvailability = [];

  List<String> get _genderOptions {
    const base = ['male', 'female'];
    final current = _selectedGender;
    if (current != null && current.isNotEmpty && !base.contains(current)) {
      return [...base, current];
    }
    return base;
  }

  List<String> get _languageOptions => ['en', 'ar', 'fr', 'es', 'de'];

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'ar': 'Arabic',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
  };

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

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
          .from(SupabaseConfig.sportsTable)
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
        final storedCountry = (response['country'] as String?) ?? '';
        // If stored as ISO code, resolve to display name
        if (storedCountry.length == 2) {
          try {
            final rows = await Supabase.instance.client
                .from(SupabaseConfig.refCountriesTable)
                .select('name_en')
                .eq('code', storedCountry.toUpperCase())
                .limit(1);
            _countryController.text = rows.isNotEmpty
                ? (rows.first['name_en'] as String? ?? storedCountry)
                : storedCountry;
          } catch (_) {
            _countryController.text = storedCountry;
          }
        } else {
          _countryController.text = storedCountry;
        }
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
        _toast('Error loading profile: $e', DabblerToastTone.error);
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
          .from(SupabaseConfig.sportProfilesTable)
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
          .from(SupabaseConfig.userPreferencesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (prefsResponse != null) {
        // Load weekly availability
        final weeklyAvailJson = prefsResponse['weekly_availability'];
        if (weeklyAvailJson != null && weeklyAvailJson is List) {
          final slots = <ProfileEditTimeSlot>[];
          for (final slot in weeklyAvailJson) {
            if (slot is Map) {
              final dayOfWeek = slot['dayOfWeek'] as int?;
              final startHour = slot['startHour'] as int?;
              final endHour = slot['endHour'] as int?;
              if (dayOfWeek != null && startHour != null && endHour != null) {
                slots.add(
                  ProfileEditTimeSlot(
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
      return ProfileEditSports.formatSportKey(sportReference);
    }

    return ProfileEditSports.label(context, sport);
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
    await showDabblerSheet<void>(
      context: context,
      title: category,
      detent: DabblerSheetDetent.content,
      builder: (_) => ProfileEditCategorySportsSheet(
        sports: sports,
        isSelected: (sport) => _selectedInterests.contains(sport.id),
        isPrimary: (sport) => _primarySport == sport.id,
        isPreferred: (sport) => _preferredSport == sport.id,
        onToggle: (sport, selected) {
          setState(() {
            _toggleInterestSportSelection(sport, selected);
          });
        },
      ),
    );
  }

  List<String> _buildAvatarChoices(String userId, {int generation = 0}) {
    final profileSeed = _profileId ?? 'draft';
    return List.generate(
      12,
      (index) => buildDsAvatarReference(
        'profile:$profileSeed:user:$userId:gen:$generation:option:${index + 1}',
      ),
    );
  }

  Future<void> _showAvatarOptionsDrawer() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        _toast(
          'Please sign in to update your avatar',
          DabblerToastTone.neutral,
        );
      }
      return;
    }

    await showDabblerSheet<void>(
      context: context,
      title: 'Choose your avatar',
      detent: DabblerSheetDetent.content,
      builder: (_) => ProfileEditAvatarSheet(
        choicesFor: (generation) =>
            _buildAvatarChoices(user.id, generation: generation),
        currentReference: _avatarPath,
        displayName: _currentAvatarDisplayName,
        uploading: _isUploadingAvatar,
        onPickGenerated: _selectDsAvatar,
        onFromFile: _pickAndUploadAvatarFromFile,
        onFromGallery: () =>
            _pickAndUploadAvatarFromSource(ImageSource.gallery),
        onFromCamera: _supportsCamera
            ? () => _pickAndUploadAvatarFromSource(ImageSource.camera)
            : null,
      ),
    );
  }

  Future<void> _selectDsAvatar(String avatarReference) async {
    if (_isUploadingAvatar) return;

    final user = _authService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        _toast(
          'Please sign in to update your avatar',
          DabblerToastTone.neutral,
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

      _toast('Avatar updated successfully', DabblerToastTone.success);
    } catch (e) {
      if (mounted) {
        _toast('Error updating avatar: $e', DabblerToastTone.error);
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
        _toast('Error selecting avatar: $e', DabblerToastTone.error);
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
        _toast('Error selecting avatar: $e', DabblerToastTone.error);
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
        _toast(
          'Please sign in to update your avatar',
          DabblerToastTone.neutral,
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

      _toast('Avatar updated successfully', DabblerToastTone.success);
    } catch (e) {
      if (mounted) {
        _toast('Error updating avatar: $e', DabblerToastTone.error);
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
    // Gender is not editable from this screen: the select is disabled and
    // shows the stored value.
    return DabblerSelect<String>(
      label: 'Gender',
      placeholder: 'Gender',
      value: _selectedGender,
      enabled: false,
      options: [
        for (final gender in _genderOptions)
          DabblerSelectOption<String>(
            value: gender,
            label: gender[0].toUpperCase() + gender.substring(1),
          ),
      ],
    );
  }

  Widget _buildLanguageSelect(BuildContext context) {
    return DabblerSelect<String>(
      label: 'Language',
      placeholder: 'Select language',
      value: _selectedLanguage,
      options: [
        for (final lang in _languageOptions)
          DabblerSelectOption<String>(
            value: lang,
            label: _languageNames[lang] ?? lang,
          ),
      ],
      onChanged: (value) {
        setState(() => _selectedLanguage = value);
      },
    );
  }

  /// Preferred or primary sport: only sports in the interests, sorted by
  /// category. Disabled until at least one interest is selected.
  Widget _buildInterestSportSelect({
    required String label,
    required String placeholder,
    required String? current,
    required ValueChanged<String> onSelected,
  }) {
    final interestSports = ProfileEditSports.sortByCategory(
      _availableSports.where((s) => _selectedInterests.contains(s.id)),
    );
    // Grouped under category headers, as the original select was.
    final byCategory = ProfileEditSports.groupByCategory(interestSports);
    return DabblerSelect<String>(
      label: label,
      placeholder: placeholder,
      value: interestSports.any((s) => s.id == current) ? current : null,
      enabled: interestSports.isNotEmpty,
      helperText: interestSports.isEmpty
          ? 'Select at least one interest first.'
          : null,
      searchable: interestSports.length >= 8,
      sheetTitle: label,
      groups: [
        for (final entry in byCategory.entries)
          DabblerSelectGroup<String>(
            label: entry.key,
            options: [
              for (final sport in entry.value)
                DabblerSelectOption<String>(
                  value: sport.id,
                  label: ProfileEditSports.label(context, sport),
                ),
            ],
          ),
      ],
      onChanged: onSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    // One layout at every width (a wide-screen shell is not a DS component).
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Edit Profile',
        onBack: () => context.pop(),
      ),
      body: _isLoading
          ? const Center(child: DabblerSpinner())
          : SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                DabblerSpacing.screenGutter,
                DabblerSpacing.space4,
                DabblerSpacing.screenGutter,
                DabblerSpacing.space8,
              ),
              child: Form(key: _formKey, child: _buildForm(context)),
            ),
    );
  }

  Widget _buildForm(BuildContext context) {
    const gap = DabblerGap.v(DabblerSpacing.space5);
    const sectionGap = DabblerGap.v(DabblerSpacing.sectionGap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileEditAvatarHeader(
          avatarUrl: _avatarUrl,
          displayName: _currentAvatarDisplayName,
          uploading: _isUploadingAvatar,
          onTap: _showAvatarOptionsDrawer,
        ),
        sectionGap,
        ProfileEditTextField(
          label: 'Display Name',
          controller: _displayNameController,
          hintText: 'Choose a name',
          validator: AppValidators.validateName,
        ),
        gap,
        ProfileEditTextField(
          label: 'Username',
          controller: _usernameController,
          hintText: 'Your username',
          readOnly: true,
          helperText: 'Username cannot be changed',
        ),
        gap,
        ProfileEditTextField(
          label: 'Bio',
          controller: _bioController,
          hintText: 'Tell us about yourself',
          maxLines: 3,
        ),
        gap,
        ProfileEditDobField(
          value: _dateOfBirth,
          minimum: _dobFirstDate,
          maximum: _dobLastDate,
          onOpenPicker: () => _showDatePicker(context),
          onChanged: _setDateOfBirth,
        ),
        gap,
        ProfileEditTextField(
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
        gap,
        _buildGenderSelect(context),
        gap,
        ProfileEditTextField(
          label: 'City',
          controller: _cityController,
          hintText: 'Your city',
        ),
        gap,
        ProfileEditTextField(
          label: 'Country',
          controller: _countryController,
          hintText: 'Your country',
        ),
        gap,
        _buildLanguageSelect(context),
        sectionGap,
        ProfileEditInterestsSection(
          sportsByCategory: ProfileEditSports.groupByCategory(_availableSports),
          selectedIds: _selectedInterests,
          onOpenCategory: (category, sports) => _showCategorySportsDrawer(
            context,
            category: category,
            sports: sports,
          ),
        ),
        sectionGap,
        _buildInterestSportSelect(
          label: 'Preferred Sport',
          placeholder: 'Select preferred sport',
          current: _preferredSport,
          onSelected: (value) => setState(() => _preferredSport = value),
        ),
        gap,
        _buildInterestSportSelect(
          label: 'Primary Sport',
          placeholder: 'Select primary sport',
          current: _primarySport,
          onSelected: (value) => setState(() => _primarySport = value),
        ),
        sectionGap,
        ProfileEditSkillLevels(
          entries: _interestSkillEntries(),
          labelOf: _sportDisplayName,
          onChanged: (sport, level) {
            setState(() {
              _selectedSports[sport] = level;
            });
          },
        ),
        sectionGap,
        ProfileEditAvailabilitySection(
          slots: _weeklyAvailability,
          onAdd: () => _showAddAvailabilityDialog(context),
          onRemove: (index) {
            setState(() {
              _weeklyAvailability.removeAt(index);
            });
          },
        ),
        sectionGap,
        DabblerButton(
          label: 'Save changes',
          size: DabblerButtonSize.full,
          fullWidth: true,
          disabled: _isLoading,
          onPressed: _isLoading ? null : _saveProfile,
        ),
      ],
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
        profileId: _profileId,
        age: age,
        gender: _selectedGender,
        language: _selectedLanguage,
      );

      // Update city, country, preferred_sport, primary_sport, interests directly
      final user = _authService.getCurrentUser();
      if (user != null && _profileId != null) {
        // Resolve country name → ISO code before saving
        String? countryToSave;
        final rawCountry = _countryController.text.trim();
        if (rawCountry.isNotEmpty) {
          if (rawCountry.length == 2) {
            countryToSave = rawCountry.toUpperCase();
          } else {
            try {
              final rows = await Supabase.instance.client
                  .from(SupabaseConfig.refCountriesTable)
                  .select('code')
                  .eq('name_en', rawCountry)
                  .limit(1);
              countryToSave = rows.isNotEmpty
                  ? rows.first['code'] as String?
                  : null;
            } catch (_) {}
          }
        }

        await Supabase.instance.client
            .from(SupabaseConfig.usersTable)
            .update({
              'city': _cityController.text.trim().isEmpty
                  ? null
                  : _cityController.text.trim(),
              'country': countryToSave,
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
        _toast('Profile updated successfully!', DabblerToastTone.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        _toast('Error updating profile: $e', DabblerToastTone.error);
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
          .from(SupabaseConfig.sportProfilesTable)
          .select('sport')
          .eq('profile_id', profileId);

      final existingKeys = existing
          .map<String>((r) => r['sport'] as String)
          .toSet();

      // Delete removed sports
      final toDelete = existingKeys.difference(desiredKeys);
      if (toDelete.isNotEmpty) {
        await Supabase.instance.client
            .from(SupabaseConfig.sportProfilesTable)
            .delete()
            .eq('profile_id', profileId)
            .inFilter('sport', toDelete.toList());
      }

      // Insert only newly added sports
      final toInsert = sportsData
          .where((r) => !existingKeys.contains(r['sport']))
          .toList();
      if (toInsert.isNotEmpty) {
        await Supabase.instance.client
            .from(SupabaseConfig.sportProfilesTable)
            .insert(toInsert);
      }

      // Update skill level for sports that already existed
      for (final row in sportsData) {
        if (existingKeys.contains(row['sport'])) {
          await Supabase.instance.client
              .from(SupabaseConfig.sportProfilesTable)
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
          .from(SupabaseConfig.userPreferencesTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await Supabase.instance.client
            .from(SupabaseConfig.userPreferencesTable)
            .update({
              'weekly_availability': weeklyAvailJson,
              'preferred_game_types': preferredGameTypes,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
      } else {
        // Insert new
        await Supabase.instance.client
            .from(SupabaseConfig.userPreferencesTable)
            .insert({
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

  /// Skill levels shown: only sports in the interests.
  Map<String, SkillLevel> _interestSkillEntries() {
    final interestSportEntries = <String, SkillLevel>{};
    for (final sport in _availableSports) {
      if (!_selectedInterests.contains(sport.id)) continue;
      final key = ProfileEditSports.keyOf(sport);
      interestSportEntries[key] = _selectedSports[key] ?? SkillLevel.beginner;
    }
    return interestSportEntries;
  }

  // ============================================================================
  // AVAILABILITY SECTION
  // ============================================================================

  void _showAddAvailabilityDialog(BuildContext context) {
    showDabblerSheet<void>(
      context: context,
      title: 'Add Availability',
      detent: DabblerSheetDetent.content,
      builder: (_) => ProfileEditAddAvailabilitySheet(
        onAdd: (slot) {
          setState(() {
            _weeklyAvailability.add(slot);
            // Sort by day of week
            _weeklyAvailability.sort(
              (a, b) => a.dayOfWeek.compareTo(b.dayOfWeek),
            );
          });
        },
      ),
    );
  }

  // ============================================================================
  // DATE OF BIRTH
  // ============================================================================

  DateTime get _dobFirstDate => DateTime(DateTime.now().year - 100);

  DateTime get _dobLastDate => DateTime(DateTime.now().year - 13);

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day);
    final firstDate = _dobFirstDate;
    final lastDate = _dobLastDate;

    final picked = await showBirthDateSheet(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : (initialDate.isAfter(lastDate) ? lastDate : initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && mounted) {
      _setDateOfBirth(picked);
    }
  }

  /// Sets the date of birth and the age derived from it; null clears both.
  void _setDateOfBirth(DateTime? picked) {
    if (picked == null) {
      setState(() {
        _dateOfBirth = null;
        _ageController.clear();
      });
      return;
    }
    final now = DateTime.now();
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
