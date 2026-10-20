import 'package:dabbler_design_system/dabbler_design_system.dart' show DabblerTheme;

/// The app's colour-theme categories and how each maps onto a design-system
/// [DabblerTheme]. Pure data: no widgets, no colours.
abstract final class ThemeCategories {
  static const String defaultCategory = 'main';

  static const List<String> supported = <String>[
    'main',
    'social',
    'sports',
    'activity',
    'profile',
  ];

  /// Lower-cases [category] and folds `activities` into `activity`; anything
  /// unknown becomes [defaultCategory].
  static String normalize(String category) {
    switch (category.toLowerCase()) {
      case 'activity':
      case 'activities':
        return 'activity';
      case 'main':
      case 'social':
      case 'sports':
      case 'profile':
        return category.toLowerCase();
      default:
        return defaultCategory;
    }
  }

  /// The design-system theme for [category]: main→main, social→social,
  /// sports→sport, activity→active, profile→main.
  static DabblerTheme dabblerThemeFor(String category) =>
      switch (normalize(category)) {
        'social' => DabblerTheme.social,
        'sports' => DabblerTheme.sport,
        'activity' => DabblerTheme.active,
        _ => DabblerTheme.main,
      };
}
