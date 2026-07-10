import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/services/eula_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/app_button.dart';

/// Mandatory Terms of Use (EULA) / Privacy Policy acceptance gate.
///
/// Per App Store Guideline 1.2, the user must view and explicitly accept
/// the Terms of Use before they can register or log in. This screen is
/// shown before any auth entry point (see `_handleRedirect` in
/// app_router.dart) and cannot be dismissed without accepting.
class EulaGateScreen extends StatefulWidget {
  const EulaGateScreen({super.key});

  @override
  State<EulaGateScreen> createState() => _EulaGateScreenState();
}

class _EulaGateScreenState extends State<EulaGateScreen> {
  bool _agreed = false;
  bool _isSubmitting = false;

  Future<void> _continue() async {
    if (!_agreed || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    await EulaService.accept();

    if (!mounted) return;
    // Acceptance is now recorded; let the router redirect forward to the
    // normal landing/auth flow.
    context.go(RoutePaths.landing);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      // No back button — this gate has nothing to go back to and must be
      // resolved (accepted) before the app can be used.
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Terms of Use')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gavel_outlined, size: 48, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Before you continue',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Please review and agree to our Terms of Use and Privacy '
                'Policy before creating an account or signing in. These '
                'explain how Dabbler works, how user content is moderated, '
                'and how your data is handled.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _LegalLinkTile(
                label: 'Read Terms of Use',
                onTap: () => context.push(RoutePaths.aboutTerms),
              ),
              const SizedBox(height: 8),
              _LegalLinkTile(
                label: 'Read Privacy Policy',
                onTap: () => context.push(RoutePaths.aboutPrivacy),
              ),
              const Spacer(),
              InkWell(
                onTap: _isSubmitting
                    ? null
                    : () => setState(() => _agreed = !_agreed),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: _isSubmitting
                            ? null
                            : (v) => setState(() => _agreed = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'I have read and agree to the Terms of Use and '
                            'Privacy Policy.',
                            style: tt.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppButton.primary(
                label: 'Agree & Continue',
                fullWidth: true,
                isLoading: _isSubmitting,
                onPressed: _agreed ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalLinkTile extends StatelessWidget {
  const _LegalLinkTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
