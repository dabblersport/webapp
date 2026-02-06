# AppFilterChip - Design System Component

## Overview
A filter chip widget following the design system style with emoji + text display, and an optional count badge for active state.

## Usage

### Basic Usage
```dart
AppFilterChip(
  emoji: '⚽️',
  label: 'Football',
  isSelected: false,
  onTap: () {
    // Handle tap
  },
)
```

### With Count Badge (Active State)
```dart
AppFilterChip(
  emoji: '🎮',
  label: 'All',
  isSelected: true,
  count: 30,
  onTap: () {
    // Handle tap
  },
)
```

### Custom Colors
```dart
AppFilterChip(
  emoji: '🏏',
  label: 'Cricket',
  isSelected: true,
  count: 15,
  selectedColor: Colors.orange.withOpacity(0.15),
  selectedBorderColor: Colors.orange,
  selectedTextColor: Colors.orange,
  onTap: () {
    // Handle tap
  },
)
```

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `emoji` | String | Yes | The emoji to display (e.g., '⚽️', '🎮') |
| `label` | String | Yes | The label text (e.g., 'Football', 'All') |
| `isSelected` | bool | Yes | Whether the chip is selected/active |
| `onTap` | VoidCallback? | No | Callback when the chip is tapped |
| `count` | int? | No | Optional count to display in active state |
| `selectedColor` | Color? | No | Background color when selected |
| `selectedBorderColor` | Color? | No | Border color when selected |
| `selectedTextColor` | Color? | No | Text color when selected |

## States

### Rest State
- Background: `AppColors.cardColor(context)`
- Border: Light gray with opacity
- Text color: Caption text color
- Shows: Emoji + Label

### Active State
- Background: Selected color with opacity (default: Sports primary with 0.15 opacity)
- Border: Selected border color (default: Sports primary)
- Text color: Selected text color (default: Sports primary)
- Shows: Emoji + Label + Count Badge (if count is provided)

## Count Badge
The count badge appears only when:
1. `isSelected` is `true`
2. `count` is provided and not null

Badge styling:
- Background: Same as `selectedTextColor`
- Text: White, 12px, font weight 500
- Shape: Rounded pill (10px border radius)

## Example Implementation

See `lib/features/explore/presentation/screens/sports_screen.dart` for a real-world example:

```dart
Widget _buildSportsChips() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_sports.length, (index) {
          final sport = _sports[index];
          final isSelected = _selectedSportIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppFilterChip(
              emoji: sport['emoji'] ?? '⚽️',
              label: sport['name'],
              isSelected: isSelected,
              count: isSelected ? sport['count'] : null,
              selectedColor: AppColors.primarySportsBtn.withOpacity(0.15),
              selectedBorderColor: AppColors.primarySportsBtn,
              selectedTextColor: AppColors.primarySportsBtn,
              onTap: () {
                setState(() {
                  _selectedSportIndex = index;
                });
              },
            ),
          );
        }),
      ),
    ),
  );
}
```
