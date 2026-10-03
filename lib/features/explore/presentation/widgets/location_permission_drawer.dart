import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The drawer asking for location permission, with three options:
/// 1. Allow location - Request device native location permission
/// 2. Remind me later - Close and ask again next time
/// 3. No thanks - Close and never ask again
///
/// Hosted in a design-system sheet (which owns the surface, handle and the
/// 18dp gutter); this widget is the sheet's content.
class LocationPermissionDrawer extends StatelessWidget {
  const LocationPermissionDrawer({
    super.key,
    required this.onAllowLocation,
    required this.onRemindLater,
    required this.onNoThanks,
  });

  final VoidCallback onAllowLocation;
  final VoidCallback onRemindLater;
  final VoidCallback onNoThanks;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const DabblerIconTile.named('location', size: 56),
        const SizedBox(height: DabblerSpacing.space6),
        Text(
          'Enable Location',
          style: listingText(
            context,
            DabblerType.headline,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Text(
          'Find sports venues and games near you. We\'ll show you activities happening in your area.',
          style: listingText(
            context,
            DabblerType.body,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: DabblerSpacing.space10),
        DabblerButton(
          label: 'Allow Location',
          icon: 'gps',
          fullWidth: true,
          onPressed: onAllowLocation,
        ),
        const SizedBox(height: DabblerSpacing.space4),
        DabblerButton(
          label: 'Remind Me Later',
          icon: 'clock',
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          onPressed: onRemindLater,
        ),
        const SizedBox(height: DabblerSpacing.space4),
        DabblerButton(
          label: 'No Thanks',
          tone: DabblerButtonTone.neutral,
          fullWidth: true,
          onPressed: onNoThanks,
        ),
      ],
    );
  }
}
