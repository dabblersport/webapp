import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_presets.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_settings_screen.dart'
    show privacyActivityShownCount, privacyProfileShownCount;
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/core/services/theme_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The short form of an app country shown on the Language & region tile.
String settingsCountryShort(AppLocalizations l10n, String country) {
  switch (country.toLowerCase()) {
    case 'egypt':
      return l10n.settings_country_short_eg;
    case 'united arab emirates':
      return l10n.settings_country_short_ae;
    case 'saudi arabia':
      return l10n.settings_country_short_sa;
    case 'morocco':
      return l10n.settings_country_short_ma;
  }
  return country;
}

String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.light => l10n.settings_theme_light,
  ThemeMode.dark => l10n.settings_theme_dark,
  ThemeMode.system => l10n.settings_theme_system,
};

String _presetLabel(AppLocalizations l10n, PrivacyPreset preset) =>
    switch (preset) {
      PrivacyPreset.public => l10n.settings_preset_public,
      PrivacyPreset.friendsOnly => l10n.settings_preset_friends,
      PrivacyPreset.private => l10n.settings_preset_private,
      PrivacyPreset.custom => l10n.priv_preset_custom,
    };

/// The Settings root's tile grid (`Settings.dc.html:144-154`), fed by the
/// privacy, notification, block, theme and country providers.
class SettingsTiles extends ConsumerWidget {
  const SettingsTiles({super.key, required this.onLanguageRegion});

  /// Opens the Language & region sheet.
  final VoidCallback onLanguageRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(blockedUsersWithProfilesProvider);
    final privacy = ref.watch(privacyControllerProvider).settings;
    final notif = ref.watch(notificationSettingsControllerProvider).settings;
    final country = ref.watch(selectedCountryProvider).valueOrNull ?? '';
    final notifOn = notif == null
        ? null
        : '${[notif.pushEnabled, notif.emailEnabled].where((e) => e).length}/2';
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) => DabblerStatGrid(
        rowExtent: DabblerStatGrid.detailsRowHeight,
        children: [
          if (privacy != null)
            DabblerStatTile(
              size: DabblerStatTileSize.setting,
              span: 3,
              tone: DabblerStatTileTone.brand,
              icon: const DabblerIcon('shield-tick'),
              value: _presetLabel(l10n, detectPrivacyPreset(privacy)),
              label: l10n.settings_tile_privacy_preset,
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
            value: _themeLabel(l10n, ThemeService().themeMode),
            label: l10n.settings_tile_appearance,
            fitValue: true,
            onTap: () => context.push('/settings/theme'),
          ),
          DabblerStatTile(
            size: DabblerStatTileSize.setting,
            span: 2,
            tone: DabblerStatTileTone.sunken,
            icon: const DabblerIcon('global'),
            value: country.isEmpty ? '-' : settingsCountryShort(l10n, country),
            label: l10n.settings_tile_language_region,
            fitValue: true,
            onTap: onLanguageRegion,
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
      ),
    );
  }
}
