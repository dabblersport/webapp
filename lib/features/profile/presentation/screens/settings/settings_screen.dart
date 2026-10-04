import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/core/services/theme_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_settings_screen.dart'
    show privacyProfileShownCount, privacyActivityShownCount;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:dabbler/l10n/app_localizations.dart';

// ─── Supported options ────────────────────────────────────────────────────────

const _kSupportedCountries = [
  (name: 'Egypt'),
  (name: 'United Arab Emirates'),
  (name: 'Saudi Arabia'),
  (name: 'Morocco'),
];

const _kSupportedLanguages = [
  (code: 'en', label: 'English', native: 'English'),
  (code: 'ar', label: 'Arabic', native: 'العربية'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _appVersion = '1.7.8';

  List<SettingsSection> _allSections(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      SettingsSection(
        title: l10n.settings_section_account,
        items: [
          SettingsItem(
            id: 'edit_profile',
            title: l10n.profile_btn_edit,
            subtitle: l10n.settings_item_edit_profile_subtitle,
            icon: 'edit',
            route: '/profile/edit',
            searchTerms: ['profile', 'name', 'photo', 'avatar', 'bio', 'edit'],
          ),
          SettingsItem(
            id: 'account_management',
            title: l10n.settings_item_account_management_title,
            subtitle: l10n.settings_item_account_management_subtitle,
            icon: 'profile-circle',
            route: '/settings/account',
            searchTerms: ['account', 'email', 'password', 'security', 'login'],
          ),
          SettingsItem(
            id: 'privacy_settings',
            title: l10n.settings_item_privacy_settings_title,
            subtitle: l10n.settings_item_privacy_settings_subtitle,
            icon: 'slash',
            route: '/settings/privacy',
            searchTerms: ['blocked', 'block', 'users', 'privacy', 'safety'],
          ),
        ],
      ),
      SettingsSection(
        title: l10n.settings_section_display,
        items: [
          SettingsItem(
            id: 'theme',
            title: l10n.settings_item_theme_title,
            subtitle: l10n.settings_item_theme_subtitle,
            icon: 'colorfilter',
            route: '/settings/theme',
            searchTerms: ['theme', 'dark', 'light', 'appearance'],
          ),
          SettingsItem(
            id: 'language',
            title: l10n.settings_item_language_title,
            subtitle: 'English · العربية',
            icon: 'language-square',
            route: '',
            searchTerms: [
              'language',
              'locale',
              'translate',
              'arabic',
              'english',
              'ar',
              'en',
            ],
          ),
          SettingsItem(
            id: 'app_country',
            title: l10n.settings_item_country_title,
            subtitle: l10n.settings_item_country_default_subtitle,
            icon: 'global',
            route: '',
            searchTerms: [
              'country',
              'region',
              'egypt',
              'uae',
              'ksa',
              'saudi',
              'morocco',
            ],
          ),
        ],
      ),
      SettingsSection(
        title: l10n.settings_section_about,
        items: [
          SettingsItem(
            id: 'terms_of_service',
            title: l10n.settings_item_terms_title,
            subtitle: l10n.settings_item_terms_subtitle,
            icon: 'document-text',
            route: '/about/terms',
            searchTerms: ['terms', 'service', 'conditions', 'legal'],
          ),
          SettingsItem(
            id: 'privacy_policy',
            title: l10n.settings_item_privacy_policy_title,
            subtitle: l10n.settings_item_privacy_policy_subtitle,
            icon: 'security-card',
            route: '/about/privacy',
            searchTerms: ['privacy', 'policy', 'data', 'legal'],
          ),
          SettingsItem(
            id: 'licenses',
            title: l10n.settings_item_licenses_title,
            subtitle: l10n.settings_item_licenses_subtitle,
            icon: 'code-circle',
            route: '/about/licenses',
            searchTerms: ['licenses', 'open', 'source', 'legal'],
          ),
        ],
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    // Fetch user's active personas for dynamic "Add Profile" section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        ref.read(privacyControllerProvider.notifier).loadPrivacySettings(uid);
      }
      ref.read(personaServiceProvider.notifier).fetchUserPersonas();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = AuthService().getCurrentUser()?.email ?? '';
    return DabblerPage(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DabblerSettingsHeader(
              topBar: DabblerNavigationTopBar.titled(
                onBack: () => context.pop(),
                transparent: true,
                actions: [
                  DabblerNavigationAction(
                    icon: 'information',
                    label: l10n.settings_header_help_tooltip,
                    onPressed: () => context.push('/help/center'),
                  ),
                ],
              ),
              versionLabel: l10n.settings_version_label(_appVersion),
              title: l10n.settings_header_title,
              subtitle: l10n.settings_hero_subtitle,
              identity: DabblerInputRow(
                flat: true,
                showDivider: false,
                onTap: () => context.push('/settings/account'),
                leading: DabblerAvatar(
                  seed: email.isEmpty ? 'dabbler' : email,
                  size: DabblerAvatarSize.md,
                ),
                title: email.isEmpty
                    ? l10n.settings_item_account_management_title
                    : email,
                subtitle: l10n.settings_item_account_management_subtitle,
                trailing: const DabblerChevron(),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                DabblerSpacing.space5,
                DabblerSpacing.space6,
                DabblerSpacing.space5,
                DabblerSpacing.space10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DabblerSearchField(
                    controller: _searchController,
                    placeholder: l10n.settings_search_hint,
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                    onCleared: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                  const DabblerGap.v(DabblerSpacing.space6),
                  if (_searchQuery.isEmpty) ...[
                    _buildTiles(context),
                    const DabblerGap.v(DabblerSpacing.space6),
                  ],
                  _buildProfileSection(context),
                  ..._buildFilteredSectionsList(context),
                  const DabblerGap.v(DabblerSpacing.space6),
                  _buildSignOutSection(context),
                  _buildVersionInfo(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiles(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(blockedUsersWithProfilesProvider);
    final privacy = ref.watch(privacyControllerProvider).settings;
    final notif = ref.watch(notificationSettingsControllerProvider).settings;
    final themeMode = ThemeService().themeMode;
    final country = ref.watch(selectedCountryProvider).valueOrNull ?? '';
    final themeLabel = switch (themeMode) {
      ThemeMode.light => l10n.settings_item_theme_title,
      ThemeMode.dark => l10n.settings_item_theme_title,
      ThemeMode.system => l10n.settings_item_theme_title,
    };
    final notifOn = notif == null
        ? null
        : '${[notif.pushEnabled, notif.emailEnabled].where((e) => e).length}/2';
    return DabblerStatGrid(
      rowExtent: DabblerStatGrid.detailsRowHeight,
      children: [
        DabblerStatTile(
          size: DabblerStatTileSize.setting,
          span: 3,
          tone: DabblerStatTileTone.brand,
          icon: const DabblerIcon('shield-tick'),
          value: l10n.settings_tile_privacy,
          label: l10n.settings_tile_privacy_label,
          fitValue: true,
          onTap: () => context.push('/settings/privacy'),
        ),
        if (privacy != null)
          DabblerStatTile(
            size: DabblerStatTileSize.setting,
            span: 3,
            tone: DabblerStatTileTone.amber,
            icon: const DabblerIcon('profile-circle'),
            value: DabblerType.toWesternDigits(
              privacyProfileShownCount(privacy),
            ),
            label: l10n.settings_tile_profile_shown,
            fitValue: true,
            onTap: () => context.push('/settings/privacy'),
          ),
        if (notifOn != null)
          DabblerStatTile(
            size: DabblerStatTileSize.setting,
            span: 2,
            tone: DabblerStatTileTone.accent,
            icon: const DabblerIcon('notification'),
            value: DabblerType.toWesternDigits(notifOn),
            label: l10n.settings_tile_notifications,
            fitValue: true,
            onTap: () => context.push('/settings/notifications'),
          ),
        DabblerStatTile(
          size: DabblerStatTileSize.setting,
          span: 2,
          icon: const DabblerIcon('colorfilter'),
          value: themeLabel,
          label: l10n.settings_tile_appearance,
          fitValue: true,
          onTap: () => context.push('/settings/theme'),
        ),
        DabblerStatTile(
          size: DabblerStatTileSize.setting,
          span: 2,
          tone: DabblerStatTileTone.sunken,
          icon: const DabblerIcon('global'),
          value: country.isEmpty ? '-' : country,
          label: l10n.settings_tile_language_region,
          fitValue: true,
          onTap: _showLanguagePicker,
        ),
        if (privacy != null)
          DabblerStatTile(
            size: DabblerStatTileSize.setting,
            span: 3,
            tone: DabblerStatTileTone.sunken,
            icon: const DabblerIcon('activity'),
            value: DabblerType.toWesternDigits(
              privacyActivityShownCount(privacy),
            ),
            label: l10n.settings_tile_activity_shown,
            fitValue: true,
            onTap: () => context.push('/settings/privacy'),
          ),
        if (blocked.valueOrNull != null)
          DabblerStatTile(
            size: DabblerStatTileSize.setting,
            span: 3,
            icon: const DabblerIcon('slash'),
            value: DabblerType.toWesternDigits(
              '${blocked.valueOrNull!.length}',
            ),
            label: l10n.settings_tile_blocked,
            fitValue: true,
            onTap: () => context.push('/settings/privacy'),
          ),
      ],
    );
  }

  List<Widget> _buildFilteredSectionsList(BuildContext context) {
    return _getFilteredSections(context).map((section) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space6),
        child: _buildSection(context, section),
      );
    }).toList();
  }

  List<SettingsSection> _getFilteredSections(BuildContext context) {
    final allSections = _allSections(context);
    if (_searchQuery.isEmpty) return allSections;
    return allSections
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
    return DabblerRowGroup(
      header: section.title,
      children: [
        for (final item in section.items) _buildSettingsItem(context, item),
      ],
    );
  }

  Widget _leadingIcon(String name, {Color? color}) {
    final colors = DabblerColors.of(context);
    return DabblerIcon(
      name,
      size: DabblerSizing.iconMd,
      color: color ?? colors.textPrimary,
    );
  }

  Widget _buildSettingsItem(BuildContext context, SettingsItem item) {
    // Dynamic subtitle for inline-picker items
    String subtitle = item.subtitle;
    if (item.id == 'language') {
      final langCode = ref.watch(localeProvider).languageCode;
      final lang = _kSupportedLanguages.firstWhere(
        (l) => l.code == langCode,
        orElse: () => _kSupportedLanguages.first,
      );
      subtitle = '${lang.label} · ${lang.native}';
    } else if (item.id == 'app_country') {
      final country = ref.watch(selectedCountryProvider).valueOrNull ?? '';
      if (country.isNotEmpty) {
        final meta = _kSupportedCountries
            .where((c) => c.name.toLowerCase() == country.toLowerCase())
            .firstOrNull;
        subtitle = meta != null ? meta.name : country;
      }
    }

    return DabblerInputRow(
      flat: true,
      showDivider: false,
      onTap: () => _navigateToSetting(item),
      leading: _leadingIcon(item.icon),
      title: item.title,
      subtitle: subtitle,
      trailing: const DabblerChevron(),
    );
  }

  /// Build dynamic "Profile" section based on available personas
  Widget _buildProfileSection(BuildContext context) {
    final personaState = ref.watch(personaServiceProvider);
    if (personaState.isLoading) return const SizedBox.shrink();

    final isAtLimit = personaState.isAtProfileLimit;
    final availablePersonas = isAtLimit
        ? <PersonaAvailability>[]
        : personaState.availablePersonas;

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

    final showLimitMessage =
        isAtLimit &&
        (_searchQuery.isEmpty ||
            'profile'.contains(_searchQuery.toLowerCase()) ||
            'limit'.contains(_searchQuery.toLowerCase()) ||
            'add'.contains(_searchQuery.toLowerCase()));

    if (filteredPersonas.isEmpty && !showLimitMessage) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space3),
      child: DabblerRowGroup(
        header: AppLocalizations.of(context).settings_section_profiles,
        children: [
          if (showLimitMessage) _buildExistingProfilesList(context),
          for (final availability in filteredPersonas)
            _buildPersonaItem(context, availability),
        ],
      ),
    );
  }

  Widget _buildExistingProfilesList(BuildContext context) {
    final availableProfilesAsync = ref.watch(availableProfilesProvider);
    final activeProfileType = ref.watch(activeProfileTypeProvider);
    final colors = DabblerColors.of(context);

    return availableProfilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final profile in profiles)
              Builder(
                builder: (context) {
                  final effectiveType =
                      profile.personaType ?? profile.profileType;
                  final isActive =
                      effectiveType?.toLowerCase() ==
                      activeProfileType?.toLowerCase();
                  final name = profile.getDisplayName().isNotEmpty
                      ? profile.getDisplayName()
                      : 'Profile';
                  return DabblerInputRow(
                    flat: true,
                    showDivider: false,
                    onTap: () => _switchProfile(isActive, effectiveType),
                    leading: DabblerAvatar(
                      seed: name,
                      imageUrl: profile.avatarUrl,
                      size: DabblerAvatarSize.sm,
                    ),
                    title: name,
                    subtitle: (effectiveType ?? 'player').toUpperCase(),
                    trailing: isActive
                        ? DabblerIcon(
                            'tick-circle',
                            size: DabblerSizing.iconMd,
                            color: colors.brandPrimary,
                          )
                        : const DabblerChevron(),
                  );
                },
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(DabblerSpacing.space5),
        child: Center(child: DabblerSpinner()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _switchProfile(bool isActive, String? effectiveType) async {
    if (isActive || effectiveType == null) return;
    // Switch active profile in the database
    final switched = await ref
        .read(personaServiceProvider.notifier)
        .switchActiveProfile(effectiveType);

    if (!switched) {
      if (mounted) {
        final errorMsg =
            ref.read(personaServiceProvider).errorMessage ??
            AppLocalizations.of(context).profile_error_switch_profile_failed;
        _toast(errorMsg);
      }
      return;
    }

    // Update local state and persist
    ref.read(activeProfileTypeProvider.notifier).state = effectiveType;
    persistActiveProfileType(effectiveType);

    // Clear cached profile so the profile screen loads fresh data
    final userId = AuthService().getCurrentUser()?.id;
    if (userId != null) {
      final localDS = ref.read(profileLocalDataSourceProvider);
      await localDS.clearUserCache(userId);
    }

    if (mounted) context.go('/profile');
  }

  void _toast(
    String message, {
    DabblerToastTone tone = DabblerToastTone.neutral,
  }) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  Widget _buildPersonaItem(
    BuildContext context,
    PersonaAvailability availability,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final isConversion = availability.actionType == PersonaActionType.convert;

    final String icon = switch (availability.targetPersona) {
      PersonaType.player => 'people',
      PersonaType.organiser => 'calendar-edit',
      PersonaType.host => 'building',
      PersonaType.socialiser => 'message',
    };

    final title = isConversion
        ? l10n.settings_persona_convert_title(
            availability.targetPersona.displayName,
          )
        : l10n.settings_persona_become_title(
            availability.targetPersona.displayName,
          );

    final subtitle = isConversion
        ? l10n.settings_persona_convert_subtitle(
            availability.convertFrom?.displayName ?? '',
          )
        : availability.targetPersona.description;

    return DabblerInputRow(
      flat: true,
      showDivider: false,
      onTap: () => _startPersonaFlow(availability),
      leading: _leadingIcon(
        icon,
        color: isConversion ? colors.accent : colors.textPrimary,
      ),
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConversion) ...[
            DabblerBadge(
              label: l10n.profile_persona_convert_badge.toUpperCase(),
              tone: DabblerBadgeTone.primary,
            ),
            const SizedBox(width: DabblerSpacing.space2),
          ],
          const DabblerChevron(),
        ],
      ),
    );
  }

  void _startPersonaFlow(PersonaAvailability availability) {
    final personaState = ref.read(personaServiceProvider);

    // Re-check active profile count before navigation
    if (personaState.isAtProfileLimit &&
        availability.actionType == PersonaActionType.add) {
      _toast(PersonaRules.profileLimitMessage, tone: DabblerToastTone.error);
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

    if (availability.actionType == PersonaActionType.convert) {
      _showConversionConfirmDialog(availability);
    } else {
      context.push(RoutePaths.addPersonaInterests);
    }
  }

  void _showConversionConfirmDialog(PersonaAvailability availability) {
    final l10n = AppLocalizations.of(context);
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        onClose: () => Navigator.of(dialogContext).pop(),
        title: l10n.profile_convert_to(availability.targetPersona.displayName),
        description: l10n.settings_persona_convert_confirm_body(
          availability.convertFrom?.displayName ?? '',
          availability.targetPersona.displayName,
        ),
        secondaryAction: DabblerDialogAction(
          label: l10n.profile_btn_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        primaryAction: DabblerDialogAction(
          label: l10n.profile_btn_continue,
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.push(RoutePaths.addPersonaInterests);
          },
        ),
      ),
    );
  }

  Widget _buildSignOutSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      children: [
        DabblerInputRow(
          flat: true,
          showDivider: false,
          onTap: _showSignOutDialog,
          leading: const DabblerIcon('logout'),
          tone: DabblerInputRowTone.destructive,
          title: l10n.settings_sign_out_title,
          subtitle: l10n.settings_sign_out_subtitle,
        ),
      ],
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerText(
            l10n.settings_version_app_name,
            style: DabblerType.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DabblerSpacing.space2),
          DabblerText(
            l10n.settings_version_label(_appVersion),
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DabblerSpacing.space2),
          DabblerText(
            l10n.settings_version_copyright,
            style: DabblerType.caption1,
            tone: DabblerTextTone.tertiary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToSetting(SettingsItem item) {
    if (item.id == 'language') {
      _showLanguagePicker();
    } else if (item.id == 'app_country') {
      _showCountryPicker();
    } else {
      context.push(item.route);
    }
  }

  Widget _pickerRow({
    required String label,
    String? sublabel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final row = DabblerInputRow(
      title: label,
      subtitle: sublabel,
      onTap: onTap,
      selected: isSelected,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space2),
      child: row,
    );
  }

  void _showLanguagePicker() {
    showDabblerSheet<void>(
      context: context,
      title: AppLocalizations.of(context).settings_item_language_title,
      detent: DabblerSheetDetent.content,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final lang in _kSupportedLanguages)
            _pickerRow(
              label: lang.label,
              sublabel: lang.native,
              isSelected: ref.read(localeProvider).languageCode == lang.code,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(Locale(lang.code));
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  void _showCountryPicker() {
    final currentCountry = ref.read(selectedCountryProvider).valueOrNull ?? '';
    final l10n = AppLocalizations.of(context);
    showDabblerSheet<void>(
      context: context,
      title: l10n.settings_item_country_title,
      detent: DabblerSheetDetent.content,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: DabblerSpacing.space4),
            child: DabblerText(
              l10n.settings_country_picker_helper,
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
          ),
          for (final c in _kSupportedCountries)
            _pickerRow(
              label: c.name,
              isSelected: currentCountry.toLowerCase() == c.name.toLowerCase(),
              onTap: () {
                ref.read(selectedCountryProvider.notifier).setCountry(c.name);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    final l10n = AppLocalizations.of(context);
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        destructive: true,
        onClose: () => Navigator.of(dialogContext).pop(),
        title: l10n.settings_sign_out_dialog_title,
        description: l10n.settings_sign_out_dialog_body,
        secondaryAction: DabblerDialogAction(
          label: l10n.settings_sign_out_dialog_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        primaryAction: DabblerDialogAction(
          label: l10n.settings_sign_out_dialog_title,
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await _signOut();
          },
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      // Show loading indicator
      showDabblerDialog<void>(
        context: context,
        builder: (_) => const Center(child: DabblerSpinner()),
      );

      // Prefer SimpleAuthNotifier (independent of unimplemented AuthRepository).
      try {
        await ref.read(simpleAuthProvider.notifier).signOut();
      } on UnimplementedError catch (_) {
        // Fallback: direct AuthService sign out if provider path not ready
        await AuthService().signOut();
        routerRefreshNotifier.notifyAuthStateChanged();
      }

      // Both signOut paths above already notify the router, which redirects
      // to /landing. Dismiss the loading dialog on the next frame (KAN-99).
      _dismissLoadingDialog();
    } catch (e) {
      _dismissLoadingDialog();
      if (mounted) {
        _toast(
          AppLocalizations.of(context).settings_sign_out_error(e.toString()),
          tone: DabblerToastTone.error,
        );
      }
    }
  }

  void _dismissLoadingDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    });
  }
}

class SettingsSection {
  final String title;
  final List<SettingsItem> items;

  SettingsSection({required this.title, required this.items});
}

class SettingsItem {
  final String id;
  final String title;
  final String subtitle;

  /// Kebab-case icon name drawn through [DabblerIcon].
  final String icon;
  final String route;
  final List<String> searchTerms;

  SettingsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.searchTerms,
  });
}
