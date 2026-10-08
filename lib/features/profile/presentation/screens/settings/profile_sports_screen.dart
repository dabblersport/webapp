import 'package:dabbler/utils/enums/game_enums.dart'
    show kSkillBandWriteValues, skillBandIndexForValue;
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_sports_view.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/feature_flags.dart';

import '../../../../../utils/constants/route_constants.dart';

/// Screen for managing user's sports and game preferences
class ProfileSportsScreen extends ConsumerStatefulWidget {
  final String? profileType; // 'player' or 'organiser'

  const ProfileSportsScreen({super.key, this.profileType});

  @override
  ConsumerState<ProfileSportsScreen> createState() =>
      _ProfileSportsScreenState();
}

class _ProfileSportsScreenState extends ConsumerState<ProfileSportsScreen> {
  bool _isLoading = true;

  // User's sport preferences - will be loaded from database
  Map<String, SportPreference> _sportPreferences = {};

  // Sport rows whose editor is open (was ExpansionTile's own state).
  final Set<String> _expanded = {};

  // User's interests (sports they selected during onboarding)
  List<String> _userInterests = [];

  // Current profile type being managed
  String? _currentProfileType;

  @override
  void initState() {
    super.initState();
    _currentProfileType = widget.profileType;
    // Deferred one microtask so a synchronous failure can reach the DS toast
    // (an inherited lookup is not legal inside initState).
    Future.microtask(_loadSportsPreferences);
  }

  Future<void> _loadSportsPreferences() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Determine profile type to use
      String profileType = _currentProfileType ?? 'player';

      // If profile type not provided, try to detect from current profile
      if (_currentProfileType == null) {
        final currentProfile = await supabase
            .from(SupabaseConfig.usersTable)
            .select('profile_type')
            .eq('user_id', userId)
            .order('created_at', ascending: true)
            .limit(1)
            .maybeSingle();

        if (currentProfile != null) {
          profileType =
              (currentProfile['profile_type'] as String?)?.toLowerCase() ??
              'player';
        }
      }

      _currentProfileType = profileType;

      // Fetch profile_id and interests for the specific profile type
      final profileResponse = await supabase
          .from(SupabaseConfig.usersTable)
          .select('id, interests')
          .eq('user_id', userId)
          .eq('profile_type', profileType)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception('Profile not found for type: $profileType');
      }

      final profileId = profileResponse['id'] as String;

      // Parse user interests (comma-separated or JSON array)
      final interestsRaw = profileResponse['interests'];
      if (interestsRaw != null) {
        if (interestsRaw is List) {
          _userInterests = interestsRaw
              .cast<String>()
              .map((s) => s.toLowerCase().trim())
              .toList();
        } else if (interestsRaw is String && interestsRaw.isNotEmpty) {
          _userInterests = interestsRaw
              .split(',')
              .map((s) => s.toLowerCase().trim())
              .toList();
        }
      }

      // Determine which table to use based on profile type
      // Players use sport_profiles table, Organisers/Business use organiser table
      final isOrganiserType =
          profileType == 'organiser' || profileType == 'business';

      Map<String, dynamic> existingSportProfiles = {};

      if (!isOrganiserType) {
        // Load from sport_profiles table for player profiles
        final response = await supabase
            .from(SupabaseConfig.sportProfilesTable)
            .select('*')
            .eq('profile_id', profileId);

        for (final sportData in response as List) {
          final sportKey = (sportData['sport'] as String? ?? '').toLowerCase();
          if (sportKey.isNotEmpty) {
            existingSportProfiles[sportKey] = sportData;
          }
        }
      } else {
        // Load from organiser table for organiser/business profiles
        final response = await supabase
            .from(SupabaseConfig.organiserTable)
            .select('*')
            .eq('profile_id', profileId);

        for (final sportData in response as List) {
          final sportKey = (sportData['sport'] as String? ?? '').toLowerCase();
          if (sportKey.isNotEmpty) {
            existingSportProfiles[sportKey] = sportData;
          }
        }
      }

      // Build preferences ONLY from user's interests
      // Sports with existing profiles are active, others are inactive
      final Map<String, SportPreference> preferences = {};

      for (final interest in _userInterests) {
        final sportKey = interest.toLowerCase().replaceAll(' ', '_');
        final existingProfile = existingSportProfiles[sportKey];
        final hasProfile = existingProfile != null;

        if (!isOrganiserType && hasProfile) {
          // Player profile with existing sport_profile
          preferences[sportKey] = SportPreference(
            name: _formatSportName(sportKey),
            emoji: _getSportEmoji(sportKey),
            isEnabled: true,
            skillLevel: _parseSkillLevel(existingProfile['skill_level']),
            preferredPosition: existingProfile['primary_position'] as String?,
          );
        } else if (isOrganiserType && hasProfile) {
          // Organiser/business profile with existing organiser record
          final organiserLevel =
              existingProfile['organiser_level'] as int? ?? 1;
          preferences[sportKey] = SportPreference(
            name: _formatSportName(sportKey),
            emoji: _getSportEmoji(sportKey),
            isEnabled: true,
            skillLevel: _parseSkillLevelFromOrganiserLevel(organiserLevel),
            preferredPosition: null,
          );
        } else {
          // Sport is in interests but no profile exists yet
          preferences[sportKey] = SportPreference(
            name: _formatSportName(sportKey),
            emoji: _getSportEmoji(sportKey),
            isEnabled: false,
            skillLevel: SkillLevel.beginner,
            preferredPosition: null,
          );
        }
      }

      setState(() {
        _sportPreferences = preferences;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _toast(
          AppLocalizations.of(context).sports_prefs_load_failed('$e'),
          DabblerToastTone.error,
        );
      }
    }
  }

  String _formatSportName(String sportType) {
    return sportType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _getSportEmoji(String sportKey) {
    switch (sportKey) {
      case 'football':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      case 'badminton':
        return '🏸';
      case 'volleyball':
        return '🏐';
      case 'cricket':
        return '🏏';
      case 'padel':
        return '🎾';
      case 'table_tennis':
        return '🏓';
      case 'baseball':
        return '⚾';
      case 'rugby':
        return '🏉';
      case 'hockey':
        return '🏒';
      case 'golf':
        return '⛳';
      case 'swimming':
        return '🏊';
      case 'cycling':
        return '🚴';
      case 'running':
        return '🏃';
      case 'boxing':
        return '🥊';
      case 'martial_arts':
        return '🥋';
      case 'handball':
        return '🤾';
      case 'squash':
        return '🎾';
      default:
        return '🏅';
    }
  }

  SkillLevel _parseSkillLevelFromOrganiserLevel(int level) {
    // Map organiser level (1-10) to skill level, on the app's one scale.
    return SkillLevel.values[skillBandIndexForValue(level)];
  }

  SkillLevel _parseSkillLevel(dynamic level) {
    // Any stored 1-10 value reads into its band (Beginner 1-3, Intermediate
    // 4-6, Advanced 7-10). This screen used to write 1 / 2 / 3; a stored 2 or
    // 3 now reads as Beginner (see the skill-3levels note).
    if (level is int) return SkillLevel.values[skillBandIndexForValue(level)];
    return SkillLevel.beginner;
  }

  bool _shouldShowCreateGame() {
    final profileState = ref.read(profileControllerProvider);
    final profileType = profileState.profile?.profileType;

    if (profileType == 'player') {
      return FeatureFlags.enablePlayerGameCreation;
    } else if (profileType == 'organiser') {
      return FeatureFlags.enableOrganiserGameCreation;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSportsView(
      isLoading: _isLoading,
      sportPreferences: _sportPreferences,
      expanded: _expanded,
      showCreateGame: _shouldShowCreateGame(),
      positionsFor: _getPositionsForSport,
      onBack: () => context.pop(),
      onSave: _savePreferences,
      onCreateGame: () => context.push(RoutePaths.createGame),
      onToggleExpanded: (key) => setState(() {
        if (!_expanded.remove(key)) _expanded.add(key);
      }),
      onSportEnabledChanged: (sportKey, preference, value) async {
        // If enabling, create sport_profile immediately
        if (value) {
          await _enableSport(sportKey, preference);
          return;
        }

        // If disabling, show confirmation and delete profile
        final confirmed = await _showRemoveConfirmation(sportKey);
        if (confirmed && mounted) {
          await _disableSport(sportKey, preference);
        }
      },
      onSkillLevelSelected: (sportKey, preference, level) {
        setState(() {
          _sportPreferences[sportKey] = preference.copyWith(skillLevel: level);
        });
      },
      onPositionChanged: (sportKey, preference, value) {
        setState(() {
          _sportPreferences[sportKey] = preference.copyWith(
            preferredPosition: value,
          );
        });
      },
    );
  }

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  List<String> _getPositionsForSport(String sport) {
    switch (sport) {
      case 'football':
        return ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
      case 'basketball':
        return [
          'Point Guard',
          'Shooting Guard',
          'Small Forward',
          'Power Forward',
          'Center',
        ];
      case 'volleyball':
        return [
          'Setter',
          'Outside Hitter',
          'Middle Blocker',
          'Opposite Hitter',
          'Libero',
        ];
      default:
        return [];
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Determine profile type
      final profileType = _currentProfileType ?? 'player';

      // Get profile_id for the specific profile type
      final profileResponse = await supabase
          .from(SupabaseConfig.usersTable)
          .select('id')
          .eq('user_id', userId)
          .eq('profile_type', profileType)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception('Profile not found for type: $profileType');
      }

      final profileId = profileResponse['id'] as String;

      // Get enabled sports
      final enabledSports = _sportPreferences.entries
          .where((entry) => entry.value.isEnabled)
          .toList();

      // Validate: must have at least one sport
      if (enabledSports.isEmpty) {
        throw Exception('You must have at least one sport enabled');
      }

      // Determine which table to use based on profile type
      final isOrganiserType =
          profileType == 'organiser' || profileType == 'business';

      if (!isOrganiserType) {
        // Delete all existing sport_profiles for this profile (player profiles)
        await supabase
            .from(SupabaseConfig.sportProfilesTable)
            .delete()
            .eq('profile_id', profileId);

        // Insert new/updated sports profiles
        final sportsData = enabledSports.map((entry) {
          final sportKey = entry.key.toLowerCase();
          return {
            'profile_id': profileId,
            'sport': sportKey,
            'skill_level': _skillLevelToInt(entry.value.skillLevel),
            if (entry.value.preferredPosition != null &&
                entry.value.preferredPosition!.isNotEmpty)
              'primary_position': entry.value.preferredPosition,
          };
        }).toList();

        await supabase
            .from(SupabaseConfig.sportProfilesTable)
            .insert(sportsData);

        // Refresh sports profiles in the controller
        final sportsController = ref.read(
          sportsProfileControllerProvider.notifier,
        );
        await sportsController.loadSportsProfiles(userId, profileId: profileId);
      } else {
        // Delete all existing organiser records for this profile (organiser/business profiles)
        await supabase
            .from(SupabaseConfig.organiserTable)
            .delete()
            .eq('profile_id', profileId);

        // Insert new/updated organiser records
        final organiserData = enabledSports.map((entry) {
          final sportKey = entry.key.toLowerCase();
          final organiserLevel = _skillLevelToOrganiserLevel(
            entry.value.skillLevel,
          );
          return {
            'profile_id': profileId,
            'sport': sportKey,
            'organiser_level': organiserLevel,
            'commission_type': 'percent',
            'commission_value': 0.0,
            'is_verified': false,
            'is_active': true,
          };
        }).toList();

        await supabase
            .from(SupabaseConfig.organiserTable)
            .insert(organiserData);

        // Refresh organiser profiles in the controller
        final organiserController = ref.read(
          organiserProfileControllerProvider.notifier,
        );
        await organiserController.loadOrganiserProfiles(
          userId,
          profileId: profileId,
        );
      }

      // Also update the user's preferred sport in the profiles table
      final primarySport = enabledSports.isNotEmpty
          ? enabledSports.first.key.toLowerCase()
          : null;

      if (primarySport != null) {
        await supabase
            .from(SupabaseConfig.usersTable)
            .update({'preferred_sport': primarySport})
            .eq('id', profileId);
      }

      if (mounted) {
        _toast(
          AppLocalizations.of(context).sports_prefs_saved,
          DabblerToastTone.success,
        );
        // Navigate back after successful save
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        _toast(
          AppLocalizations.of(context).sports_prefs_save_failed('$e'),
          DabblerToastTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _skillLevelToInt(SkillLevel level) {
    // New saves write the band's value (2 / 5 / 7); reads accept any 1-10.
    return kSkillBandWriteValues[level.index];
  }

  int _skillLevelToOrganiserLevel(SkillLevel level) {
    // Convert skill level to organiser level (1-10 scale)
    switch (level) {
      case SkillLevel.beginner:
        return 1;
      case SkillLevel.intermediate:
        return 5;
      case SkillLevel.advanced:
        return 10;
    }
  }

  /// Enable a sport and create its profile in the database immediately
  Future<void> _enableSport(String sportKey, SportPreference preference) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final profileType = _currentProfileType ?? 'player';
      final isOrganiserType =
          profileType == 'organiser' || profileType == 'business';

      // Get profile_id
      final profileResponse = await supabase
          .from(SupabaseConfig.usersTable)
          .select('id')
          .eq('user_id', userId)
          .eq('profile_type', profileType)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception('Profile not found');
      }

      final profileId = profileResponse['id'] as String;

      if (!isOrganiserType) {
        // Create sport_profile in database for player profiles
        await supabase.from(SupabaseConfig.sportProfilesTable).upsert({
          'profile_id': profileId,
          'sport': sportKey.toLowerCase(),
          'skill_level': _skillLevelToInt(preference.skillLevel),
          if (preference.preferredPosition != null &&
              preference.preferredPosition!.isNotEmpty)
            'primary_position': preference.preferredPosition,
        }, onConflict: 'profile_id,sport');

        // Refresh sports profiles in the controller
        final sportsController = ref.read(
          sportsProfileControllerProvider.notifier,
        );
        await sportsController.loadSportsProfiles(userId, profileId: profileId);
      } else {
        // Create organiser record in database for organiser/business profiles
        final organiserLevel = _skillLevelToOrganiserLevel(
          preference.skillLevel,
        );
        await supabase.from(SupabaseConfig.organiserTable).upsert({
          'profile_id': profileId,
          'sport': sportKey.toLowerCase(),
          'organiser_level': organiserLevel,
          'commission_type': 'percent',
          'commission_value': 0.0,
          'is_verified': false,
          'is_active': true,
        }, onConflict: 'profile_id,sport');

        // Refresh organiser profiles in the controller
        final organiserController = ref.read(
          organiserProfileControllerProvider.notifier,
        );
        await organiserController.loadOrganiserProfiles(
          userId,
          profileId: profileId,
        );
      }

      // Update local state
      if (mounted) {
        setState(() {
          _sportPreferences[sportKey] = preference.copyWith(isEnabled: true);
        });

        _toast(
          '${_formatSportName(sportKey)} enabled',
          DabblerToastTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        _toast(
          AppLocalizations.of(context).sports_prefs_enable_failed('$e'),
          DabblerToastTone.error,
        );
      }
    }
  }

  /// Disable a sport and remove its profile from the database
  Future<void> _disableSport(
    String sportKey,
    SportPreference preference,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final profileType = _currentProfileType ?? 'player';
      final isOrganiserType =
          profileType == 'organiser' || profileType == 'business';

      // Get profile_id
      final profileResponse = await supabase
          .from(SupabaseConfig.usersTable)
          .select('id')
          .eq('user_id', userId)
          .eq('profile_type', profileType)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception('Profile not found');
      }

      final profileId = profileResponse['id'] as String;

      if (!isOrganiserType) {
        // Delete sport_profile from database for player profiles
        await supabase
            .from(SupabaseConfig.sportProfilesTable)
            .delete()
            .eq('profile_id', profileId)
            .eq('sport', sportKey.toLowerCase());

        // Refresh sports profiles in the controller
        final sportsController = ref.read(
          sportsProfileControllerProvider.notifier,
        );
        await sportsController.loadSportsProfiles(userId, profileId: profileId);
      } else {
        // Delete organiser record from database for organiser/business profiles
        await supabase
            .from(SupabaseConfig.organiserTable)
            .delete()
            .eq('profile_id', profileId)
            .eq('sport', sportKey.toLowerCase());

        // Refresh organiser profiles in the controller
        final organiserController = ref.read(
          organiserProfileControllerProvider.notifier,
        );
        await organiserController.loadOrganiserProfiles(
          userId,
          profileId: profileId,
        );
      }

      // Update local state
      if (mounted) {
        setState(() {
          _sportPreferences[sportKey] = preference.copyWith(isEnabled: false);
        });

        _toast(
          '${_formatSportName(sportKey)} removed',
          DabblerToastTone.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        _toast(
          AppLocalizations.of(context).sports_prefs_remove_failed('$e'),
          DabblerToastTone.error,
        );
      }
    }
  }

  bool _canRemoveSport(String sportKey) {
    // Check if this is the last enabled sport
    final enabledCount = _sportPreferences.values
        .where((p) => p.isEnabled)
        .length;
    final currentSport = _sportPreferences[sportKey];

    // Can't remove if it's the last enabled sport
    if (enabledCount <= 1 && currentSport?.isEnabled == true) {
      return false;
    }

    return true;
  }

  Future<bool> _showRemoveConfirmation(String sportKey) async {
    final sportName = _formatSportName(sportKey);
    final canRemove = _canRemoveSport(sportKey);

    if (!canRemove) {
      if (mounted) {
        _toast(
          AppLocalizations.of(context).sports_prefs_need_one,
          DabblerToastTone.error,
        );
      }
      return false;
    }

    return await showDabblerDialog<bool>(
          context: context,
          builder: (dialogContext) => DabblerDialog(
            title: AppLocalizations.of(
              context,
            ).sports_prefs_remove_title(sportName),
            description: AppLocalizations.of(
              context,
            ).sports_prefs_remove_body(sportName),
            destructive: true,
            onClose: () => Navigator.of(dialogContext).pop(false),
            secondaryAction: DabblerDialogAction(
              label: AppLocalizations.of(context).sports_prefs_cancel,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            primaryAction: DabblerDialogAction(
              label: AppLocalizations.of(context).sports_prefs_remove,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ),
        ) ??
        false;
  }
}

/// Model for sport preferences
class SportPreference {
  final String name;
  final String emoji;
  final bool isEnabled;
  final SkillLevel skillLevel;
  final String? preferredPosition;

  const SportPreference({
    required this.name,
    required this.emoji,
    required this.isEnabled,
    required this.skillLevel,
    this.preferredPosition,
  });

  SportPreference copyWith({
    String? name,
    String? emoji,
    bool? isEnabled,
    SkillLevel? skillLevel,
    String? preferredPosition,
  }) {
    return SportPreference(
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      isEnabled: isEnabled ?? this.isEnabled,
      skillLevel: skillLevel ?? this.skillLevel,
      preferredPosition: preferredPosition ?? this.preferredPosition,
    );
  }
}

/// Enum for skill levels
enum SkillLevel {
  beginner,
  intermediate,
  advanced;

  String label(AppLocalizations l) => switch (this) {
    SkillLevel.beginner => l.sports_prefs_level_beginner,
    SkillLevel.intermediate => l.sports_prefs_level_intermediate,
    SkillLevel.advanced => l.sports_prefs_level_advanced,
  };
}

/// The display label of a sport position; the stored value stays the English
/// position name, and an unknown one is shown as stored.
String sportPositionLabel(AppLocalizations l, String position) =>
    switch (position) {
      'Goalkeeper' => l.sports_pos_goalkeeper,
      'Defender' => l.sports_pos_defender,
      'Midfielder' => l.sports_pos_midfielder,
      'Forward' => l.sports_pos_forward,
      'Point Guard' => l.sports_pos_point_guard,
      'Shooting Guard' => l.sports_pos_shooting_guard,
      'Small Forward' => l.sports_pos_small_forward,
      'Power Forward' => l.sports_pos_power_forward,
      'Center' => l.sports_pos_center,
      'Setter' => l.sports_pos_setter,
      'Outside Hitter' => l.sports_pos_outside_hitter,
      'Middle Blocker' => l.sports_pos_middle_blocker,
      'Opposite Hitter' => l.sports_pos_opposite_hitter,
      'Libero' => l.sports_pos_libero,
      _ => position,
    };
