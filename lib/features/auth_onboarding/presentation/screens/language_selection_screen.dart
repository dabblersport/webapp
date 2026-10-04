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
      setState(() {
        _selectedLanguage = currentLanguage;
      });
    } catch (e) {
      // Use default language
      setState(() {
        _selectedLanguage = 'en';
      });
    }
  }

  void _selectLanguage(String languageCode) {
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);

    try {
      final localizationService = MockLocalizationService();
      await localizationService.setLanguage(_selectedLanguage);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(message: 'Error: $e', tone: DabblerToastTone.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DabblerPage(
      maxContentWidth: DabblerPage.readableWidth,
      topBar: DabblerNavigationTopBar.titled(
        border: true,
        title: l10n.language_select_title,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      bottomBar: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
          DabblerSpacing.space10,
        ),
        child: DabblerButton(
          label: _isLoading
              ? l10n.language_select_saving
              : l10n.landing_continue,
          size: DabblerButtonSize.full,
          fullWidth: true,
          loading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space10,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DabblerText(
              'Choose Your Language',
              style: DabblerType.title1,
              textAlign: TextAlign.center,
            ),
            const DabblerGap.v(DabblerSpacing.space2),
            DabblerText(
              'Select your preferred language for the app',
              tone: DabblerTextTone.secondary,
              textAlign: TextAlign.center,
            ),
            const DabblerGap.v(DabblerSpacing.space11),
            for (final language in _languages) ...[
              DabblerInputRow(
                leading: const DabblerIcon('global'),
                title: language['native']!,
                selected: _selectedLanguage == language['code'],
                onTap: () => _selectLanguage(language['code']!),
              ),
              const DabblerGap.v(DabblerSpacing.space3),
            ],
          ],
        ),
      ),
    );
  }
}
