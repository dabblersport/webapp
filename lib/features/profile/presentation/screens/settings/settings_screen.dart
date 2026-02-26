import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _appVersion = '1.6.1';

  final List<SettingsSection> _allSections = [
    SettingsSection(
      title: 'Account',
      items: [
        SettingsItem(
          title: 'Account Management',
          subtitle: 'Email, password, security',
          icon: Iconsax.profile_circle_copy,
          route: '/settings/account',
          searchTerms: ['account', 'email', 'password', 'security', 'login'],
        ),
        SettingsItem(
          title: 'Privacy Settings',
          subtitle: 'Manage privacy settings and blocked users',
          icon: Iconsax.slash_copy,
          route: '/settings/privacy',
          searchTerms: ['blocked', 'block', 'users', 'privacy', 'safety'],
        ),
      ],
    ),
    // Release 2: Preferences section
    // SettingsSection(
    //   title: 'Preferences',
    //   items: [
    //     SettingsItem(
    //       title: 'Game Preferences',
    //       subtitle: 'Game types, duration, competition',
    //       icon: Iconsax.game_copy,
    //       route: '/preferences/games',
    //       searchTerms: ['games', 'types', 'duration', 'competition', 'team'],
    //     ),
    //     SettingsItem(
    //       title: 'Availability',
    //       subtitle: 'Schedule and time preferences',
    //       icon: Iconsax.calendar_copy,
    //       route: '/preferences/availability',
    //       searchTerms: ['availability', 'schedule', 'time', 'calendar'],
    //     ),
    //   ],
    // ),
    SettingsSection(
      title: 'Display',
      items: [
        SettingsItem(
          title: 'Theme',
          subtitle: 'Light, dark, or system default',
          icon: Iconsax.colorfilter_copy,
          route: '/settings/theme',
          searchTerms: ['theme', 'dark', 'light', 'appearance'],
        ),
        SettingsItem(
          title: 'Design System Showcase',
          subtitle: 'View all design components',
          icon: Iconsax.element_3_copy,
          route: '/showcase',
          searchTerms: ['design', 'system', 'showcase', 'components', 'theme'],
        ),
        // Release 2: Language
        // SettingsItem(
        //   title: 'Language',
        //   subtitle: 'Choose your preferred language',
        //   icon: Iconsax.global_copy,
        //   route: '/settings/language',
        //   searchTerms: ['language', 'locale', 'translate'],
        // ),
      ],
    ),
    // Release 2: Help & Support section
    // SettingsSection(
    //   title: 'Help & Support',
    //   items: [
    //     SettingsItem(
    //       title: 'Help Center',
    //       subtitle: 'FAQs and tutorials',
    //       icon: Iconsax.info_circle_copy,
    //       route: '/help/center',
    //       searchTerms: ['help', 'faq', 'support', 'tutorials'],
    //     ),
    //     SettingsItem(
    //       title: 'Contact Support',
    //       subtitle: 'Get help from our team',
    //       icon: Iconsax.message_question_copy,
    //       route: '/help/contact',
    //       searchTerms: ['contact', 'support', 'help', 'team'],
    //     ),
    //     SettingsItem(
    //       title: 'Report a Bug',
    //       subtitle: 'Help us improve the app',
    //       icon: Iconsax.danger_copy,
    //       route: '/help/bug-report',
    //       searchTerms: ['bug', 'report', 'issue', 'problem'],
    //     ),
    //   ],
    // ),
    SettingsSection(
      title: 'About',
      items: [
        SettingsItem(
          title: 'Terms of Service',
          subtitle: 'Read our terms and conditions',
          icon: Iconsax.document_text_copy,
          route: '/about/terms',
          searchTerms: ['terms', 'service', 'conditions', 'legal'],
        ),
        SettingsItem(
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
          icon: Iconsax.security_card_copy,
          route: '/about/privacy',
          searchTerms: ['privacy', 'policy', 'data', 'legal'],
        ),
        SettingsItem(
          title: 'Licenses',
          subtitle: 'Open source licenses',
          icon: Iconsax.code_circle_copy,
          route: '/about/licenses',
          searchTerms: ['licenses', 'open', 'source', 'legal'],
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Fetch user's active personas for dynamic "Add Profile" section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(personaServiceProvider.notifier).fetchUserPersonas();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleSectionLayout(
      category: 'profile',
      scrollable: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildHeroCard(context),
                _buildSearchBar(context),
                _buildProfileSection(context),
                ..._buildFilteredSectionsList(context),
                _buildSignOutSection(context),
                _buildVersionInfo(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_copy),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.categoryProfile.withValues(alpha: 0.0),
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: () => context.push('/help/center'),
          icon: const Icon(Iconsax.info_circle_copy),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.categoryProfile.withValues(alpha: 0.0),
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
          tooltip: 'Help center',
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final profileAccent = colorScheme.categoryProfile;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: profileAccent.withValues(alpha: isDarkMode ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize your experience',
            style: textTheme.labelLarge?.copyWith(
              color: profileAccent.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tune Dabbler to match how you play',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Manage your account, preferences, and notifications all in one place.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search settings',
          prefixIcon: const Icon(Iconsax.search_normal_copy),
          prefixIconColor: colorScheme.categoryProfile,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Iconsax.close_circle_copy),
                )
              : null,
          filled: true,
          fillColor: colorScheme.categoryProfile.withValues(
            alpha: isDarkMode ? 0.14 : 0.10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: colorScheme.categoryProfile,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFilteredSectionsList(BuildContext context) {
    final filteredSections = _getFilteredSections();

    return filteredSections.map((section) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildSection(context, section),
      );
    }).toList();
  }

  List<SettingsSection> _getFilteredSections() {
    if (_searchQuery.isEmpty) return _allSections;

    return _allSections
        .map((section) {
          final filteredItems = section.items.where((item) {
            return item.title.toLowerCase().contains(_searchQuery) ||
                item.subtitle.toLowerCase().contains(_searchQuery) ||
                item.searchTerms.any((term) => term.contains(_searchQuery));
          }).toList();

          return SettingsSection(title: section.title, items: filteredItems);
        })
        .where((section) => section.items.isNotEmpty)
        .toList();
  }

  Widget _buildSection(BuildContext context, SettingsSection section) {
    if (section.items.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0, bottom: 12),
          child: Text(
            section.title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: colorScheme.categoryProfile.withValues(
            alpha: isDarkMode ? 0.08 : 0.06,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: section.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == section.items.length - 1;

              return _buildSettingsItem(context, item, showDivider: !isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    SettingsItem item, {
    required bool showDivider,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        ListTile(
          onTap: () => _navigateToSetting(item),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.categoryProfile.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: colorScheme.categoryProfile),
          ),
          title: Text(
            item.title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            item.subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Iconsax.arrow_right_3_copy,
            color: colorScheme.onSurfaceVariant,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }

  /// Build dynamic "Profile" section based on available personas
  Widget _buildProfileSection(BuildContext context) {
    final personaState = ref.watch(personaServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Don't show if still loading
    if (personaState.isLoading) {
      return const SizedBox.shrink();
    }

    // Check if user is at profile limit
    final isAtLimit = personaState.isAtProfileLimit;

    // Get available personas (only if not at limit)
    final availablePersonas = isAtLimit
        ? <PersonaAvailability>[]
        : personaState.availablePersonas;

    // Filter by search if active
    final filteredPersonas = _searchQuery.isEmpty
        ? availablePersonas
        : availablePersonas.where((p) {
            final searchLower = _searchQuery.toLowerCase();
            return p.targetPersona.displayName.toLowerCase().contains(
                  searchLower,
                ) ||
                p.targetPersona.description.toLowerCase().contains(
                  searchLower,
                ) ||
                'profile'.contains(searchLower) ||
                'become'.contains(searchLower) ||
                'add'.contains(searchLower);
          }).toList();

    // Show limit message if at limit (and search matches or empty)
    final showLimitMessage =
        isAtLimit &&
        (_searchQuery.isEmpty ||
            'profile'.contains(_searchQuery.toLowerCase()) ||
            'limit'.contains(_searchQuery.toLowerCase()) ||
            'add'.contains(_searchQuery.toLowerCase()));

    // Don't show section if no available personas AND not showing limit message
    if (filteredPersonas.isEmpty && !showLimitMessage) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 0, bottom: 12),
            child: Text(
              'Profiles',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Show existing profiles list when at limit
          if (showLimitMessage)
            _buildExistingProfilesList(
              context,
              colorScheme,
              textTheme,
              isDarkMode,
            ),
          // Show add options if available
          if (filteredPersonas.isNotEmpty) ...[
            if (showLimitMessage) const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: colorScheme.categoryProfile.withValues(
                alpha: isDarkMode ? 0.08 : 0.06,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: filteredPersonas.asMap().entries.map((entry) {
                  final index = entry.key;
                  final availability = entry.value;
                  final isLast = index == filteredPersonas.length - 1;

                  return _buildPersonaItem(
                    context,
                    availability,
                    showDivider: !isLast,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingProfilesList(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDarkMode,
  ) {
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);

    return availableProfilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          color: colorScheme.categoryProfile.withValues(
            alpha: isDarkMode ? 0.08 : 0.06,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: profiles.asMap().entries.map((entry) {
              final index = entry.key;
              final profile = entry.value;
              final isLast = index == profiles.length - 1;
              final effectiveType = profile.personaType ?? profile.profileType;
              final isActive =
                  effectiveType?.toLowerCase() ==
                  activeProfileType?.toLowerCase();

              return Column(
                children: [
                  ListTile(
                    onTap: () {
                      if (!isActive) {
                        // Switch profile and navigate back to profile screen
                        ref.read(activeProfileTypeProvider.notifier).state =
                            effectiveType;
                        persistActiveProfileType(effectiveType);
                        context.go('/profile');
                      }
                    },
                    leading: DSAvatar.small(
                      imageUrl: profile.avatarUrl,
                      displayName: profile.getDisplayName().isNotEmpty
                          ? profile.getDisplayName()
                          : 'Profile',
                      context: AvatarContext.profile,
                    ),
                    title: Text(
                      profile.getDisplayName().isNotEmpty
                          ? profile.getDisplayName()
                          : 'Profile',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      (effectiveType ?? 'player').toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: isActive
                        ? Icon(
                            Iconsax.tick_circle_copy,
                            color: colorScheme.categoryProfile,
                          )
                        : Icon(
                            Iconsax.arrow_right_3_copy,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPersonaItem(
    BuildContext context,
    PersonaAvailability availability, {
    required bool showDivider,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isConversion = availability.actionType == PersonaActionType.convert;

    // Get icon based on persona type
    IconData icon;
    switch (availability.targetPersona) {
      case PersonaType.player:
        icon = Iconsax.people_copy;
        break;
      case PersonaType.organiser:
        icon = Iconsax.calendar_edit_copy;
        break;
      case PersonaType.hoster:
        icon = Iconsax.building_copy;
        break;
      case PersonaType.socialiser:
        icon = Iconsax.message_copy;
        break;
    }

    // Title based on action type
    final title = isConversion
        ? 'Convert to ${availability.targetPersona.displayName}'
        : 'Become a ${availability.targetPersona.displayName}';

    // Subtitle with description
    final subtitle = isConversion
        ? 'Replace your ${availability.convertFrom?.displayName} profile'
        : availability.targetPersona.description;

    return Column(
      children: [
        ListTile(
          onTap: () => _startPersonaFlow(availability),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isConversion
                  ? colorScheme.tertiary.withValues(alpha: 0.12)
                  : colorScheme.categoryProfile.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isConversion
                  ? colorScheme.tertiary
                  : colorScheme.categoryProfile,
            ),
          ),
          title: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConversion)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CONVERT',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Iconsax.arrow_right_3_copy,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }

  void _startPersonaFlow(PersonaAvailability availability) {
    final personaState = ref.read(personaServiceProvider);

    // Re-check active profile count before navigation
    if (personaState.isAtProfileLimit &&
        availability.actionType == PersonaActionType.add) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PersonaRules.profileLimitMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final primaryProfile = personaState.primaryProfile;

    // Initialize add persona data with shared attributes
    ref
        .read(addPersonaDataProvider.notifier)
        .init(
          targetPersona: availability.targetPersona,
          actionType: availability.actionType,
          convertFrom: availability.convertFrom,
          age: primaryProfile?.age,
          gender: primaryProfile?.gender,
          existingProfileId:
              availability.actionType == PersonaActionType.convert
              ? personaState.activeProfiles
                    .firstWhere(
                      (p) => p.personaType == availability.convertFrom,
                      orElse: () => personaState.activeProfiles.first,
                    )
                    .profileId
              : null,
        );

    // Show confirmation for conversion, otherwise start flow directly
    if (availability.actionType == PersonaActionType.convert) {
      _showConversionConfirmDialog(availability);
    } else {
      // Navigate to first screen of add flow (interests selection)
      context.push(RoutePaths.addPersonaInterests);
    }
  }

  void _showConversionConfirmDialog(PersonaAvailability availability) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Convert to ${availability.targetPersona.displayName}?'),
        content: Text(
          'This will deactivate your ${availability.convertFrom?.displayName} profile and create a new ${availability.targetPersona.displayName} profile.\n\n'
          'Your account data (age, gender) will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to first screen of add flow
              context.push(RoutePaths.addPersonaInterests);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Card(
        elevation: 0,
        color: colorScheme.categoryProfile.withValues(
          alpha: isDarkMode ? 0.08 : 0.06,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ListTile(
          onTap: _showSignOutDialog,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Iconsax.logout_copy, color: colorScheme.error),
          ),
          title: Text(
            'Sign out',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.error,
            ),
          ),
          subtitle: Text(
            'Leave your account on this device',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Iconsax.arrow_right_3_copy,
            color: colorScheme.onSurfaceVariant,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dabbler',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Version $_appVersion',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '© 2026 Dabbler. All rights reserved.',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSetting(SettingsItem item) {
    context.push(item.route);
  }

  void _showSignOutDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _signOut();
            },
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Prefer SimpleAuthNotifier (independent of unimplemented AuthRepository).
      try {
        await ref.read(simpleAuthProvider.notifier).signOut();
      } on UnimplementedError catch (_) {
        // Fallback: direct AuthService sign out if provider path not ready
        await AuthService().signOut();
        routerRefreshNotifier.notifyAuthStateChanged();
      }

      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        // Navigate to phone input (primary auth entry) instead of legacy /login
        context.go(RoutePaths.phoneInput);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class SettingsSection {
  final String title;
  final List<SettingsItem> items;

  SettingsSection({required this.title, required this.items});
}

class SettingsItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final List<String> searchTerms;

  SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.searchTerms,
  });
}
