import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';

/// Border radius variant for upcoming game card
enum BorderRadiusVariant {
  /// All corners rounded (12px)
  all,

  /// Only top corners rounded (12px)
  topOnly,

  /// Only bottom corners rounded (12px)
  bottomOnly,
}

/// Card view state - expanded or collapsed
enum CardViewState {
  /// Expanded view with full details (date, time, location)
  expanded,

  /// Collapsed view with minimal info (sport + game name + time)
  collapsed,
}

/// Upcoming game card component matching Figma design
/// Displays game information with countdown timer
/// Supports expanded and collapsed views
class UpcomingGameCard extends StatelessWidget {
  /// Card title (e.g., "Upcoming Game")
  final String title;

  /// Game name (e.g., "Football Game")
  final String gameName;

  /// Time remaining text (e.g., "0h 45m")
  final String timeRemaining;

  /// Sport icon widget from design system (e.g., AppSportIcon.size18())
  final Widget sportIcon;

  /// Date and time string for expanded view (e.g., "Mon, Dec 1 - 6:00 PM - 8:00 PM")
  final String? dateTime;

  /// Location string for expanded view (e.g., "Downtown Sports Center")
  final String? location;

  /// Border radius variant
  final BorderRadiusVariant borderRadiusVariant;

  /// View state - expanded or collapsed
  final CardViewState viewState;

  /// Optional width (defaults to 353px from Figma)
  final double? width;

  const UpcomingGameCard({
    super.key,
    required this.title,
    required this.timeRemaining,
    required this.gameName,
    required this.sportIcon,
    this.dateTime,
    this.location,
    this.borderRadiusVariant = BorderRadiusVariant.all,
    this.viewState = CardViewState.collapsed,
    this.width,
  });

  /// Factory: Collapsed view
  factory UpcomingGameCard.collapsed({
    Key? key,
    required String title,
    required String gameName,
    required String timeRemaining,
    required Widget sportIcon,
    BorderRadiusVariant borderRadiusVariant = BorderRadiusVariant.all,
    double? width,
  }) {
    return UpcomingGameCard(
      key: key,
      title: title,
      gameName: gameName,
      timeRemaining: timeRemaining,
      sportIcon: sportIcon,
      borderRadiusVariant: borderRadiusVariant,
      viewState: CardViewState.collapsed,
      width: width,
    );
  }

  /// Factory: Expanded view with full details
  factory UpcomingGameCard.expanded({
    Key? key,
    required String title,
    required String gameName,
    required String timeRemaining,
    required Widget sportIcon,
    required String dateTime,
    required String location,
    BorderRadiusVariant borderRadiusVariant = BorderRadiusVariant.all,
    double? width,
  }) {
    return UpcomingGameCard(
      key: key,
      title: title,
      gameName: gameName,
      timeRemaining: timeRemaining,
      sportIcon: sportIcon,
      dateTime: dateTime,
      location: location,
      borderRadiusVariant: borderRadiusVariant,
      viewState: CardViewState.expanded,
      width: width,
    );
  }

  BorderRadius _getBorderRadius() {
    const radius = Radius.circular(12);
    const noRadius = Radius.zero;

    switch (borderRadiusVariant) {
      case BorderRadiusVariant.all:
        return const BorderRadius.all(radius);
      case BorderRadiusVariant.topOnly:
        return const BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: radius,
          bottomRight: radius,
        );
      case BorderRadiusVariant.bottomOnly:
        return const BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: radius,
          bottomRight: radius,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.colorTokens;

    return Container(
      width: width ?? 353,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.stroke, width: 1),
        borderRadius: _getBorderRadius(),
      ),
      child: viewState == CardViewState.expanded
          ? _buildExpandedView(context, tokens)
          : _buildCollapsedView(context, tokens),
    );
  }

  Widget _buildCollapsedView(BuildContext context, ThemeColorTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Sport icon + game name
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sport icon from design system
              sportIcon,
              const SizedBox(width: 6),

              // Game name
              Flexible(
                child: Text(
                  gameName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.172,
                    color: tokens.titleOnSec,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Right: Time chip + arrow down icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeChip(context, tokens),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, size: 18, color: tokens.titleOnSec),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedView(BuildContext context, ThemeColorTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title row with time chip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.172,
                color: tokens.titleOnSec,
              ),
            ),
            _buildTimeChip(context, tokens),
          ],
        ),

        const SizedBox(height: 12),

        // Sport icon + game name
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sport icon from design system
            sportIcon,
            const SizedBox(width: 6),

            // Game name
            Flexible(
              child: Text(
                gameName,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: tokens.titleOnSec,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Date/Time row
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: tokens.titleOnSec,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                dateTime ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: tokens.titleOnSec,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Location row
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 18,
              color: tokens.titleOnSec,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                location ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: tokens.titleOnSec,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeChip(BuildContext context, ThemeColorTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.btnBase, // 6% opacity purple
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer icon
          Icon(Icons.timer_outlined, size: 18, color: tokens.titleOnSec),
          const SizedBox(width: 3),

          // Time text
          Text(
            timeRemaining,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.172,
              color: tokens.titleOnSec,
            ),
          ),
        ],
      ),
    );
  }
}
