import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
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

class _ProfileSportsScreenState extends ConsumerState<ProfileSportsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;

  // User's sport preferences - will be loaded from database
  Map<String, SportPreference> _sportPreferences = {};

  // User's interests (sports they selected during onboarding)
  List<String> _userInterests = [];

  // Current profile type being managed
  String? _currentProfileType;

  @override
  void initState() {
    super.initState();
    _currentProfileType = widget.profileType;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
    _loadSportsPreferences();
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
            .from('profiles')
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
          .from('profiles')
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
            .from('sport_profiles')
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
            .from('organiser')
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sports preferences: $e'),
            backgroundColor: Colors.red,
          ),
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
    // Map organiser level (1-10) to skill level
    if (level <= 3) return SkillLevel.beginner;
    if (level <= 7) return SkillLevel.intermediate;
    return SkillLevel.advanced;
  }

  SkillLevel _parseSkillLevel(dynamic level) {
    if (level is int) {
      switch (level) {
        case 1:
          return SkillLevel.beginner;
        case 2:
          return SkillLevel.intermediate;
        case 3:
          return SkillLevel.advanced;
        default:
          return SkillLevel.beginner;
      }
    }
    return SkillLevel.beginner;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Preferences'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(onPressed: _savePreferences, child: const Text('Save')),
        ],
      ),
      body: _isLoading && _sportPreferences.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildSportsPreferences(),
                      const SizedBox(height: 24),
                      _buildGeneralPreferences(),
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _shouldShowCreateGame()
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RoutePaths.createGame),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create game'),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_esports,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sports & Games',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_shouldShowCreateGame())
                  FilledButton.icon(
                    onPressed: () => context.push(RoutePaths.createGame),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Create game'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your sports preferences and skill levels to get the best game recommendations.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportsPreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Sports',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable sports you want to play and set your skill level',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ..._sportPreferences.entries.map(
              (entry) => _buildSportPreferenceItem(entry.key, entry.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportPreferenceItem(
    String sportKey,
    SportPreference preference,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Text(
          preference.emoji,
          style: TextStyle(
            fontSize: 24,
            color: preference.isEnabled
                ? null
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        title: Text(
          preference.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: preference.isEnabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        subtitle: Text(
          preference.isEnabled ? preference.skillLevel.displayName : 'Disabled',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: preference.isEnabled,
          onChanged: (value) async {
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
        ),
        children: preference.isEnabled
            ? [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      _buildSkillLevelSelector(sportKey, preference),
                      if (preference.preferredPosition != null) ...[
                        const SizedBox(height: 16),
                        _buildPositionSelector(sportKey, preference),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildSkillLevelSelector(String sportKey, SportPreference preference) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skill Level',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SkillLevel.values.map((level) {
            final isSelected = preference.skillLevel == level;
            return FilterChip(
              label: Text(level.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _sportPreferences[sportKey] = preference.copyWith(
                      skillLevel: level,
                    );
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPositionSelector(String sportKey, SportPreference preference) {
    final positions = _getPositionsForSport(sportKey);
    if (positions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Position',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: preference.preferredPosition,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: positions.map((position) {
            return DropdownMenuItem(value: position, child: Text(position));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _sportPreferences[sportKey] = preference.copyWith(
                preferredPosition: value,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildGeneralPreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Preferences',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Auto-join compatible games'),
              subtitle: const Text(
                'Automatically join games that match your preferences',
              ),
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_city_outlined),
              title: const Text('Use location for recommendations'),
              subtitle: const Text('Find games near your current location'),
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Flexible timing'),
              subtitle: const Text('Show games with flexible start times'),
              trailing: Switch(value: false, onChanged: (value) {}),
            ),
          ],
        ),
      ),
    );
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
          .from('profiles')
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
            .from('sport_profiles')
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

        await supabase.from('sport_profiles').insert(sportsData);

        // Refresh sports profiles in the controller
        final sportsController = ref.read(
          sportsProfileControllerProvider.notifier,
        );
        await sportsController.loadSportsProfiles(userId, profileId: profileId);
      } else {
        // Delete all existing organiser records for this profile (organiser/business profiles)
        await supabase.from('organiser').delete().eq('profile_id', profileId);

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

        await supabase.from('organiser').insert(organiserData);

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
            .from('profiles')
            .update({'preferred_sport': primarySport})
            .eq('id', profileId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sports preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back after successful save
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
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
    switch (level) {
      case SkillLevel.beginner:
        return 1;
      case SkillLevel.intermediate:
        return 2;
      case SkillLevel.advanced:
        return 3;
    }
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
          .from('profiles')
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
        await supabase.from('sport_profiles').upsert({
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
        await supabase.from('organiser').upsert({
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_formatSportName(sportKey)} enabled'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enable sport: $e'),
            backgroundColor: Colors.red,
          ),
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
          .from('profiles')
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
            .from('sport_profiles')
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
            .from('organiser')
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_formatSportName(sportKey)} removed'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove sport: $e'),
            backgroundColor: Colors.red,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You must have at least one sport enabled'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove $sportName?'),
            content: Text(
              'Are you sure you want to remove $sportName from your profile?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Remove'),
              ),
            ],
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

  String get displayName {
    switch (this) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
    }
  }
}
