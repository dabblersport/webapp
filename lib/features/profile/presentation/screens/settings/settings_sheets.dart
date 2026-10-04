import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _kSupportedCountries = [
  'Egypt',
  'United Arab Emirates',
  'Saudi Arabia',
  'Morocco',
];

const _kSupportedLanguages = [
  (code: 'en', label: 'English', native: 'English'),
  (code: 'ar', label: 'Arabic', native: 'العربية'),
];

/// `Settings.dc.html` Language & region page, as a sheet: the language group
/// and the app-country group behind one tile.
void showSettingsLanguageRegionSheet(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final currentCountry = ref.read(selectedCountryProvider).valueOrNull ?? '';
  final langCode = ref.read(localeProvider).languageCode;
  showDabblerSheet<void>(
    context: context,
    title: l10n.settings_tile_language_region,
    detent: DabblerSheetDetent.content,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(
          l10n.settings_item_language_title,
          style: DabblerType.footnote,
          weight: DabblerTextWeight.semibold,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        for (final lang in _kSupportedLanguages)
          _PickerRow(
            label: lang.label,
            sublabel: lang.native,
            selected: langCode == lang.code,
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(Locale(lang.code));
              Navigator.pop(sheetContext);
            },
          ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerText(
          l10n.settings_item_country_title,
          style: DabblerType.footnote,
          weight: DabblerTextWeight.semibold,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        for (final c in _kSupportedCountries)
          _PickerRow(
            label: c,
            selected: currentCountry.toLowerCase() == c.toLowerCase(),
            onTap: () {
              ref.read(selectedCountryProvider.notifier).setCountry(c);
              Navigator.pop(sheetContext);
            },
          ),
      ],
    ),
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space2),
    child: DabblerInputRow(
      title: label,
      subtitle: sublabel,
      onTap: onTap,
      selected: selected,
    ),
  );
}

/// The root's single About row opens the legal pages (`Settings.dc.html`
/// About group), each reached through its existing route.
void showSettingsAboutSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showDabblerSheet<void>(
    context: context,
    title: l10n.settings_about_title,
    detent: DabblerSheetDetent.content,
    builder: (sheetContext) {
      Widget row(String icon, String title, String subtitle, String route) =>
          DabblerInputRow(
            flat: true,
            showDivider: false,
            onTap: () {
              Navigator.pop(sheetContext);
              context.push(route);
            },
            leading: DabblerIcon(icon, size: DabblerSizing.iconMd),
            title: title,
            subtitle: subtitle,
            trailing: const DabblerChevron(circled: true),
          );
      return DabblerRowGroup(
        children: [
          row(
            'document-text',
            l10n.settings_item_terms_title,
            l10n.settings_item_terms_subtitle,
            '/about/terms',
          ),
          row(
            'shield-tick',
            l10n.settings_item_privacy_policy_title,
            l10n.settings_item_privacy_policy_subtitle,
            '/about/privacy',
          ),
          row(
            'code',
            l10n.settings_item_licenses_title,
            l10n.settings_item_licenses_subtitle,
            '/about/licenses',
          ),
        ],
      );
    },
  );
}

/// The Become-an-organiser info sheet (`Settings.dc.html:976-977`).
void showSettingsOrganiserSheet(BuildContext context, VoidCallback onStart) {
  final l10n = AppLocalizations.of(context);
  showDabblerSheet<void>(
    context: context,
    title: l10n.settings_organiser_title,
    detent: DabblerSheetDetent.content,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(
          l10n.settings_organiser_info_body,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerButton(
          label: l10n.settings_organiser_start,
          fullWidth: true,
          onPressed: () {
            Navigator.pop(sheetContext);
            onStart();
          },
        ),
      ],
    ),
  );
}

/// The sign-out confirmation (`Settings.dc.html` `isConfirm` sheet).
void showSettingsSignOutSheet(BuildContext context, VoidCallback onConfirm) {
  final l10n = AppLocalizations.of(context);
  showDabblerSheet<void>(
    context: context,
    title: l10n.settings_sign_out_title,
    detent: DabblerSheetDetent.content,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(
          l10n.settings_sign_out_confirm_body,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerButton(
          label: l10n.settings_sign_out_title,
          tone: DabblerButtonTone.destructive,
          fullWidth: true,
          onPressed: () {
            Navigator.pop(sheetContext);
            onConfirm();
          },
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerButton(
          label: l10n.settings_sign_out_dialog_cancel,
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ],
    ),
  );
}
