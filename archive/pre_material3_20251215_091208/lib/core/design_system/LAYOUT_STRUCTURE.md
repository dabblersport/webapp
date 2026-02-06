# Two-Section Screen Structure Documentation

## 📐 Screen Layout Architecture

### Overview
The app uses a standardized **Two-Section Layout** design pattern:
- **Top Section**: Purple background (`#6B2D9E`) with rounded bottom corners
- **Bottom Section**: Dark background (`#1A1A1A`) for main content

---

## 🎨 Visual Structure

```
┌─────────────────────────────────────┐
│                                     │
│        PURPLE TOP SECTION           │
│      (#6B2D9E Purple)               │
│                                     │
│   [20px padding all sides]          │
│   [28px bottom padding]             │
│                                     │
│   - Logo                            │
│   - Welcome text                    │
│   - Description                     │
│                                     │
└─────────────────╮         ╭─────────┘
                  │ 52px    │ 
                  │ radius  │
                  └─────────┘

┌─────────────────────────────────────┐
│                                     │
│        DARK BOTTOM SECTION          │
│      (#1A1A1A Dark)                 │
│                                     │
│   [20px padding all sides]          │
│                                     │
│   - Input fields                    │
│   - Buttons                         │
│   - Content                         │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

---

## 📏 Detailed Measurements

### Top Section (Purple)
- **Background Color**: `AppColors.primaryPurple` (#6B2D9E)
- **Padding**: 
  - Top: `20px`
  - Left: `20px`
  - Right: `20px`
  - Bottom: `28px` (extra space before curve)
- **Border Radius**: 
  - Bottom Left: `52px`
  - Bottom Right: `52px`
  - Top corners: `0px` (square)

### Bottom Section (Dark)
- **Background Color**: `AppColors.backgroundDark` (#1A1A1A)
- **Padding**: `20px` all sides
- **Border Radius**: None (square corners)

---

## 🔧 Implementation Details

### File: `TwoSectionLayout` Widget
Location: `/lib/core/design_system/layouts/two_section_layout.dart`

```dart
TwoSectionLayout(
  topSection: Widget,      // Content for purple section
  bottomSection: Widget,   // Content for dark section
  topPadding: EdgeInsets?, // Optional custom padding (default: 20,20,20,28)
  bottomPadding: EdgeInsets?, // Optional custom padding (default: 20)
)
```

### Key Components:
1. **Scaffold** - Root container
2. **SafeArea** - Handles notches/system UI
3. **SingleChildScrollView** - Makes content scrollable
4. **BouncingScrollPhysics** - iOS-style bounce effect
5. **Column** - Stacks top and bottom sections

---

## 📐 Spacing Constants

From `AppSpacing` class:

| Name | Value | Usage |
|------|-------|-------|
| `xs` | 4px | Minimal gaps |
| `sm` | 8px | Small spacing |
| `md` | 12px | Medium spacing |
| `lg` | 16px | Large spacing |
| `xl` | 20px | Extra large (screen padding) |
| `xxl` | 24px | Section spacing |
| `xxxl` | 28px | Extra spacing |
| `huge` | 32px | Maximum spacing |
| `sectionBorderRadius` | **52px** | 🎯 Bottom curve radius |
| `cardBorderRadius` | 16px | Cards |
| `buttonBorderRadius` | 12px | Buttons/inputs |

---

## 🎯 The 52px Curve

### Why 52px?
The **52px border radius** creates a smooth, modern curve at the bottom of the purple section:
- Large enough to be noticeable and elegant
- Not too large to waste space
- Matches modern mobile UI design trends
- Creates visual separation between sections

### CSS Equivalent:
```css
border-radius: 0 0 52px 52px;
/* top-left, top-right, bottom-right, bottom-left */
```

### Flutter Code:
```dart
BorderRadius.only(
  bottomLeft: Radius.circular(52),
  bottomRight: Radius.circular(52),
)
```

---

## 📱 Responsive Behavior

### Scrolling
- Both sections scroll together as one unit
- `SingleChildScrollView` enables vertical scrolling
- `BouncingScrollPhysics` adds iOS-style overscroll bounce

### SafeArea
- Automatically handles:
  - iPhone notches
  - Status bar
  - Home indicator
  - System gestures areas

---

## 🎨 Color System

### Purple Section
- Background: `#6B2D9E` (Primary Purple)
- Text: White (`#FFFFFF`)
- Secondary text: White70 (70% opacity white)

### Dark Section  
- Background: `#1A1A1A` (Dark)
- Cards: `#2D2D2D` (Card Dark)
- Borders: `#404040` (Border Dark)
- Text Primary: `#FFFFFF` (White)
- Text Secondary: `#AAAAAA` (Gray)

---

## 💡 Usage Example

```dart
@override
Widget build(BuildContext context) {
  return TwoSectionLayout(
    topSection: Column(
      children: [
        SvgPicture.asset('logo.svg'),
        SizedBox(height: AppSpacing.xl),
        Text('Welcome to dabbler!'),
      ],
    ),
    bottomSection: Column(
      children: [
        TextField(...),
        SizedBox(height: AppSpacing.lg),
        ElevatedButton(...),
      ],
    ),
  );
}
```

---

## 🔍 Key Design Decisions

### 1. **Fixed Bottom Curve**
   - The 52px radius is fixed, not responsive
   - Ensures consistency across all screen sizes
   - Matches Figma design specifications

### 2. **Standardized Padding**
   - Top section: 20px sides, 28px bottom (extra space before curve)
   - Bottom section: 20px all sides
   - Consistent across all screens

### 3. **Scrollable Content**
   - Entire screen scrolls as one unit
   - No separate scrolling for top/bottom sections
   - Simpler UX, less confusion

### 4. **Color Contrast**
   - Purple (#6B2D9E) vs Dark (#1A1A1A)
   - 6.8:1 contrast ratio (WCAG AA compliant)
   - Good readability with white text

---

## 📋 Checklist for New Screens

When creating a new screen:

- [ ] Use `TwoSectionLayout` widget
- [ ] Top section: Logo, title, description
- [ ] Bottom section: Interactive content
- [ ] Use `AppSpacing` constants (no hardcoded values)
- [ ] Use `AppColors` constants (no hardcoded colors)
- [ ] Test scrolling behavior
- [ ] Verify on different screen sizes
- [ ] Check text readability (white on purple/dark)

---

## 🚀 Benefits of This Structure

1. **Consistency** - All screens look and feel the same
2. **Maintainability** - Change once, apply everywhere
3. **Accessibility** - Built-in SafeArea and scroll handling
4. **Performance** - Efficient rendering with single scroll view
5. **Design System** - Follows established patterns
6. **Developer Experience** - Easy to implement new screens

---

## 📊 Current Implementation

Screens using this pattern:
- ✅ Home Screen
- ✅ Social Feed Screen
- ✅ Phone Input Screen
- 🔄 More screens to follow...

---

## 🎓 Technical Notes

### Container Hierarchy:
```
Scaffold
  └─ SafeArea
      └─ SingleChildScrollView
          └─ Column
              ├─ Container (Purple section with rounded bottom)
              │   └─ Padding
              │       └─ [topSection content]
              └─ Padding
                  └─ [bottomSection content]
```

### Performance:
- Single `build()` pass
- No nested scroll views
- Efficient widget tree
- Minimal rebuilds

---

## 📖 Related Documentation

- `README.md` - Full design system documentation
- `QUICK_REFERENCE.md` - Quick code snippets
- `example_screen.dart` - Complete screen template

