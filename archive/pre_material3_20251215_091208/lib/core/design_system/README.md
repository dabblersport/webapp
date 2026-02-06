# Dabbler Design System

## Overview
This design system ensures consistency across all screens in the Dabbler app using **Material Design 3**.

## Material 3 Migration

The app has been migrated to Material Design 3. See [MATERIAL3_MIGRATION_GUIDE.md](./MATERIAL3_MIGRATION_GUIDE.md) for migration patterns and examples.

### Key Changes
- ✅ Enhanced Material 3 theme with comprehensive tokens
- ✅ Updated components to use Material 3 patterns
- ✅ Created Material 3 extensions for category colors
- ✅ Standardized buttons, inputs, and cards
- ⏳ Screen migration in progress (see migration guide)

## Layout Structure

### Two-Section Layout
All screens follow a consistent two-section structure:

```dart
TwoSectionLayout(
  topSection: Column(
    children: [
      // Content for purple top section
    ],
  ),
  bottomSection: Column(
    children: [
      // Content for dark bottom section
    ],
  ),
)
```

**Top Section:**
- Background: Primary Purple (#6B2D9E)
- Border Radius: 52px (bottom corners)
- Padding: 20px (default)
- Contains: Headers, key actions, featured content

**Bottom Section:**
- Background: Dark (#1A1A1A)
- Padding: 20px (default)
- Contains: Lists, cards, secondary content

## Colors

### Material 3 ColorScheme

The app uses Material 3 ColorScheme for all colors. Access via:

```dart
final colorScheme = Theme.of(context).colorScheme;

// Primary colors
colorScheme.primary
colorScheme.onPrimary
colorScheme.primaryContainer
colorScheme.onPrimaryContainer

// Surface colors (for elevation hierarchy)
colorScheme.surfaceContainerHighest
colorScheme.surfaceContainerHigh
colorScheme.surfaceContainer
colorScheme.surfaceContainerLow
colorScheme.surfaceContainerLowest

// Text colors
colorScheme.onSurface
colorScheme.onSurfaceVariant

// Outline colors
colorScheme.outline
colorScheme.outlineVariant

// Error colors
colorScheme.error
colorScheme.errorContainer
colorScheme.onErrorContainer
```

### Category Colors

Category colors are available via ColorScheme extension:

```dart
colorScheme.categoryMain      // Purple
colorScheme.categorySocial    // Blue
colorScheme.categorySports    // Green
colorScheme.categoryActivities // Pink
colorScheme.categoryProfile   // Orange

// Or by name
colorScheme.getCategoryColor('main')
```

### App-Specific Colors

Success, warning, and info colors are available via theme extension:

```dart
// Using extension helper
context.successColor
context.warningColor
context.infoLinkColor
context.dangerColor

// Or directly
Theme.of(context).extension<AppThemeExtension>()?.success
```

### Legacy Colors (Deprecated)

⚠️ **Note:** The old `AppColors` class is deprecated. Use Material 3 ColorScheme instead. See migration guide for details.

## Typography

The app uses Material 3 typography. Access via:

```dart
final textTheme = Theme.of(context).textTheme;

// Display styles
textTheme.displayLarge    // 57sp, weight 400
textTheme.displayMedium   // 45sp, weight 400
textTheme.displaySmall    // 36sp, weight 400

// Headline styles
textTheme.headlineLarge   // 32sp, weight 400
textTheme.headlineMedium  // 28sp, weight 400
textTheme.headlineSmall   // 24sp, weight 400

// Title styles
textTheme.titleLarge      // 22sp, weight 400
textTheme.titleMedium     // 16sp, weight 500
textTheme.titleSmall      // 14sp, weight 500

// Body styles
textTheme.bodyLarge       // 16sp, weight 400
textTheme.bodyMedium      // 14sp, weight 400
textTheme.bodySmall       // 12sp, weight 400

// Label styles
textTheme.labelLarge      // 14sp, weight 500
textTheme.labelMedium     // 12sp, weight 500
textTheme.labelSmall      // 11sp, weight 500
```

### Usage

```dart
Text(
  'Title',
  style: textTheme.headlineSmall?.copyWith(
    color: colorScheme.onSurface,
  ),
)
```

## Spacing

Material 3 uses a **4dp grid system**. Common spacing values:

```dart
// Standard spacing (multiples of 4dp)
const SizedBox(height: 4)   // 4dp
const SizedBox(height: 8)   // 8dp
const SizedBox(height: 12)  // 12dp
const SizedBox(height: 16)  // 16dp
const SizedBox(height: 20)  // 20dp
const SizedBox(height: 24)  // 24dp
const SizedBox(height: 32)  // 32dp
const SizedBox(height: 48)  // 48dp
const SizedBox(height: 64)  // 64dp

// Padding
const EdgeInsets.all(16)           // 16dp all sides
const EdgeInsets.symmetric(horizontal: 16, vertical: 8)  // 16dp horizontal, 8dp vertical
```

### Common Use Cases
- Screen padding: 16dp or 20dp
- Card padding: 16dp
- Section spacing: 24dp
- Card border radius: 12dp (Material 3 standard)
- Button border radius: 12dp (Material 3 standard)

## Components

### Buttons

#### Material 3 Buttons

```dart
// Primary action
FilledButton(
  onPressed: () {},
  child: Text('Button'),
)

// Secondary action
FilledButton.tonal(
  onPressed: () {},
  child: Text('Button'),
)

// Tertiary action
OutlinedButton(
  onPressed: () {},
  child: Text('Button'),
)

// Text-only action
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

#### AppButton Wrapper

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

### Cards

#### Material 3 Card

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: YourContent(),
  ),
)
```

#### AppCard (Wrapper)

```dart
AppCard(
  child: YourContent(),
)
```

#### AppButtonCard
Button-style card with emoji and label:
```dart
AppButtonCard(
  emoji: '🏆',
  label: 'Sports',
  onTap: () {},
)
```

#### AppActionCard
Card with emoji, title, and subtitle:
```dart
AppActionCard(
  emoji: '➕',
  title: 'Create Game',
  subtitle: 'Start a new match',
  onTap: () {},
)
```

### Input Fields

#### Material 3 TextField

```dart
TextField(
  decoration: InputDecoration(
    hintText: 'Enter text',
  ).applyDefaults(Theme.of(context).inputDecorationTheme),
)
```

#### CustomInputField (Wrapper)

```dart
CustomInputField(
  label: 'Label',
  hintText: 'Enter text',
  controller: controller,
  onChanged: (value) {},
)
```

### Chips

```dart
// Filter chip
FilterChip(
  label: Text('Filter'),
  selected: isSelected,
  onSelected: (selected) {},
)

// Choice chip
ChoiceChip(
  label: Text('Choice'),
  selected: isSelected,
  onSelected: (selected) {},
)

// Action chip
ActionChip(
  label: Text('Action'),
  onPressed: () {},
)
```

## Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/layouts/two_section_layout.dart';
import 'package:dabbler/core/design_system/widgets/app_card.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return TwoSectionLayout(
      topSection: Column(
        children: [
          Text(
            'Header',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          // More top section content
        ],
      ),
      bottomSection: Column(
        children: [
          AppCard(
            child: Text('Card Content'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButtonCard(
                  emoji: '📚',
                  label: 'Community',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButtonCard(
                  emoji: '🏆',
                  label: 'Sports',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## Material 3 Patterns

### Elevation
Material 3 uses **surface container colors** instead of elevation for depth:
- `surfaceContainerHighest` - Highest elevation
- `surfaceContainerHigh` - High elevation
- `surfaceContainer` - Default elevation
- `surfaceContainerLow` - Low elevation
- `surfaceContainerLowest` - Lowest elevation

### State Layers
Material 3 uses state layers for interactive elements:
- Hover: `onSurface.withOpacity(0.08)`
- Focus: `onSurface.withOpacity(0.12)`
- Pressed: `onSurface.withOpacity(0.16)`

### Shape
Material 3 uses rounded corners:
- Small: 8dp radius
- Medium: 12dp radius (default)
- Large: 16dp radius

## Naming Conventions

### Files
- Colors: `app_colors.dart`
- Typography: `app_typography.dart`
- Spacing: `app_spacing.dart`
- Widgets: `app_[widget_name].dart`

### Classes
- Use `App` prefix for design system classes
- Use descriptive names: `AppCard`, `AppButtonCard`, `AppActionCard`

## Migration Status

### Completed ✅
- Material 3 theme with comprehensive tokens
- Material 3 extensions for category colors
- Updated core components (buttons, inputs, cards)
- Migration guide documentation
- Example migrated screen (phone_input_screen)

### In Progress ⏳
- Screen-by-screen migration (62+ screens)
- Design system documentation updates

### Resources
- [Material 3 Migration Guide](./MATERIAL3_MIGRATION_GUIDE.md)
- [Material Design 3 Guidelines](https://m3.material.io/)
- [Flutter Material 3](https://docs.flutter.dev/ui/design/material)
