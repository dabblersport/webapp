# Iconsax Icons Usage Guide

## Overview

The Dabbler design system now uses **Iconsax icons** (from https://app.iconsax.io/) instead of Material Icons for a more modern, consistent visual style. Iconsax provides beautiful outline and bold icons that better match our Figma designs.

## Package

We use the `iconsax_flutter` package (v1.0.0) which provides access to all Iconsax icons.

## Import

```dart
import 'package:iconsax_flutter/iconsax_flutter.dart';
```

## Icon Variants

Iconsax provides **two variants** for most icons:
1. **Outline** (default) - Regular outlined style
2. **Bold** - Filled/bold style (suffix `_copy`)

### Examples

```dart
// Outline variant (default)
Icon(Iconsax.home)
Icon(Iconsax.user)
Icon(Iconsax.search_normal)

// Bold variant (use _copy suffix)
Icon(Iconsax.home_copy)
Icon(Iconsax.user_copy) 
Icon(Iconsax.search_normal_copy)
```

## Common Icon Mappings

Here's a mapping from Material Icons to Iconsax equivalents:

### Navigation & Actions
| Material Icon | Iconsax Outline | Iconsax Bold |
|--------------|----------------|--------------|
| `Icons.add` | `Iconsax.add` | `Iconsax.add_copy` |
| `Icons.arrow_forward` | `Iconsax.arrow_right` | `Iconsax.arrow_right_copy` |
| `Icons.arrow_back` | `Iconsax.arrow_left` | `Iconsax.arrow_left_copy` |
| `Icons.close` | `Iconsax.close_circle` | `Iconsax.close_circle_copy` |
| `Icons.menu` | `Iconsax.menu` | `Iconsax.menu_copy` |
| `Icons.more_vert` | `Iconsax.more` | `Iconsax.more_copy` |
| `Icons.more_horiz` | `Iconsax.more_2` | `Iconsax.more_2_copy` |

### UI Elements
| Material Icon | Iconsax Outline | Iconsax Bold |
|--------------|----------------|--------------|
| `Icons.home` | `Iconsax.home` | `Iconsax.home_copy` |
| `Icons.search` | `Iconsax.search_normal` | `Iconsax.search_normal_copy` |
| `Icons.filter_list` | `Iconsax.filter` | `Iconsax.filter_copy` |
| `Icons.settings` | `Iconsax.setting` | `Iconsax.setting_copy` |
| `Icons.notifications` | `Iconsax.notification` | `Iconsax.notification_copy` |
| `Icons.star` | `Iconsax.star` | `Iconsax.star_copy` |
| `Icons.favorite` | `Iconsax.heart` | `Iconsax.heart_copy` |

### User & Profile
| Material Icon | Iconsax Outline | Iconsax Bold |
|--------------|----------------|--------------|
| `Icons.person` | `Iconsax.user` | `Iconsax.user_copy` |
| `Icons.account_circle` | `Iconsax.profile_circle` | `Iconsax.profile_circle_copy` |
| `Icons.group` | `Iconsax.people` | `Iconsax.people_copy` |
| `Icons.email` | `Iconsax.sms` | `Iconsax.sms_copy` |
| `Icons.phone` | `Iconsax.call` | `Iconsax.call_copy` |

### Forms & Input
| Material Icon | Iconsax Outline | Iconsax Bold |
|--------------|----------------|--------------|
| `Icons.visibility` | `Iconsax.eye` | `Iconsax.eye_copy` |
| `Icons.visibility_off` | `Iconsax.eye_slash` | `Iconsax.eye_slash_copy` |
| `Icons.lock` | `Iconsax.lock` | `Iconsax.lock_copy` |
| `Icons.check` | `Iconsax.tick_circle` | `Iconsax.tick_circle_copy` |
| `Icons.edit` | `Iconsax.edit` | `Iconsax.edit_copy` |
| `Icons.delete` | `Iconsax.trash` | `Iconsax.trash_copy` |

### Sports & Activities
| Material Icon | Iconsax Outline | Iconsax Bold |
|--------------|----------------|--------------|
| `Icons.sports_soccer` | `Iconsax.ticket_2` | `Iconsax.ticket_2_copy` |
| `Icons.sports_basketball` | `Iconsax.game` | `Iconsax.game_copy` |
| `Icons.sports` | `Iconsax.activity` | `Iconsax.activity_copy` |
| `Icons.location_on` | `Iconsax.location` | `Iconsax.location_copy` |
| `Icons.calendar_today` | `Iconsax.calendar` | `Iconsax.calendar_copy` |

### Media & Content
| Material Icon | Iconsax Outline | Iconsax Bold |
|--------------|----------------|--------------|
| `Icons.image` | `Iconsax.gallery` | `Iconsax.gallery_copy` |
| `Icons.camera_alt` | `Iconsax.camera` | `Iconsax.camera_copy` |
| `Icons.video_library` | `Iconsax.video` | `Iconsax.video_copy` |
| `Icons.play_arrow` | `Iconsax.play` | `Iconsax.play_copy` |
| `Icons.share` | `Iconsax.share` | `Iconsax.share_copy` |

### Status & Feedback
| Material Icon | Iconsax Outline | Iconsax Bold |
|--------------|----------------|--------------|
| `Icons.check_circle` | `Iconsax.tick_circle` | `Iconsax.tick_circle_copy` |
| `Icons.error` | `Iconsax.danger` | `Iconsax.danger_copy` |
| `Icons.warning` | `Iconsax.warning_2` | `Iconsax.warning_2_copy` |
| `Icons.info` | `Iconsax.info_circle` | `Iconsax.info_circle_copy` |

## Usage in Components

### AppButton

```dart
// Primary button with icon
AppButton.primary(
  label: 'Continue',
  onPressed: () {},
  leftIcon: const Icon(Iconsax.add_copy),
  rightIcon: const Icon(Iconsax.arrow_right_copy),
)

// Outlined button with icon
AppButton.outlined(
  label: 'Edit',
  onPressed: () {},
  leftIcon: const Icon(Iconsax.edit_copy),
)
```

### AppLabel

```dart
AppLabel.filled(
  text: 'Featured',
  leftIcon: const Icon(Iconsax.star_copy),
)

AppLabel.subtle(
  text: 'Verified',
  leftIcon: const Icon(Iconsax.tick_circle_copy),
)
```

### AppChip

```dart
AppChip(
  label: 'Football',
  icon: const Icon(Iconsax.ticket_2_copy),
  isActive: true,
  onTap: () {},
)
```

### AppTab

```dart
AppTab(
  label: 'Explore',
  icon: const Icon(Iconsax.search_normal_copy),
  isActive: true,
  onTap: () {},
)
```

### AppInputField

```dart
AppInputField(
  label: 'Email',
  placeholder: 'Enter your email',
  prefixIcon: Iconsax.sms_copy,
)

AppInputField(
  label: 'Password',
  obscureText: true,
  prefixIcon: Iconsax.lock_copy,
  suffixIcon: const Icon(Iconsax.eye_copy, size: 18),
)
```

### AppFilterChip

```dart
AppFilterChip(
  label: 'Filter',
  icon: Iconsax.filter_copy,
  isSelected: true,
  onTap: () {},
)
```

## Icon Sizing

Iconsax icons work well with Flutter's standard icon sizing:

```dart
// Small (18px)
Icon(Iconsax.add_copy, size: 18)

// Default (24px)
Icon(Iconsax.add_copy) // or size: 24

// Medium (28px)
Icon(Iconsax.add_copy, size: 28)

// Large (32px)
Icon(Iconsax.add_copy, size: 32)
```

## Color Customization

Icons inherit colors from their parent `IconTheme` or can be customized:

```dart
// Using theme colors
Icon(
  Iconsax.heart_copy,
  color: Theme.of(context).colorScheme.primary,
)

// Custom color
Icon(
  Iconsax.heart_copy,
  color: Colors.red,
)

// From IconTheme
IconTheme(
  data: IconThemeData(
    color: Colors.blue,
    size: 24,
  ),
  child: Icon(Iconsax.star_copy),
)
```

## Best Practices

### 1. **Use Bold Variants for Primary Actions**
```dart
// Good - uses bold variant for emphasis
AppButton.primary(
  label: 'Create Game',
  leftIcon: const Icon(Iconsax.add_copy), // bold
)

// Outline variant for secondary actions
AppButton.outlined(
  label: 'View Details',
  leftIcon: const Icon(Iconsax.eye), // outline
)
```

### 2. **Consistent Icon Usage**
Use the same icon for the same action throughout the app:
- Add: `Iconsax.add_copy`
- Edit: `Iconsax.edit_copy`
- Delete: `Iconsax.trash_copy`
- Search: `Iconsax.search_normal_copy`
- Filter: `Iconsax.filter_copy`

### 3. **Icon-Text Alignment**
Ensure icons align well with text:
```dart
Row(
  children: [
    Icon(Iconsax.location_copy, size: 16),
    const SizedBox(width: 4),
    Text('Location'),
  ],
)
```

### 4. **Loading States**
For loading states, use consistent loading icons:
```dart
// Loading
Icon(Iconsax.refresh, size: 24)

// Processing
CircularProgressIndicator()
```

### 5. **Accessibility**
Always provide semantic labels for icon-only buttons:
```dart
IconButton(
  icon: const Icon(Iconsax.notification_copy),
  tooltip: 'Notifications',
  onPressed: () {},
)
```

## Finding Icons

To find the right Iconsax icon:

1. Visit https://app.iconsax.io/
2. Search for the icon you need
3. Note the icon name (e.g., "home", "user", "search-normal")
4. Convert to Dart format:
   - Outline: `Iconsax.icon_name`
   - Bold: `Iconsax.icon_name_copy`
   - Use underscores for multi-word names: `search_normal`, `tick_circle`

## Migration from Material Icons

To migrate existing code:

1. Find the Material Icon being used
2. Look up the Iconsax equivalent in the mapping table above
3. Replace `Icons.icon_name` with `Iconsax.icon_name_copy` (bold variant)
4. Update imports to include `iconsax_flutter`

Example:
```dart
// Before
Icon(Icons.add)
Icon(Icons.arrow_forward)
Icon(Icons.star)

// After
Icon(Iconsax.add_copy)
Icon(Iconsax.arrow_right_copy)
Icon(Iconsax.star_copy)
```

## Additional Resources

- **Iconsax Website**: https://app.iconsax.io/
- **Package Documentation**: https://pub.dev/packages/iconsax_flutter
- **Icon Browser**: Browse all available icons at https://iconsax.io/icons

## Support

If you can't find an Iconsax equivalent for a Material Icon:
1. Check https://app.iconsax.io/ for alternatives
2. Consider using a similar Iconsax icon
3. As a last resort, keep the Material Icon for that specific use case
4. Document any Material Icon exceptions in code comments
