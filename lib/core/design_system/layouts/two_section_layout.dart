import 'package:dabbler/utils/ui_constants.dart';
import 'package:flutter/material.dart';
import 'package:dabbler/themes/app_theme.dart';

/// Standard two-section layout for all screens using Material Design 3
/// Top section: Category-colored background with rounded bottom corners
/// Bottom section: Surface color with content
class TwoSectionLayout extends StatelessWidget {
  /// Content for the top section
  final Widget topSection;

  /// Content for the bottom section
  final Widget bottomSection;

  /// Optional padding for top section (default: 24px)
  final EdgeInsets? topPadding;

  /// Optional padding for bottom section (default: 24px)
  final EdgeInsets? bottomPadding;

  /// Custom top section background color (overrides category color)
  final Color? topBackgroundColor;

  /// Custom bottom section background color (overrides surface color)
  final Color? bottomBackgroundColor;

  /// Category for top section color ('main', 'social', 'sports', 'activities', 'profile')
  final String? category;

  /// Optional floating action button
  final Widget? floatingActionButton;

  /// Optional floating action button location
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Optional pull-to-refresh callback
  final Future<void> Function()? onRefresh;

  const TwoSectionLayout({
    super.key,
    required this.topSection,
    required this.bottomSection,
    this.topPadding,
    this.bottomPadding,
    this.topBackgroundColor,
    this.bottomBackgroundColor,
    this.category,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final currentScheme = Theme.of(context).colorScheme;

    // Get device corner radius dynamically based on safe area insets
    final topInset = MediaQuery.of(context).padding.top;
    // Approximate device corner radius based on top safe area
    // iPhone models with notch/Dynamic Island have ~39-47px radius
    final deviceRadius = topInset > 20 ? 50.0 : 0.0;

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomNavHeight = MediaQuery.of(context).padding.bottom + 80;

    Widget buildContent(ColorScheme scheme) {
      final background = bottomBackgroundColor ?? scheme.secondaryContainer;

      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (screenHeight - bottomNavHeight)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: Container(
                padding: const EdgeInsets.all(0),
                clipBehavior: Clip.none,
                decoration: ShapeDecoration(
                  // Native M3 outer surface background.
                  color: background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      deviceRadius > 0 ? 52 : 0,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ========== TOP SECTION ==========
                    Container(
                      width: double.infinity,
                      padding:
                          topPadding ??
                          const EdgeInsets.only(
                            top: 48,
                            left: 0,
                            right: 0,
                            bottom: 18,
                          ),
                      clipBehavior: Clip.none,
                      decoration: ShapeDecoration(
                        // Default to primaryContainer (JSON token source-of-truth).
                        color: topBackgroundColor ?? scheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(deviceRadius > 0 ? 50 : 0),
                            topRight: Radius.circular(
                              deviceRadius > 0 ? 50 : 0,
                            ),
                            bottomLeft: const Radius.circular(24),
                            bottomRight: const Radius.circular(24),
                          ),
                        ),
                      ),
                      child: IconTheme.merge(
                        data: IconThemeData(color: scheme.onPrimaryContainer),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(color: scheme.onPrimaryContainer),
                          child: topSection,
                        ),
                      ),
                    ),

                    // 4px gap between sections
                    const SizedBox(height: 4),

                    // ========== BOTTOM SECTION ==========
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (screenHeight - bottomNavHeight - 300)
                            .clamp(0.0, double.infinity)
                            .toDouble(),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          12,
                          AppSpacing.lg,
                          78,
                        ),

                        clipBehavior: Clip.none,
                        decoration: ShapeDecoration(
                          // Default to secondaryContainer (JSON token source-of-truth).
                          color:
                              bottomBackgroundColor ??
                              scheme.secondaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(24),
                              topRight: const Radius.circular(24),
                              bottomLeft: Radius.circular(
                                deviceRadius > 0 ? 50 : 0,
                              ),
                              bottomRight: Radius.circular(
                                deviceRadius > 0 ? 50 : 0,
                              ),
                            ),
                          ),
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(
                            color: scheme.onSecondaryContainer,
                          ),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                            ),
                            child: bottomSection,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    Widget buildScaffold(ColorScheme scheme) {
      final scrollView = buildContent(scheme);

      return Scaffold(
        // Match the screen background to the active scheme (category-aware).
        backgroundColor: bottomBackgroundColor ?? scheme.secondaryContainer,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        extendBody: true,
        body: onRefresh != null
            ? RefreshIndicator(onRefresh: onRefresh!, child: scrollView)
            : scrollView,
      );
    }

    if (category == null) {
      return buildScaffold(currentScheme);
    }

    final resolvedCategory = category!;
    final scheme =
        AppTheme.tryGetCachedColorScheme(resolvedCategory, brightness) ??
        context.getCategoryTheme(resolvedCategory);
    return buildScaffold(scheme);
  }
}
