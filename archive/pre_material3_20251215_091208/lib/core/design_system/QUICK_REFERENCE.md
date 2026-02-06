# Design System Quick Reference

## Import
```dart
import 'package:dabbler/core/design_system/design_system.dart';
```

## Screen Structure
```dart
TwoSectionLayout(
  topSection: Column(children: [...]),
  bottomSection: Column(children: [...]),
)
```

## Colors
```dart
AppColors.primaryPurple
AppColors.backgroundDark
AppColors.backgroundCardDark
AppColors.textPrimary
AppColors.textSecondary
```

## Typography
```dart
AppTypography.displayLarge       // 28px, bold (like "Moataz!")
AppTypography.greeting           // 22px (like "Good morning")
AppTypography.headingLarge       // 20px
AppTypography.headingMedium      // 18px
AppTypography.bodyLarge          // 15px
AppTypography.bodyMedium         // 14px
```

## Spacing
```dart
AppSpacing.xs                    // 4px
AppSpacing.sm                    // 8px
AppSpacing.md                    // 12px
AppSpacing.lg                    // 16px
AppSpacing.xl                    // 20px
AppSpacing.xxl                   // 24px
AppSpacing.sectionSpacing        // 24px (between major sections)
AppSpacing.elementSpacing        // 12px (between elements)
```

## Widgets

### Button Card
```dart
AppButtonCard(
  emoji: '🏆',
  label: 'Sports',
  onTap: () {},
)
```

### Action Card
```dart
AppActionCard(
  emoji: '➕',
  title: 'Create Game',
  subtitle: 'Start a new match',
  onTap: () {},
)
```

### CTA Button
```dart
DesignSystemButton(
  label: 'Continue',
  leadingIcon: Icons.add,             // optional
  trailingIcon: Icons.arrow_forward,  // optional
  size: DesignSystemButtonSize.large, // small | medium | large
  onPressed: () {},
)
```

### Generic Card
```dart
AppCard(
  child: YourWidget(),
  onTap: () {},  // optional
)
```

## Common Patterns

### Two Buttons Side by Side
```dart
Row(
  children: [
    Expanded(child: AppButtonCard(...)),
    SizedBox(width: AppSpacing.md),
    Expanded(child: AppButtonCard(...)),
  ],
)
```

### Section with Title
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Title', style: AppTypography.headingLarge),
    SizedBox(height: AppSpacing.elementSpacing),
    // Content...
  ],
)
```

### List of Cards
```dart
...List.generate(items.length, (index) =>
  Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.md),
    child: AppCard(...),
  ),
)
```

## Border Radius Reference
- Sections: 52px (AppSpacing.sectionBorderRadius)
- Cards: 16px (AppSpacing.cardBorderRadius)
- Buttons: 12px (AppSpacing.buttonBorderRadius)
