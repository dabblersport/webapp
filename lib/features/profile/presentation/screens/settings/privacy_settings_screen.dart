import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_presets.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_toggles.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings/settings_top_bar.dart';
import 'package:dabbler/features/profile/presentation/widgets/blocked_accounts_group.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

export 'package:dabbler/features/profile/presentation/screens/settings/privacy_presets.dart'
    show PrivacyPreset;

/// The privacy pages of `Settings.dc.html`: a hub (preset cards, then a row per
/// group of switches) and the pages it opens. The pages are states of this one
/// screen — the route stays `/settings/privacy`.
enum _Page {
  hub,
  profile,
  activity,
  discovery,
  contact,
  data,
  notifications,
  blocked,
}

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  PrivacyPreset _selectedPreset = PrivacyPreset.public;
  _Page _page = _Page.hub;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Load privacy settings from Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        ref
            .read(privacyControllerProvider.notifier)
            .loadPrivacySettings(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final privacyState = ref.watch(privacyControllerProvider);
    final settings = privacyState.settings;

    // Sync local preset selection when settings first load
    if (settings != null && !_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedPreset = detectPrivacyPreset(settings));
        }
      });
    }

    return PopScope(
      canPop: _page == _Page.hub,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _page = _Page.hub);
      },
      child: DabblerPage(
        topBar: settingsTopBar(
          context,
          title: _title(l10n),
          onBack: () => _page == _Page.hub
              ? context.pop()
              : setState(() => _page = _Page.hub),
        ),
        body: privacyState.isLoading
            ? const Center(child: DabblerSpinner())
            : ListView(
                padding: kSettingsBodyPadding,
                children: _page == _Page.blocked
                    ? _blockedPage()
                    : settings == null
                    ? const []
                    : _pageBody(l10n, settings),
              ),
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (_page) {
    _Page.hub => l10n.priv_title,
    _Page.profile => l10n.priv_profile_title,
    _Page.activity => l10n.priv_activity_title,
    _Page.discovery => l10n.priv_discover_title,
    _Page.contact => l10n.priv_contact_nav,
    _Page.data => l10n.priv_data_title,
    _Page.notifications => l10n.priv_notif_title,
    _Page.blocked => l10n.priv_blocked_title,
  };

  List<Widget> _pageBody(AppLocalizations l10n, PrivacySettings s) {
    return switch (_page) {
      _Page.hub => _hub(l10n, s),
      _Page.profile => [_toggleGroup(privacyProfileToggles, s, l10n, true)],
      _Page.activity => [_toggleGroup(privacyActivityToggles, s, l10n, true)],
      _Page.discovery => [_toggleGroup(privacyDiscoveryToggles, s, l10n, true)],
      _Page.data => [_toggleGroup(privacyDataToggles, s, l10n, false)],
      _Page.notifications => [
        _toggleGroup(privacyNotificationToggles, s, l10n, false),
      ],
      _Page.contact => [_contactGroup(l10n, s)],
      _Page.blocked => const [],
    };
  }

  // ─── Hub ────────────────────────────────────────────────────────────────

  List<Widget> _hub(AppLocalizations l10n, PrivacySettings s) {
    final blockedCount =
        ref.watch(blockedUsersWithProfilesProvider).valueOrNull?.length ?? 0;
    return [
      DabblerRowGroup.stack(
        header: l10n.priv_preset_header,
        note: l10n.priv_preset_note,
        children: _presetCards(l10n),
      ),
      kSettingsGroupGap,
      DabblerRowHint(text: l10n.priv_hint),
      kSettingsGroupGap,
      DabblerRowGroup(
        header: l10n.priv_group_see,
        children: [
          _navRow(
            'profile-circle',
            l10n.priv_profile_title,
            l10n.priv_profile_sub,
            _count(l10n, privacyProfileToggles, s),
            _Page.profile,
          ),
          _navRow(
            'activity',
            l10n.priv_activity_title,
            l10n.priv_activity_sub,
            _count(l10n, privacyActivityToggles, s),
            _Page.activity,
          ),
          _navRow(
            'search-normal',
            l10n.priv_discover_title,
            l10n.priv_discover_sub,
            _count(l10n, privacyDiscoveryToggles, s),
            _Page.discovery,
          ),
        ],
      ),
      kSettingsGroupGap,
      DabblerRowGroup(
        header: l10n.priv_group_comm,
        children: [
          _navRow(
            'message-text',
            l10n.priv_contact_title,
            l10n.priv_contact_sub,
            _audienceLabel(l10n, s.messagePreference),
            _Page.contact,
          ),
        ],
      ),
      kSettingsGroupGap,
      DabblerRowGroup(
        header: l10n.priv_group_data,
        children: [
          _navRow(
            'chart',
            l10n.priv_data_title,
            l10n.priv_data_sub,
            _count(l10n, privacyDataToggles, s),
            _Page.data,
          ),
          _navRow(
            'notification',
            l10n.priv_notif_title,
            l10n.priv_notif_sub,
            _count(l10n, privacyNotificationToggles, s),
            _Page.notifications,
          ),
        ],
      ),
      kSettingsGroupGap,
      DabblerRowGroup(
        header: l10n.priv_group_safety,
        children: [
          _navRow(
            'slash',
            l10n.priv_blocked_title,
            l10n.priv_blocked_sub,
            DabblerType.toWesternDigits('$blockedCount'),
            _Page.blocked,
          ),
        ],
      ),
    ];
  }

  Widget _navRow(
    String icon,
    String title,
    String subtitle,
    String value,
    _Page page,
  ) {
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      leading: settingsRowIcon(context, icon),
      title: title,
      subtitle: subtitle,
      value: value,
      onTap: () => setState(() => _page = page),
    );
  }

  String _count(
    AppLocalizations l10n,
    List<PrivacyToggle> toggles,
    PrivacySettings s,
  ) {
    final on = privacyOnCount(toggles, s);
    final label = on == toggles.length
        ? l10n.priv_count_all(toggles.length)
        : on == 0
        ? l10n.priv_count_none
        : l10n.priv_count_some(on, toggles.length);
    return DabblerType.toWesternDigits(label);
  }

  // ─── Presets ────────────────────────────────────────────────────────────

  List<Widget> _presetCards(AppLocalizations l10n) {
    final cards = <(PrivacyPreset, String, String, String)>[
      (
        PrivacyPreset.public,
        'global',
        l10n.priv_preset_public,
        l10n.priv_preset_public_desc,
      ),
      (
        PrivacyPreset.friendsOnly,
        'people',
        l10n.priv_preset_friends,
        l10n.priv_preset_friends_desc,
      ),
      (
        PrivacyPreset.private,
        'lock',
        l10n.priv_preset_private,
        l10n.priv_preset_private_desc,
      ),
      if (_selectedPreset == PrivacyPreset.custom)
        (
          PrivacyPreset.custom,
          'setting-4',
          l10n.priv_preset_custom,
          l10n.priv_preset_custom_desc,
        ),
    ];
    return [
      for (final c in cards)
        DabblerPresetCard(
          icon: c.$2,
          title: c.$3,
          description: c.$4,
          selected: _selectedPreset == c.$1,
          onTap: () => _applyPreset(c.$1, c.$3),
        ),
    ];
  }

  Future<void> _applyPreset(PrivacyPreset preset, String label) async {
    if (preset == PrivacyPreset.custom) return;
    setState(() => _selectedPreset = preset);
    ref
        .read(privacyControllerProvider.notifier)
        .applyPreset(privacyPresetSettings(preset));
    await _save(AppLocalizations.of(context).priv_preset_applied(label));
  }

  // ─── Switches ───────────────────────────────────────────────────────────

  Widget _toggleGroup(
    List<PrivacyToggle> toggles,
    PrivacySettings s,
    AppLocalizations l10n,
    bool breaksPreset,
  ) {
    return DabblerRowGroup(
      children: [
        for (final t in toggles)
          DabblerInputRow.toggle(
            flat: true,
            showDivider: false,
            leading: settingsRowIcon(context, t.icon),
            title: t.title(l10n),
            subtitle: t.subtitle(l10n),
            checked: t.read(s),
            toggleSemanticLabel: t.title(l10n),
            onChanged: (value) {
              ref
                  .read(privacyControllerProvider.notifier)
                  .updateSetting(t.key, value);
              if (breaksPreset) {
                setState(() => _selectedPreset = PrivacyPreset.custom);
              }
              _save(l10n.priv_saved);
            },
          ),
      ],
    );
  }

  /// Every change applies at once — there is no Save button.
  Future<void> _save(String savedMessage) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final saved = await ref
        .read(privacyControllerProvider.notifier)
        .saveAllChanges(userId);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    _toast(
      saved ? savedMessage : l10n.priv_save_failed,
      saved ? DabblerToastTone.neutral : DabblerToastTone.error,
    );
  }

  // ─── Contact ────────────────────────────────────────────────────────────

  Widget _contactGroup(AppLocalizations l10n, PrivacySettings s) {
    return DabblerRowGroup(
      children: [
        _prefRow(
          'message-text',
          l10n.priv_dm_title,
          l10n.priv_dm_sub,
          'messagePreference',
          s.messagePreference,
        ),
        _prefRow(
          'game',
          l10n.priv_invites_title,
          l10n.priv_invites_sub,
          'gameInvitePreference',
          s.gameInvitePreference,
        ),
        _prefRow(
          'user-add',
          l10n.priv_requests_title,
          l10n.priv_requests_sub,
          'friendRequestPreference',
          s.friendRequestPreference,
        ),
      ],
    );
  }

  Widget _prefRow(
    String icon,
    String title,
    String subtitle,
    String key,
    CommunicationPreference value,
  ) {
    final l10n = AppLocalizations.of(context);
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      leading: settingsRowIcon(context, icon),
      title: title,
      subtitle: subtitle,
      value: _audienceLabel(l10n, value),
      onTap: () => showDabblerSheet<void>(
        context: context,
        title: title,
        detent: DabblerSheetDetent.content,
        showCloseButton: false,
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final pref in CommunicationPreference.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: DabblerSpacing.space2,
                ),
                child: DabblerOptionRow(
                  label: _audienceLabel(l10n, pref),
                  selected: pref == value,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ref
                        .read(privacyControllerProvider.notifier)
                        .updateSetting(key, pref);
                    _save(l10n.priv_saved);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _audienceLabel(AppLocalizations l10n, CommunicationPreference pref) =>
      switch (pref) {
        CommunicationPreference.anyone => l10n.priv_audience_anyone,
        CommunicationPreference.friendsOnly => l10n.priv_audience_friends,
        CommunicationPreference.organizersOnly => l10n.priv_audience_organizers,
        CommunicationPreference.none => l10n.priv_audience_none,
      };

  // ─── Blocked accounts ───────────────────────────────────────────────────

  List<Widget> _blockedPage() => const [BlockedAccountsGroup()];

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }
}

/// How many of the profile-visibility toggles are on, as `n/total`.
String privacyProfileShownCount(PrivacySettings s) =>
    _shown(privacyProfileToggles, s);

/// How many of the activity-visibility toggles are on, as `n/total`.
String privacyActivityShownCount(PrivacySettings s) =>
    _shown(privacyActivityToggles, s);

String _shown(List<PrivacyToggle> toggles, PrivacySettings s) =>
    '${privacyOnCount(toggles, s)}/${toggles.length}';
