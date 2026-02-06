# Material Design 3 Button Migration

## Overview

The `AppButton` component has been refactored to use Material Design 3 button components as the foundation while maintaining the exact same visual style from the Figma design specifications.

## What Changed

### Before (Custom Implementation)
- Used `GestureDetector` with `Container` for button rendering
- Manual styling with decoration properties
- Custom opacity handling for disabled states
- No built-in Material Design states (pressed, hovered, focused)

### After (Material 3 Based)
- Uses Material 3 button components:
  - **FilledButton** for `defaultType` (filled buttons)
  - **OutlinedButton** for `outlined` and `ghostOutline` types
  - **TextButton** for `ghost` type
- Leverages Material Design state management (`WidgetState`)
- Built-in support for press, hover, focus states with proper ripple effects
- Native accessibility features from Material components
- Automatic disabled state handling

## Benefits of Material 3 Foundation

### 1. **Material Design Compliance**
- Follows Material 3 design principles
- Consistent with Flutter's design system
- Better integration with other Material widgets

### 2. **Enhanced User Experience**
- Native ripple effects on press
- Hover states for web/desktop
- Focus indicators for keyboard navigation
- Proper touch feedback

### 3. **Accessibility**
- Built-in ARIA labels support
- Screen reader compatibility
- Keyboard navigation support
- Semantic button behavior

### 4. **State Management**
- Material `WidgetState` handles:
  - `WidgetState.disabled`
  - `WidgetState.pressed`
  - `WidgetState.hovered`
  - `WidgetState.focused`
- Automatic state transitions
- No manual opacity tracking needed

### 5. **Performance**
- Optimized rendering from Material framework
- Efficient state updates
- Better animation performance

### 6. **Maintainability**
- Less custom code to maintain
- Leverages well-tested Flutter components
- Future-proof with Material 3 updates

## Visual Style Maintained

All Figma design specifications are preserved:

### Sizes
- **Small**: 24px height, 6px border radius
- **Default**: 36px height, 12px border radius  
- **Large**: 48px height, 18px border radius

### Types
- **Default (Filled)**: Solid background with `tokens.button`
- **Outlined**: Transparent background with border
- **Ghost**: No background, no border
- **Ghost Outline**: Surface background with subtle border

### Design Tokens
- Background: `colors/brand/button → tokens.button`
- Text/Icon: `colors/brand/on-btn → tokens.onBtn`
- Border: `colors/brand/stroke → tokens.stroke (18% opacity)`
- Ghost text: `colors/brand/neutral → tokens.neutral (92% opacity)`

## Implementation Details

### Button Style System
Each button type uses `ButtonStyle` with `WidgetStateProperty` for dynamic styling:

```dart
ButtonStyle baseStyle = ButtonStyle(
  minimumSize: WidgetStateProperty.all(Size(64, specs.height)),
  padding: WidgetStateProperty.all(EdgeInsets.symmetric(...)),
  shape: WidgetStateProperty.all(RoundedRectangleBorder(...)),
  textStyle: WidgetStateProperty.all(TextStyle(...)),
  overlayColor: WidgetStateProperty.resolveWith((states) {
    // Dynamic press/hover states
  }),
);
```

### Type-Specific Customization
Each button type extends the base style:

- **FilledButton**: Solid background colors
- **OutlinedButton**: Border with transparent/surface background
- **TextButton**: Completely transparent

### Disabled States
All disabled states automatically reduce opacity to 38% following Material Design guidelines.

## API Compatibility

**No breaking changes!** The public API remains identical:

```dart
// All existing usage continues to work
AppButton.primary(label: 'Continue', onPressed: () {})
AppButton.outlined(label: 'Cancel', onPressed: () {})
AppButton.ghost(label: 'Skip', onPressed: () {})
AppButton.ghostOutline(label: 'Learn More', onPressed: () {})
```

Factory constructors and all parameters are unchanged.

## Testing

The button has been tested to ensure:
- ✅ Visual parity with Figma designs
- ✅ All 36 variants render correctly (4 types × 3 sizes × 3 icon configs)
- ✅ Disabled states display properly
- ✅ Press/hover states work correctly
- ✅ Custom colors can override defaults
- ✅ Icons render at correct sizes

## Migration Notes

For developers:
- **No code changes needed** in existing usage
- Button behavior is now more consistent with Material Design
- Press states now have ripple effects (expected Material behavior)
- Accessibility is automatically improved

## Future Enhancements

With Material 3 foundation, we can easily add:
- Badge support (via Material Badge widget)
- Segmented button groups
- Icon buttons with consistent styling
- Extended FAB variations
- Loading states with CircularProgressIndicator

## Related Components

Other buttons in the design system:
- `DesignSystemButton` - Another button implementation (consider consolidating)
- `AppFilterChip` - Chip-style buttons for filters
- `AppChip` - Selectable chips
- `AppTab` - Tab navigation buttons

Consider migrating these to Material 3 patterns as well.
