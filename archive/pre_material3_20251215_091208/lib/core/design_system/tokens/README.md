# Design Tokens System

This directory contains the design tokens extracted from `tokens.json` that define the visual language for all 10 theme modes in the Dabbler app.

## Overview

The token system provides a consistent, maintainable way to manage colors, typography, spacing, and other design properties across all theme variants.

## Architecture

### 1. **Design Tokens** (`design_tokens.dart`)
Core design tokens shared across all themes:

- **Typography**: Font families, sizes (9px-30px), and weights (300-700)
- **Spacing**: Standardized spacing scale (0-54px)
- **Opacity**: Standard opacity values (0%, 25%, 50%, 75%, 100%)
- **Common Colors**: Success, warning, error colors for light & dark modes

### 2. **Theme Color Tokens**
Each theme mode has its own color palette:

```dart
ThemeColorTokens {
  Color header;          // Top section background
  Color section;         // Section background with transparency
  Color button;          // Primary button color
  Color btnBase;         // Button base/background
  Color tabActive;       // Active tab indicator
  Color app;             // App background
  Color base;            // Base/surface color
  Color card;            // Card background
  Color stroke;          // Border/stroke color
  Color titleOnSec;      // Title on section
  Color titleOnHead;     // Title on header
  Color neutral;         // Primary text (92% opacity)
  Color neutralOpacity;  // Secondary text (72% opacity)
  Color neutralDisabled; // Disabled text (24% opacity)
  Color onBtn;           // Text on buttons
  Color onBtnIcon;       // Icons on buttons
}
```

### 3. **10 Theme Modes**

#### Light Themes
- **Main Light**: Purple theme (`#7328CE`) - Primary app theme
- **Social Light**: Blue theme (`#3473D7`) - Social features
- **Sports Light**: Green theme (`#348638`) - Sports/games
- **Activities Light**: Pink theme (`#D72078`) - Activities/events
- **Profile Light**: Orange theme (`#F59E0B`) - User profiles

#### Dark Themes
- **Main Dark**: Deep purple (`#C18FFF`) with dark backgrounds
- **Social Dark**: Sky blue (`#A6DCFF`) with dark backgrounds
- **Sports Dark**: Mint green (`#7FD89B`) with dark backgrounds
- **Activities Dark**: Light pink (`#FFA8D5`) with dark backgrounds
- **Profile Dark**: Amber (`#FFCE7A`) with dark backgrounds

## Usage

### Basic Theme Application

```dart
import 'package:dabbler/core/design_system/design_system.dart';

// Build a specific theme
final theme = TokenBasedTheme.build(AppThemeMode.mainLight);

// Apply to MaterialApp
MaterialApp(
  theme: theme,
  // ...
)
```

### Switching Themes

```dart
// In a StatefulWidget
AppThemeMode _currentTheme = AppThemeMode.mainLight;

void switchToSportsTheme() {
  setState(() {
    _currentTheme = AppThemeMode.sportsLight;
  });
}

@override
Widget build(BuildContext context) {
  return Theme(
    data: TokenBasedTheme.build(_currentTheme),
    child: YourWidget(),
  );
}
```

### Accessing Theme Properties

```dart
// Get current theme colors
final colorScheme = Theme.of(context).colorScheme;

// Use semantic colors
Container(
  color: colorScheme.primary,
  child: Text(
    'Hello',
    style: Theme.of(context).textTheme.titleLarge,
  ),
)

// Access token-based colors directly
final tokens = AppThemeMode.mainLight.colorTokens;
Color buttonColor = tokens.button;
```

### Using Design Tokens

```dart
// Typography
Text(
  'Title',
  style: TextStyle(
    fontSize: DesignTokens.fontSizeBase,
    fontWeight: DesignTokens.fontWeightBold,
  ),
)

// Spacing
Padding(
  padding: EdgeInsets.all(DesignTokens.spacingSm),
  child: child,
)

// Opacity
Container(
  color: Colors.blue.withOpacity(DesignTokens.opacity50),
)
```

## Token Structure

### Typography Scale
```
2xs:  9px  - Tiny labels
xs:   12px - Small labels, captions
sm:   15px - Body text, buttons
base: 17px - Default body, titles
lg:   19px - Large titles
xl:   21px - Extra large titles
2xl:  24px - Display text
ex:   24px - Extra display
ex2:  30px - Largest display
```

### Spacing Scale (4px base grid)
```
xxs:  3px  - Minimal spacing
xs:   6px  - Tight spacing
sm:   12px - Comfortable spacing
md:   18px - Standard spacing
lg:   24px - Large spacing
xl:   30px - Extra large
2xl:  36px - 2x large
3xl:  42px - 3x large
4xl:  48px - 4x large
5xl:  54px - Maximum
```

### Color Opacity Standards
```
100%: Primary content (neutral)
92%:  Secondary content (neutralOpacity)
72%:  Tertiary content
24%:  Disabled state (neutralDisabled)
18%:  Borders, dividers
6%:   Subtle backgrounds
```

## Theme Category System

Each theme mode belongs to a category:

```dart
AppThemeMode.mainLight.category    // "main"
AppThemeMode.socialDark.category   // "social"
AppThemeMode.sportsLight.category  // "sports"
```

Use categories to dynamically switch themes based on app context (e.g., switching to sports theme when viewing sports content).

## Material 3 Integration

The token system generates Material 3 `ColorScheme` objects:

```dart
ColorScheme {
  primary: tokens.button,
  onPrimary: tokens.onBtn,
  primaryContainer: tokens.btnBase,
  secondary: tokens.tabActive,
  tertiary: tokens.header,
  surface: tokens.base,
  surfaceContainer: tokens.card,
  // ... full M3 color mapping
}
```

This ensures compatibility with all Material 3 components while maintaining design token consistency.

## Demo

See `theme_showcase_screen.dart` for a live demonstration of all 10 theme modes with:
- Color token swatches
- Typography samples
- Button variants
- Component examples
- Spacing reference

## Best Practices

1. **Always use tokens** instead of hardcoded values
2. **Use semantic names** from ColorScheme rather than raw colors
3. **Theme per category** - Use appropriate theme for each section
4. **Maintain consistency** - Follow the spacing scale strictly
5. **Accessibility** - All tokens meet WCAG contrast requirements

## Migration from Legacy Colors

Old (`AppColors`):
```dart
color: AppColors.primaryPurple
```

New (Token-based):
```dart
color: Theme.of(context).colorScheme.primary
// or
color: AppThemeMode.mainLight.colorTokens.button
```

## Files

- `design_tokens.dart` - Core tokens (typography, spacing, common colors)
- `token_based_theme.dart` - Theme builder and AppThemeMode enum
- `theme_showcase_screen.dart` - Visual demonstration of all themes

## Token Source

All tokens are extracted from `design-system/tokens.json` and represent the source of truth for the design system. Any design changes should be made in the tokens.json file first, then propagated here.
