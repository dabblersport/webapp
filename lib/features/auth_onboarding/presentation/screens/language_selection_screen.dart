import 'package:dabbler/core/services/mock_localization_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings/settings_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The countries the app serves, by the name the location provider stores.
const _kCountries = <String>[
  'Egypt',
  'United Arab Emirates',
  'Saudi Arabia',
  'Morocco',
];

/// Language & region — `Settings.dc.html` route `region`: the app language and
/// the app country, each chosen in a sheet and applied at once.
class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    try {
      final localizationService = MockLocalizationService();
      final currentLanguage = await localizationService.getCurrentLanguage();
      if (!mounted) return;
      setState(() {
        _selectedLanguage = currentLanguage;
      });
    } catch (e) {
      // Use default language
      if (!mounted) return;
      setState(() {
        _selectedLanguage = 'en';
      });
    }
  }

  String _languageLabel(AppLocalizations l10n, String code) =>
      code == 'ar' ? l10n.region_lang_ar : l10n.region_lang_en;

  String _countryLabel(AppLocalizations l10n, String name) =>
      switch (name.toLowerCase()) {
        'egypt' => l10n.region_country_Egypt,
        'united arab emirates' => l10n.region_country_UAE,
        'saudi arabia' => l10n.region_country_KSA,
        'morocco' => l10n.region_country_Morocco,
        _ => name,
      };

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  Future<void> _selectLanguage(String languageCode) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _selectedLanguage = languageCode);
    try {
      await MockLocalizationService().setLanguage(languageCode);
      if (!mounted) return;
      _toast(l10n.region_language_updated, DabblerToastTone.success);
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.region_error(e.toString()), DabblerToastTone.error);
    }
  }

  Future<void> _selectCountry(String country) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(selectedCountryProvider.notifier).setCountry(country);
    if (!mounted) return;
    _toast(l10n.region_country_updated, DabblerToastTone.success);
  }

  void _showOptions({
    required String title,
    required List<(String, String)> options,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    showDabblerSheet<void>(
      context: context,
      title: title,
      detent: DabblerSheetDetent.content,
      showCloseButton: false,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: DabblerSpacing.space2,
              ),
              child: DabblerOptionRow(
                label: option.$2,
                selected: option.$1.toLowerCase() == current.toLowerCase(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onSelect(option.$1);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final country = ref.watch(selectedCountryProvider).valueOrNull ?? '';

    return DabblerPage(
      topBar: settingsTopBar(
        context,
        title: l10n.region_title,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: kSettingsBodyPadding,
        children: [
          DabblerRowGroup(
            children: [
              DabblerInputRow(
                flat: true,
                showDivider: false,
                leading: settingsRowIcon(context, 'translate'),
                title: l10n.region_language,
                subtitle: l10n.region_language_sub,
                value: _languageLabel(l10n, _selectedLanguage),
                onTap: () => _showOptions(
                  title: l10n.region_language,
                  options: [
                    ('en', l10n.region_lang_en),
                    ('ar', l10n.region_lang_ar),
                  ],
                  current: _selectedLanguage,
                  onSelect: _selectLanguage,
                ),
              ),
              DabblerInputRow(
                flat: true,
                showDivider: false,
                leading: settingsRowIcon(context, 'global'),
                title: l10n.region_country,
                subtitle: l10n.region_country_sub,
                value: country.isEmpty ? null : _countryLabel(l10n, country),
                trailing: country.isEmpty ? const DabblerChevron() : null,
                onTap: () => _showOptions(
                  title: l10n.region_country,
                  options: [
                    for (final c in _kCountries) (c, _countryLabel(l10n, c)),
                  ],
                  current: country,
                  onSelect: _selectCountry,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
