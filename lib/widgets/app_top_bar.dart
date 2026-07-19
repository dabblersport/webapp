import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Universal top bar used by the four main tabs (Home, Community, Venues,
/// Games): wordmark + app-level location selector on the left; screen-specific
/// [extraActions] on the right. The global search / notifications / profile
/// cluster renders only when [showGlobalActions] is true (Home tab).
///
/// The location row reflects [activeLocationProvider] — the single app-level
/// location selection. Tapping it opens [HomeLocationPickerSheet]; a change
/// there propagates to every screen that watches the provider (nearby feeds,
/// venue/game distance filters, etc.).
class AppTopBar extends ConsumerWidget {
  const AppTopBar({
    super.key,
    this.avatarContext = AvatarContext.main,
    this.avatarUrl,
    this.displayName,
    this.extraActions = const [],
    this.showGlobalActions = false,
  });

  /// Theme context for the avatar ring (main / social / sports…).
  final AvatarContext avatarContext;

  /// Optional overrides for screens that manage their own profile state;
  /// when null the bar reads [profileControllerProvider].
  final String? avatarUrl;
  final String? displayName;

  /// Screen-specific action buttons inserted before the search button
  /// (e.g. the organiser "add venue" button on the Venues tab).
  final List<Widget> extraActions;

  /// Renders the global search / notifications / profile cluster.
  /// Only the Home tab enables this; other tabs show [extraActions] alone.
  final bool showGlobalActions;

  /// Fixed content height so the bar measures the same on every tab —
  /// matches the tallest element (40dp avatar + 2dp ring padding + 2dp
  /// border on each side). Prevents layout jump when switching tabs.
  static const double _contentHeight = 48;

  void _openLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, sc) => HomeLocationPickerSheet(scrollController: sc),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + 12;

    final profile = showGlobalActions
        ? ref.watch(profileControllerProvider).profile
        : null;
    final effectiveAvatarUrl = avatarUrl ?? profile?.avatarUrl;
    final effectiveDisplayName =
        displayName ?? profile?.displayName ?? profile?.username ?? 'User';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 6),
      child: SizedBox(
        height: _contentHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: wordmark + location row
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/dabbler_text_logo.svg',
                    width: 100,
                    height: 18,
                    colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
                  ),
                  const SizedBox(height: 4),
                  _LocationRow(onTap: () => _openLocationPicker(context)),
                ],
              ),
            ),
            // Right: extra actions + search + notifications + avatar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < extraActions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  extraActions[i],
                ],
                if (showGlobalActions) ...[
                  if (extraActions.isNotEmpty) const SizedBox(width: 6),
                  _CircleButton(
                    icon: Iconsax.search_normal_1_copy,
                    onTap: () => context.push(RoutePaths.socialSearch),
                  ),
                  const SizedBox(width: 6),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _CircleButton(
                        icon: Iconsax.notification_copy,
                        onTap: () => context.push(RoutePaths.notifications),
                      ),
                      const Positioned(
                        top: -2,
                        right: -2,
                        child: NotificationBadge(),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.push(RoutePaths.profile),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: DSAvatar.small(
                        imageUrl: effectiveAvatarUrl,
                        displayName: effectiveDisplayName,
                        context: avatarContext,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LOCATION ROW
// =============================================================================

class _LocationRow extends ConsumerWidget {
  const _LocationRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final locState = ref.watch(activeLocationProvider).valueOrNull;
    final locationName = locState is ActiveLocationReady
        ? locState.location.area.name
        : 'Set location';

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.location_copy, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              locationName,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Iconsax.arrow_down_1_copy,
            size: 10,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CIRCLE BUTTON
// =============================================================================

/// 36×36 circular icon button matching the header action style. Public so
/// screens can build [AppTopBar.extraActions] in the same visual language.
class AppTopBarButton extends StatelessWidget {
  const AppTopBarButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _CircleButton(icon: icon, onTap: onTap);
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: cs.primary, size: 18),
      ),
    );
  }
}
