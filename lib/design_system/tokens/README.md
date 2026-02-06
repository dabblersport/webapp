# Design Tokens

This directory contains design token definitions for the Dabbler app theme system.

It includes:

- Source Material 3 JSON theme files (`*-light-theme.json`, `*-dark-theme.json`)
- Generated Dart token files (`*_light.dart`, `*_dark.dart`)

## Structure

### Main Theme
- `main-light-theme.json` - Main light theme color tokens
- `main-dark-theme.json` - Main dark theme color tokens

Generated Dart:

- `main_light.dart`
- `main_dark.dart`

### Category Themes
- `social-light-theme.json` - Social category light theme
- `social-dark-theme.json` - Social category dark theme
- `sports-light-theme.json` - Sports category light theme
- `sports-dark-theme.json` - Sports category dark theme
- `activity-light-theme.json` - Activity category light theme
- `activity-dark-theme.json` - Activity category dark theme
- `profile-light-theme.json` - Profile category light theme
- `profile-dark-theme.json` - Profile category dark theme

Generated Dart:

- `social_light.dart`, `social_dark.dart`
- `sports_light.dart`, `sports_dark.dart`
- `activity_light.dart`, `activity_dark.dart`
- `profile_light.dart`, `profile_dark.dart`

## Token Schema

All theme tokens follow the Material Design 3 color system specification:

### Core Colors
- `primary` / `onPrimary` - Primary brand color and its foreground
- `primaryContainer` / `onPrimaryContainer` - Primary container and its foreground
- `secondary` / `onSecondary` - Secondary accent color and its foreground
- `secondaryContainer` / `onSecondaryContainer` - Secondary container and its foreground
- `tertiary` / `onTertiary` - Tertiary accent color and its foreground
- `tertiaryContainer` / `onTertiaryContainer` - Tertiary container and its foreground

### System Colors
- `error` / `onError` - Error state color and its foreground
- `errorContainer` / `onErrorContainer` - Error container and its foreground

### Surface Colors
- `background` / `onBackground` - Base background and its foreground
- `surface` / `onSurface` - Surface color and its foreground
- `surfaceVariant` / `onSurfaceVariant` - Surface variant and its foreground
- `surfaceDim` - Dimmed surface
- `surfaceBright` - Bright surface
- `surfaceContainerLowest` - Lowest elevation container
- `surfaceContainerLow` - Low elevation container
- `surfaceContainer` - Default container
- `surfaceContainerHigh` - High elevation container
- `surfaceContainerHighest` - Highest elevation container

### Additional Colors
- `outline` - Outline/border color
- `outlineVariant` - Variant outline color
- `surfaceTint` - Tint color for elevated surfaces
- `shadow` - Shadow color
- `scrim` - Scrim/overlay color

### Inverse Colors
- `inverseSurface` / `inverseOnSurface` - Inverse surface and foreground
- `inversePrimary` - Inverse primary color

### Fixed Colors
- `primaryFixed` / `onPrimaryFixed` - Fixed primary colors
- `primaryFixedDim` / `onPrimaryFixedVariant` - Primary fixed variants
- `secondaryFixed` / `onSecondaryFixed` - Fixed secondary colors
- `secondaryFixedDim` / `onSecondaryFixedVariant` - Secondary fixed variants
- `tertiaryFixed` / `onTertiaryFixed` - Fixed tertiary colors
- `tertiaryFixedDim` / `onTertiaryFixedVariant` - Tertiary fixed variants

## Dart Tokens

See `DART_TOKENS.md` for the generated Dart token file rules and shape.
