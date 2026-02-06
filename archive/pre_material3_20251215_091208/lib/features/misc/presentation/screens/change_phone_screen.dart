import 'package:flutter/material.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/constants.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/widgets/app_button.dart';
import 'package:dabbler/widgets/input_field.dart';

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+971';
  bool _isLoading = false;

  final List<Map<String, String>> _countryCodes = [
    {'code': '+971', 'country': 'UAE', 'flag': '🇦🇪'},
    {'code': '+20', 'country': 'Egypt', 'flag': '🇪🇬'},
    {'code': '+1', 'country': 'US', 'flag': '🇺🇸'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final fullPhoneNumber =
          '$_selectedCountryCode${_phoneController.text.replaceAll(RegExp(r'[^\d]'), '')}';

      final authService = AuthService();
      await authService.signInWithPhone(phone: fullPhoneNumber);

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/otp-verification',
          arguments: {'phoneNumber': fullPhoneNumber},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _buildHeroSection(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: _buildFormSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final heroColor = isDarkMode
        ? const Color(0xFF4A148C)
        : const Color(0xFFE0C7FF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode
        ? Colors.white.withOpacity(0.85)
        : Colors.black.withOpacity(0.7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.phone_android, size: 56, color: textColor),
          const SizedBox(height: 16),
          Text(
            'Update Phone Number',
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your new phone number to receive verification code',
            style: textTheme.bodyLarge?.copyWith(color: subtextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone Input
          Row(
            children: [
              // Country Code Dropdown
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    items: _countryCodes.map((country) {
                      return DropdownMenuItem(
                        value: country['code'],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(country['flag']!),
                              const SizedBox(width: 4),
                              Text(country['code']!),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCountryCode = value);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Phone Number Input
              Expanded(
                child: CustomInputField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hintText: 'Enter your new phone number',
                  keyboardType: TextInputType.phone,
                  validator: AppValidators.validatePhoneNumber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Update Button
          AppButton(
            onPressed: _isLoading ? null : _handleSubmit,
            label: _isLoading ? 'Saving...' : 'Continue',
          ),

          const SizedBox(height: 24),

          // Info Text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? colorScheme.primaryContainer.withOpacity(0.3)
                  : Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? colorScheme.primary.withOpacity(0.5)
                    : Colors.blue[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDarkMode ? colorScheme.primary : Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A verification code will be sent to your new phone number to confirm the change.',
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode
                          ? colorScheme.onPrimaryContainer
                          : Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
