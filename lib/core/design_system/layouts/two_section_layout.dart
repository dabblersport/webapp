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

  /// Optional scroll controller for the root scroll view
  final ScrollController? scrollController;

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
    this.scrollController,
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

    Widget buildContent(ColorScheme scheme) {
      final background = bottomBackgroundColor ?? scheme.primaryContainer;

      return Container(
        padding: const EdgeInsets.all(4),
        clipBehavior: Clip.none,
        decoration: ShapeDecoration(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(deviceRadius > 0 ? 52 : 0),
          ),
        ),
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ========== TOP SECTION ==========
            SliverToBoxAdapter(
              child: Container(
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
                  color: topBackgroundColor ?? scheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      deviceRadius > 0 ? 52 : 0,
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
            ),

            // 4px gap
            const SliverToBoxAdapter(child: SizedBox(height: 4)),

            // ========== BOTTOM SECTION ==========
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.none,
                decoration: ShapeDecoration(
                  color: bottomBackgroundColor ?? scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: Radius.circular(deviceRadius > 0 ? 50 : 0),
                      bottomRight: Radius.circular(deviceRadius > 0 ? 50 : 0),
                    ),
                  ),
                ),
                padding:
                    bottomPadding ??
                    const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                child: IconTheme.merge(
                  data: IconThemeData(color: scheme.onSurface),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: scheme.onSurface),
                    child: bottomSection,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildScaffold(ColorScheme scheme) {
      final content = buildContent(scheme);

      return Scaffold(
        backgroundColor: bottomBackgroundColor ?? scheme.primaryContainer,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        extendBody: true,
        body: onRefresh != null
            ? RefreshIndicator(onRefresh: onRefresh!, child: content)
            : content,
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
