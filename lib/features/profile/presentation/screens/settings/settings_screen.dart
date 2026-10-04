import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_profiles.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_search.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_sheets.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_tiles.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/l10n/app_localizations.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SettingsProfilesMixin<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _searchQuery = '';
  final String _appVersion = '1.7.8';

  /// Scroll offset past which the bar drops the hero tint and shows its title
  /// (`Settings.dc.html:1192` — the hero's height less the 52px bar).
  static const double _titleRevealOffset = 260;

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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = AuthService().getCurrentUser()?.email ?? '';
    final searching = _searchQuery.isNotEmpty;
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.settings_header_title,
        onBack: () => context.pop(),
        scrollController: _scroll,
        titleRevealOffset: _titleRevealOffset,
        heroTint: true,
        actions: [
          DabblerNavigationAction(
            icon: 'information',
            label: l10n.settings_header_help_tooltip,
            onPressed: () => context.push('/help/center'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DabblerSettingsHeader(
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
                subtitle: l10n.settings_identity_subtitle,
                trailing: const DabblerChevron(circled: true),
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
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                    onCleared: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                  const DabblerGap.v(DabblerSpacing.space6),
                  if (searching)
                    SettingsSearchResults(
                      results: _searchEntries(
                        context,
                      ).where((e) => e.matches(_searchQuery)).toList(),
                    )
                  else ...[
                    SettingsTiles(
                      onLanguageRegion: () =>
                          showSettingsLanguageRegionSheet(context, ref),
                    ),
                    const DabblerGap.v(DabblerSpacing.space6),
                    buildProfileSection(context),
                    _buildAboutSection(context),
                    const DabblerGap.v(DabblerSpacing.space6),
                    _buildSignOutSection(context),
                    _buildVersionInfo(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Everything the root can reach, for the search list.
  List<SettingsSearchEntry> _searchEntries(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    SettingsSearchEntry route(
      String icon,
      String label,
      String path,
      String to, [
      List<String> terms = const [],
    ]) => SettingsSearchEntry(
      icon: icon,
      label: label,
      path: path,
      terms: terms,
      onTap: () => context.push(to),
    );
    final organiser = organiserAvailability();
    return [
      if (organiser != null)
        SettingsSearchEntry(
          icon: 'calendar-edit',
          label: l10n.settings_organiser_title,
          path: l10n.settings_path_profiles,
          onTap: () => openOrganiser(organiser),
        ),
      route(
        'edit',
        l10n.profile_btn_edit,
        l10n.settings_path_profiles,
        '/profile/edit',
        ['profile', 'name', 'photo', 'avatar', 'bio'],
      ),
      route(
        'profile-circle',
        l10n.settings_item_account_management_title,
        l10n.settings_path_account,
        '/settings/account',
        ['email', 'password', 'security', 'login'],
      ),
      route(
        'shield-tick',
        l10n.settings_tile_privacy_preset,
        l10n.settings_path_privacy,
        '/settings/privacy',
        ['privacy', 'safety'],
      ),
      route(
        'slash',
        l10n.settings_tile_blocked,
        l10n.settings_path_privacy_safety,
        '/settings/privacy',
        ['block', 'blocked', 'users'],
      ),
      route(
        'notification',
        l10n.settings_tile_notifications,
        l10n.settings_tile_notifications,
        '/settings/notifications',
        ['push', 'email', 'alerts'],
      ),
      route(
        'colorfilter',
        l10n.settings_item_theme_title,
        l10n.settings_path_appearance,
        '/settings/theme',
        ['dark', 'light', 'appearance'],
      ),
      SettingsSearchEntry(
        icon: 'translate',
        label: l10n.settings_item_language_title,
        path: l10n.settings_tile_language_region,
        terms: const ['locale', 'arabic', 'english'],
        onTap: () => showSettingsLanguageRegionSheet(context, ref),
      ),
      SettingsSearchEntry(
        icon: 'global',
        label: l10n.settings_item_country_title,
        path: l10n.settings_tile_language_region,
        terms: const ['country', 'region', 'egypt', 'uae', 'saudi', 'morocco'],
        onTap: () => showSettingsLanguageRegionSheet(context, ref),
      ),
      route(
        'document-text',
        l10n.settings_item_terms_title,
        l10n.settings_about_title,
        '/about/terms',
        ['legal', 'conditions'],
      ),
      route(
        'shield-tick',
        l10n.settings_item_privacy_policy_title,
        l10n.settings_about_title,
        '/about/privacy',
        ['legal', 'data'],
      ),
      route(
        'code',
        l10n.settings_item_licenses_title,
        l10n.settings_about_title,
        '/about/licenses',
        ['legal', 'open', 'source'],
      ),
      SettingsSearchEntry(
        icon: 'logout',
        label: l10n.settings_sign_out_title,
        path: l10n.settings_path_root,
        onTap: _showSignOutDialog,
      ),
    ];
  }

  Widget _buildAboutSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space6),
      child: DabblerRowGroup(
        header: l10n.settings_section_about,
        children: [
          DabblerInputRow(
            flat: true,
            showDivider: false,
            onTap: () => showSettingsAboutSheet(context),
            leading: leadingIcon('information'),
            title: l10n.settings_about_title,
            subtitle: l10n.settings_about_subtitle,
            value: l10n.settings_version_label(_appVersion),
            trailing: const DabblerChevron(circled: true),
          ),
        ],
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
            style: DabblerType.subheadline,
            weight: DabblerTextWeight.semibold,
            tone: DabblerTextTone.secondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DabblerSpacing.space1),
          DabblerText(
            l10n.settings_version_label(_appVersion),
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DabblerSpacing.space1),
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

  void _showSignOutDialog() => showSettingsSignOutSheet(context, _signOut);

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
        toast(
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
