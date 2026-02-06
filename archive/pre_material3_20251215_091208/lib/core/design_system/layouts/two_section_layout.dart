import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:dabbler/themes/material3_extensions.dart';

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

  /// Get bottom section color based on category
  Color _getBottomSectionColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    switch (category?.toLowerCase()) {
      case 'main':
        return isDark
            ? const Color(0xFF4A148C).withValues(alpha: 0.32)
            : const Color(0xFFE0C7FF).withValues(alpha: 0.18);
      case 'profile':
        return isDark
            ? const Color(0xFFEC8F1E).withValues(alpha: 0.32)
            : const Color(0xFFFCF8EA).withValues(alpha: 0.18);
      case 'sports':
        return isDark
            ? colorScheme.categorySports.withValues(alpha: 0.32)
            : colorScheme.categorySports.withValues(alpha: 0.18);
      case 'social':
        return isDark
            ? colorScheme.categorySocial.withValues(alpha: 0.32)
            : colorScheme.categorySocial.withValues(alpha: 0.18);
      case 'activities':
        return isDark
            ? colorScheme.categoryActivities.withValues(alpha: 0.32)
            : colorScheme.categoryActivities.withValues(alpha: 0.18);
      default:
        // Default to main category colors
        return isDark
            ? const Color(0xFF4A148C).withValues(alpha: 0.32)
            : const Color(0xFFE0C7FF).withValues(alpha: 0.18);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get color tokens for current theme/category
    final tokens = category != null
        ? context.getCategoryColorTokens(category!)
        : context.colorTokens;

    // Get device corner radius dynamically based on safe area insets
    final topInset = MediaQuery.of(context).padding.top;
    // Approximate device corner radius based on top safe area
    // iPhone models with notch/Dynamic Island have ~39-47px radius
    final deviceRadius = topInset > 20 ? 50.0 : 0.0;

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomNavHeight = MediaQuery.of(context).padding.bottom + 80;

    final scrollView = LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - bottomNavHeight,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: tokens.app, // Use token for app background
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
                  // ========== TOP SECTION - Header from tokens.json ==========
                  Container(
                    width: double.infinity,
                    padding:
                        topPadding ??
                        const EdgeInsets.only(
                          top: 48,
                          left: 24,
                          right: 24,
                          bottom: 12,
                        ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      // Use token header color (top section background)
                      color: topBackgroundColor ?? tokens.header,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(deviceRadius > 0 ? 50 : 0),
                          topRight: Radius.circular(deviceRadius > 0 ? 50 : 0),
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: topSection,
                  ),

                  // 4px gap between sections
                  const SizedBox(height: 4),

                  // ========== BOTTOM SECTION - Section from tokens.json ==========
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight - bottomNavHeight - 300,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding:
                          bottomPadding ??
                          const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 24,
                          ),
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        // Use category-specific colors with opacity
                        color:
                            bottomBackgroundColor ??
                            _getBottomSectionColor(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                            bottomLeft: Radius.circular(
                              deviceRadius > 0 ? 50 : 0,
                            ),
                            bottomRight: Radius.circular(
                              deviceRadius > 0 ? 50 : 0,
                            ),
                          ),
                        ),
                      ),
                      child: bottomSection,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Scaffold(
      // Use token app color for background
      backgroundColor: tokens.app,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      extendBody: true,
      body: onRefresh != null
          ? RefreshIndicator(onRefresh: onRefresh!, child: scrollView)
          : scrollView,
    );
  }
}
