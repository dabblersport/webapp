# Material 3 Migration Guide

This guide provides patterns and examples for migrating screens and components to Material Design 3.

## Overview

The app has been updated to use Material 3 design tokens throughout. This guide shows how to migrate existing screens and components to Material 3 patterns.

## Completed Foundation Work

### Phase 1: Theme Enhancement ✅
- Enhanced Material 3 theme with comprehensive tokens
- Created Material 3 extensions for category colors
- Added app-specific theme extensions (success, warning, info)
- Updated ThemeService to use Material 3 properly

### Phase 2: Component Standardization ✅
- Updated `AppButton` to use Material 3 buttons (FilledButton, OutlinedButton, TextButton)
- Updated `CustomInputField` to use Material 3 TextField with theme styling
- Updated `AppCard` to use Material 3 Card with proper tokens
- Updated `ThoughtsInput` to remove hardcoded colors

### Phase 3: Screen Migration (In Progress)
- ✅ `phone_input_screen.dart` - Fully migrated to Material 3
- ⏳ Remaining 61+ screens need migration

## Migration Patterns

### 1. Colors

**Before (Old Pattern):**
```dart
color: AppColors.primaryPurple
color: AppColors.cardColor(context)
color: AppColors.borderDark
```

**After (Material 3):**
```dart
color: Theme.of(context).colorScheme.primary
color: Theme.of(context).colorScheme.surfaceContainer
color: Theme.of(context).colorScheme.outline
```

**Category Colors:**
```dart
// Old
color: AppColors.categoryBgMain(context)

// New
color: Theme.of(context).colorScheme.categoryMain
// or
color: Theme.of(context).colorScheme.getCategoryColor('main')
```

**App-Specific Colors (Success, Warning, Error):**
```dart
// Success
color: Theme.of(context).extension<AppThemeExtension>()?.success
// or use the extension helper
color: context.successColor

// Warning
color: context.warningColor

// Error (use ColorScheme.error)
color: Theme.of(context).colorScheme.error
// or
color: context.dangerColor
```

### 2. Typography

**Before:**
```dart
Text(
  'Title',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  ),
)
```

**After (Material 3):**
```dart
final textTheme = Theme.of(context).textTheme;

Text(
  'Title',
  style: textTheme.headlineSmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  ),
)
```

**Material 3 Text Styles:**
- `textTheme.displayLarge` - 57sp, weight 400
- `textTheme.displayMedium` - 45sp, weight 400
- `textTheme.displaySmall` - 36sp, weight 400
- `textTheme.headlineLarge` - 32sp, weight 400
- `textTheme.headlineMedium` - 28sp, weight 400
- `textTheme.headlineSmall` - 24sp, weight 400
- `textTheme.titleLarge` - 22sp, weight 400
- `textTheme.titleMedium` - 16sp, weight 500
- `textTheme.titleSmall` - 14sp, weight 500
- `textTheme.bodyLarge` - 16sp, weight 400
- `textTheme.bodyMedium` - 14sp, weight 400
- `textTheme.bodySmall` - 12sp, weight 400
- `textTheme.labelLarge` - 14sp, weight 500
- `textTheme.labelMedium` - 12sp, weight 500
- `textTheme.labelSmall` - 11sp, weight 500

### 3. Buttons

**Before:**
```dart
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryPurple,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  child: Text('Button'),
)
```

**After (Material 3):**
```dart
// Primary action - use FilledButton
FilledButton(
  onPressed: () {},
  child: Text('Button'),
)

// Secondary action - use FilledButton.tonal
FilledButton.tonal(
  onPressed: () {},
  child: Text('Button'),
)

// Tertiary action - use OutlinedButton
OutlinedButton(
  onPressed: () {},
  child: Text('Button'),
)

// Text-only action - use TextButton
TextButton(
  onPressed: () {},
  child: Text('Button'),
)

// With icon
FilledButton.icon(
  onPressed: () {},
  icon: Icon(Icons.add),
  label: Text('Button'),
)
```

**Using AppButton (wraps Material 3 buttons):**
```dart
AppButton.primary(
  label: 'Button',
  onPressed: () {},
)

AppButton.secondary(
  label: 'Button',
  onPressed: () {},
)

AppButton.outline(
  label: 'Button',
  onPressed: () {},
)

AppButton.ghost(
  label: 'Button',
  onPressed: () {},
)
```

### 4. Input Fields

**Before:**
```dart
TextField(
  decoration: InputDecoration(
    hintText: 'Enter text',
    filled: true,
    fillColor: AppColors.cardColor(context),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.borderDark),
    ),
  ),
)
```

**After (Material 3):**
```dart
TextField(
  decoration: InputDecoration(
    hintText: 'Enter text',
    // Material 3 uses InputDecorationTheme from theme
  ).applyDefaults(Theme.of(context).inputDecorationTheme),
)
```

**Or use CustomInputField (already migrated):**
```dart
CustomInputField(
  label: 'Label',
  hintText: 'Enter text',
  controller: controller,
  onChanged: (value) {},
)
```

### 5. Cards

**Before:**
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.cardColor(context),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.borderDark),
  ),
  child: content,
)
```

**After (Material 3):**
```dart
// Use Material 3 Card (elevation: 0, uses surface containers)
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: content,
  ),
)

// Or use AppCard (already migrated)
AppCard(
  child: content,
)
```

### 6. Spacing

**Before:**
```dart
SizedBox(height: AppSpacing.lg)
padding: EdgeInsets.all(AppSpacing.md)
```

**After (Material 3 - 4dp grid):**
```dart
// Use Material 3 spacing (multiples of 4dp)
const SizedBox(height: 16) // 16dp
const EdgeInsets.all(16) // 16dp
const SizedBox(height: 24) // 24dp

// Common Material 3 spacing values:
// 4, 8, 12, 16, 20, 24, 32, 48, 64
```

### 7. Error/Success Messages

**Before:**
```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.error.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.error.withOpacity(0.3)),
  ),
  child: Text(
    'Error message',
    style: TextStyle(color: AppColors.error),
  ),
)
```

**After (Material 3):**
```dart
// Error message
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'Error message',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    ],
  ),
)

// Success message
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: context.successColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Icon(
        Icons.check_circle_outline,
        color: context.successColor,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'Success message',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.successColor,
          ),
        ),
      ),
    ],
  ),
)
```

### 8. Dividers

**Before:**
```dart
Container(
  height: 1,
  color: AppColors.borderDark,
)
```

**After (Material 3):**
```dart
Divider(
  color: Theme.of(context).colorScheme.outlineVariant,
  thickness: 1,
)
```

### 9. Surface Containers (Elevation Hierarchy)

Material 3 uses surface container colors instead of elevation:

```dart
// Highest elevation
color: Theme.of(context).colorScheme.surfaceContainerHighest

// High elevation
color: Theme.of(context).colorScheme.surfaceContainerHigh

// Default elevation
color: Theme.of(context).colorScheme.surfaceContainer

// Low elevation
color: Theme.of(context).colorScheme.surfaceContainerLow

// Lowest elevation
color: Theme.of(context).colorScheme.surfaceContainerLowest
```

### 10. Icons

**Before:**
```dart
Icon(
  Icons.add,
  color: AppColors.textPrimary,
  size: 24,
)
```

**After (Material 3):**
```dart
Icon(
  Icons.add,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
  size: 24,
)

// Icon buttons
IconButton(
  onPressed: () {},
  icon: Icon(Icons.add),
)

// Filled icon button
IconButton.filled(
  onPressed: () {},
  icon: Icon(Icons.add),
)

// Tonal icon button
IconButton.filledTonal(
  onPressed: () {},
  icon: Icon(Icons.add),
)

// Outlined icon button
IconButton.outlined(
  onPressed: () {},
  icon: Icon(Icons.add),
)
```

## Step-by-Step Screen Migration

1. **Replace hardcoded colors:**
   - Find all `AppColors.*` usages
   - Replace with `Theme.of(context).colorScheme.*`
   - Use surface containers for backgrounds
   - Use onSurface variants for text

2. **Update typography:**
   - Replace hardcoded `TextStyle` with `textTheme.*`
   - Use appropriate Material 3 text styles
   - Remove hardcoded font sizes

3. **Update buttons:**
   - Replace `ElevatedButton` with `FilledButton` for primary actions
   - Use `FilledButton.tonal` for secondary actions
   - Use `OutlinedButton` for tertiary actions
   - Use `TextButton` for text-only actions
   - Or use `AppButton` wrapper

4. **Update inputs:**
   - Use `TextField` with `InputDecorationTheme` from theme
   - Or use `CustomInputField` component

5. **Update cards:**
   - Use Material 3 `Card` widget (elevation: 0)
   - Or use `AppCard` component

6. **Update spacing:**
   - Replace `AppSpacing.*` with Material 3 spacing (4dp grid)
   - Use: 4, 8, 12, 16, 20, 24, 32, 48, 64

7. **Update error/success messages:**
   - Use `errorContainer` for errors
   - Use theme extensions for success/warning

8. **Test:**
   - Test in light theme
   - Test in dark theme
   - Verify all interactive elements work
   - Check accessibility

## Example: Migrated Screen

See `phone_input_screen.dart` for a complete example of a migrated screen.

## Material 3 ColorScheme Properties

```dart
colorScheme.primary
colorScheme.onPrimary
colorScheme.primaryContainer
colorScheme.onPrimaryContainer
colorScheme.secondary
colorScheme.onSecondary
colorScheme.secondaryContainer
colorScheme.onSecondaryContainer
colorScheme.tertiary
colorScheme.onTertiary
colorScheme.tertiaryContainer
colorScheme.onTertiaryContainer
colorScheme.error
colorScheme.onError
colorScheme.errorContainer
colorScheme.onErrorContainer
colorScheme.surface
colorScheme.onSurface
colorScheme.surfaceVariant
colorScheme.onSurfaceVariant
colorScheme.surfaceContainerHighest
colorScheme.surfaceContainerHigh
colorScheme.surfaceContainer
colorScheme.surfaceContainerLow
colorScheme.surfaceContainerLowest
colorScheme.outline
colorScheme.outlineVariant
colorScheme.inverseSurface
colorScheme.onInverseSurface
colorScheme.inversePrimary
```

## Quick Reference

### Common Patterns

```dart
// Get theme
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;

// Primary button
FilledButton(onPressed: () {}, child: Text('Button'))

// Secondary button
FilledButton.tonal(onPressed: () {}, child: Text('Button'))

// Card
Card(child: Padding(padding: EdgeInsets.all(16), child: content))

// Text field
TextField(decoration: InputDecoration(hintText: 'Hint').applyDefaults(Theme.of(context).inputDecorationTheme))

// Error message
Container(
  color: colorScheme.errorContainer,
  child: Text('Error', style: TextStyle(color: colorScheme.onErrorContainer)),
)
```

## Resources

- [Material Design 3 Guidelines](https://m3.material.io/)
- [Flutter Material 3](https://docs.flutter.dev/ui/design/material)
- [Material 3 Color System](https://m3.material.io/styles/color/the-color-system/overview)

## Migration Checklist

For each screen:
- [ ] Replace all `AppColors.*` with `colorScheme.*`
- [ ] Replace hardcoded `TextStyle` with `textTheme.*`
- [ ] Update buttons to Material 3 variants
- [ ] Update inputs to use theme styling
- [ ] Update cards to use Material 3 Card
- [ ] Update spacing to Material 3 4dp grid
- [ ] Update error/success messages
- [ ] Test in light and dark themes
- [ ] Verify accessibility
- [ ] Remove unused imports

## Notes

- Material 3 uses elevation: 0 for cards (color creates depth)
- Material 3 uses 4dp grid for spacing
- Material 3 prefers color over shadows
- All colors should come from ColorScheme
- All typography should come from TextTheme
- Use surface containers for elevation hierarchy

