import 'package:flutter/material.dart';
import 'package:dabbler/core/services/mock_localization_service.dart';
import 'package:dabbler/core/utils/constants.dart';
import 'package:dabbler/widgets/app_button.dart';

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
    {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية', 'flag': '🇪🇬'},
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Language'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Header
              Text(
                'Choose Your Language',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Select your preferred language for the app',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Language Options
              ..._languages.map((language) {
                final isSelected = _selectedLanguage == language['code'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _selectLanguage(language['code']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.07)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.3)
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            language['flag']!,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  language['native']!,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                ),
                                if (language['code'] != 'en') ...[
                                  const SizedBox(height: 2),
                                  // Text(
                                  //   language['name']!,
                                  //   style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  //         color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  //       ),
                                  // ),
                                ],
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    key: ValueKey(language['code']),
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : const SizedBox(width: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const Spacer(),

              // Continue Button
              AppButton(
                onPressed: _isLoading ? null : _handleSubmit,
                label: _isLoading ? 'Saving...' : 'Continue',
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
