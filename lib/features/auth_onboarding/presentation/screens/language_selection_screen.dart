import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/services/mock_localization_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = 'en';
  bool _isLoading = false;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
  ];

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
      setState(() => _selectedLanguage = currentLanguage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedLanguage = 'en');
    }
  }

  void _selectLanguage(String languageCode) {
    setState(() => _selectedLanguage = languageCode);
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      final localizationService = MockLocalizationService();
      await localizationService.setLanguage(_selectedLanguage);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(message: 'Error: $e', tone: DabblerToastTone.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l10n.language_select_title,
        onBack: () => Navigator.maybePop(context),
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
        ),
        child: DabblerButton(
          label: _isLoading
              ? l10n.language_select_saving
              : l10n.landing_continue,
          size: DabblerButtonSize.full,
          fullWidth: true,
          loading: _isLoading,
          onPressed: _isLoading ? null : _handleSubmit,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DabblerSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: DabblerSpacing.space8),
            Text(
              'Choose Your Language',
              style: DabblerType.title1
                  .resolveForDirection(dir)
                  .copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DabblerSpacing.space2),
            Text(
              'Select your preferred language for the app',
              style: DabblerType.body
                  .resolveForDirection(dir)
                  .copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DabblerSpacing.space11),
            for (final language in _languages)
              Padding(
                padding: const EdgeInsets.only(bottom: DabblerSpacing.space3),
                child: DabblerInputRow(
                  onTap: () => _selectLanguage(language['code']!),
                  title: language['native'],
                  trailing: _selectedLanguage == language['code']
                      ? DabblerIcon(
                          'tick-circle',
                          weight: DabblerIconWeight.bold,
                          size: DabblerSizing.iconMd,
                          color: colors.brandPrimary,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
