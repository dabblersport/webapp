// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ActivitySecurityFooter extends StatelessWidget {
  const ActivitySecurityFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    const green = DesignTokens.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: green.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Iconsax.security_copy, size: 18, color: green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).activity_all_normal_title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                      children: [
                        TextSpan(
                          text: AppLocalizations.of(context).activity_all_normal_body,
                        ),
                        TextSpan(
                          text: AppLocalizations.of(context).activity_manage_devices,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
