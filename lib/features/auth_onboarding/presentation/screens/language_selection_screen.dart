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
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);

    return DabblerPage(
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
            const SizedBox(height: DabblerSpacing.space2),
            DabblerText(
              'Select your preferred language for the app',
              tone: DabblerTextTone.secondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DabblerSpacing.space11),
            ..._languages.map((language) {
              final isSelected = _selectedLanguage == language['code'];
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: DabblerSpacing.space3,
                ),
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectLanguage(language['code']!),
                    child: DabblerSurface(
                      variant: isSelected
                          ? DabblerSurfaceVariant.selected
                          : DabblerSurfaceVariant.card,
                      radius: DabblerRadius.lg,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: DabblerSpacing.space4,
                        vertical: DabblerSpacing.space4,
                      ),
                      child: Row(
                        children: [
                          DabblerIcon(
                            'global',
                            size: DabblerSizing.iconRow,
                            color: isSelected
                                ? colors.onBrand
                                : colors.textSecondary,
                          ),
                          const SizedBox(width: DabblerSpacing.space4),
                          Expanded(
                            child: DabblerText(
                              language['native']!,
                              tone: isSelected
                                  ? DabblerTextTone.onBrand
                                  : DabblerTextTone.primary,
                            ),
                          ),
                          if (isSelected)
                            DabblerIcon(
                              'tick-circle',
                              weight: DabblerIconWeight.bold,
                              size: DabblerSizing.iconRow,
                              color: colors.onBrand,
                            )
                          else
                            const SizedBox(width: DabblerSizing.iconRow),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
