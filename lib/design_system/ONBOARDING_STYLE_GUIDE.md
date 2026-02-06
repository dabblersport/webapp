# Onboarding Style Guide

This document defines the design standards for all authentication and onboarding screens in the Dabbler app. All screens in the auth journey and onboarding flow **MUST** follow these guidelines to ensure visual consistency and adherence to the Material 3 token system.

## Layout Architecture

### 1. Container Structure
All auth/onboarding screens use a two-layer container architecture:

```dart
Scaffold(
  backgroundColor: tokens.main.background, // Outer container
  body: Padding(
    padding: const EdgeInsets.all(AppSpacing.xs), // 4dp padding
    child: ClipRRect(
      borderRadius: AppRadius.extraExtraLarge,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.main.secondaryContainer, // Inner container
        ),
        child: SafeArea(
          child: // Screen content
        ),
      ),
    ),
  ),
)
```

**Rules:**
- Outer container: `tokens.main.background`
- Inner container: `tokens.main.secondaryContainer`
- Padding between containers: `EdgeInsets.all(AppSpacing.xs)` (4dp)
- Border radius: `AppRadius.extraExtraLarge`
- SafeArea is placed **inside** the secondary container

### 2. Content Padding
Inner content uses consistent padding:

```dart
Padding(
  padding: const EdgeInsets.all(AppSpacing.xxl), // 24dp
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Screen content
    ],
  ),
)
```

## Typography Hierarchy

### 1. Screen Title
Primary heading that identifies the screen purpose.

```dart
Text(
  'Screen Title',
  style: theme.textTheme.displayMedium?.copyWith(
    fontWeight: FontWeight.w800,
    color: tokens.main.onSecondaryContainer,
  ),
)
```

**Properties:**
- Typography: `displayMedium`
- Font Weight: `w800` (Extra Bold)
- Color: `tokens.main.onSecondaryContainer`

### 2. Headlines
Secondary headings and subheadings.

```dart
Text(
  'Headline Text',
  style: theme.textTheme.headlineSmall?.copyWith(
    fontWeight: FontWeight.w500,
    color: tokens.main.onSecondaryContainer,
  ),
)
```

**Properties:**
- Typography: `headlineSmall`
- Font Weight: `w500` (Medium)
- Color: `tokens.main.onSecondaryContainer`

### 3. Paragraphs
Body text, descriptions, and informational content.

```dart
Text(
  'Paragraph text content',
  style: theme.textTheme.bodyMedium?.copyWith(
    color: tokens.main.onSecondaryContainer,
    height: 1.25, // Optional: line height for readability
  ),
)
```

**Properties:**
- Typography: `bodyMedium`
- Color: `tokens.main.onSecondaryContainer`
- Line Height: `1.25` (optional, for multi-line paragraphs)

### 4. Labels & Small Text
Field labels, captions, and tertiary text.

```dart
Text(
  'Label',
  style: theme.textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w700,
    color: tokens.main.onSecondaryContainer,
  ),
)
```

**Properties:**
- Typography: `titleMedium`
- Font Weight: `w700` (Bold)
- Color: `tokens.main.onSecondaryContainer`

## Interactive Elements

### 1. Primary CTA (Call-to-Action)
Main action buttons that advance the user flow.

```dart
FilledButton(
  onPressed: () => handleAction(),
  style: FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(56),
    shape: const StadiumBorder(),
    backgroundColor: tokens.main.primary,
    foregroundColor: tokens.main.onPrimary,
    textStyle: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
  ),
  child: const Text('Continue'),
)
```

**Properties:**
- Background: `tokens.main.primary`
- Foreground: `tokens.main.onPrimary`
- Shape: `StadiumBorder()` (pill-shaped)
- Height: `56dp`
- Text Style: `titleMedium` with `fontWeight: w700`

### 2. Secondary CTA
OAuth buttons (Google, Apple) and alternative actions.

**Google Button Example:**
```dart
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: isDark
        ? tokens.main.inverseSurface
        : tokens.main.surfaceContainerLowest,
    foregroundColor: isDark
        ? tokens.main.inverseOnSurface
        : tokens.main.onSurface,
    minimumSize: const Size.fromHeight(AppButtonSize.extraLargeHeight),
    padding: AppButtonSize.extraLargePadding,
    shape: const StadiumBorder(),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SvgPicture.asset(
        'assets/icons/google.svg',
        width: AppIconSize.sm,
        height: AppIconSize.sm,
        colorFilter: ColorFilter.mode(
          isDark ? tokens.main.inverseOnSurface : tokens.main.onSurface,
          BlendMode.srcIn,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text('Continue with Google'),
    ],
  ),
)
```

### 3. Text Buttons
Tertiary actions, navigation links, and low-emphasis interactions.

```dart
TextButton(
  onPressed: () => navigate(),
  child: Text(
    'Already have an account? Log in',
    style: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: tokens.main.primary,
    ),
  ),
)
```

**Properties:**
- Text Color: `tokens.main.primary`
- Text Style: `titleMedium` with `fontWeight: w700`

## Input Fields

### Email/Text Input Fields

All input fields in auth/onboarding screens follow a consistent pill-shaped design:

```dart
Widget _buildEmailInputPill(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final borderRadius = BorderRadius.circular(999);

  return Form(
    key: _formKey,
    child: TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.done,
      onChanged: _onEmailChanged,
      validator: _validateEmail,
      style: theme.textTheme.titleMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'email@domain.com',
        hintStyle: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
    ),
  );
}
```

**Properties:**
- **Border Radius:** `999` (pill-shaped)
- **Text Style:** `titleMedium` with `fontWeight: w500`
- **Text Color:** `colorScheme.onSurface`
- **Hint Style:** `titleMedium` with `fontWeight: w500`
- **Hint Color:** `colorScheme.onSurfaceVariant`
- **Fill Color:** `colorScheme.surface`
- **Content Padding:** `EdgeInsets.symmetric(horizontal: 22, vertical: 16)`

**Border States:**
- **Default Border:** `BorderSide.none`
- **Enabled Border:** `colorScheme.outlineVariant` (1px)
- **Focused Border:** `colorScheme.primary` (2px width)
- **Error Border:** `colorScheme.error` (1px)
- **Focused Error Border:** `colorScheme.error` (2px width)

**Field Configuration:**
- Always use `filled: true`
- Apply appropriate `keyboardType` (e.g., `TextInputType.emailAddress`)
- Include `autofillHints` for better UX
- Set `textInputAction` based on context (e.g., `TextInputAction.done`)
- Implement validation with `validator` callback

### OTP Input Fields

For OTP/PIN verification screens, use individual digit fields:

```dart
TextField(
  controller: _otpControllers[index],
  focusNode: _focusNodes[index],
  keyboardType: TextInputType.number,
  textAlign: TextAlign.center,
  maxLength: 6,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  style: theme.textTheme.headlineMedium?.copyWith(
    fontWeight: FontWeight.w700,
    color: tokens.main.onSurface,
  ),
  decoration: InputDecoration(
    counterText: '',
    filled: true,
    fillColor: tokens.main.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: tokens.main.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: tokens.main.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
  ),
)
```

**Properties:**
- **Border Radius:** `16` (rounded square)
- **Text Style:** `headlineMedium` with `fontWeight: w700`
- **Text Alignment:** `TextAlign.center`
- **Size:** `56x56` dp
- **Max Length:** `6` characters
- **Input Filter:** Digits only
- **Fill Color:** `tokens.main.surface`
- **Border Colors:** Same as standard input fields

### Checkboxes

For consent and opt-in interactions:

```dart
Checkbox(
  value: _keepInLoop,
  onChanged: (v) => setState(() => _keepInLoop = v ?? false),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
  ),
  activeColor: colorScheme.primary,
  checkColor: colorScheme.onPrimary,
  side: BorderSide(color: colorScheme.primary, width: 2),
)
```

**Properties:**
- **Shape:** `RoundedRectangleBorder` with `borderRadius: 6`
- **Active Color:** `colorScheme.primary`
- **Check Color:** `colorScheme.onPrimary`
- **Border:** `colorScheme.primary` (2px width)

## Spacing Standards

Use consistent spacing throughout:

- `AppSpacing.xs` (4dp): Container padding
- `AppSpacing.sm` (8dp): Tight element spacing
- `AppSpacing.md` (12dp): Standard element spacing
- `AppSpacing.lg` (16dp): Section spacing
- `AppSpacing.xl` (20dp): Large section spacing
- `AppSpacing.xxl` (24dp): Content padding
- `AppSpacing.xxxl` (32dp): Screen section separation

## Border Radius

- Input fields (pill): `BorderRadius.circular(999)`
- Cards/Containers: `AppRadius.extraExtraLarge`
- Small elements: `AppRadius.medium`

## Color Usage

**Always use tokens, never hardcoded colors:**

✅ **Correct:**
```dart
color: tokens.main.onSecondaryContainer
backgroundColor: tokens.main.primary
```

❌ **Incorrect:**
```dart
color: Colors.white
backgroundColor: Color(0xFF6200EE)
color: colorScheme.onSurface // Use tokens instead
```

## Screen Layout Pattern

All auth/onboarding screens should follow this structure:

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

  return Scaffold(
    backgroundColor: tokens.main.background,
    body: Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: ClipRRect(
        borderRadius: AppRadius.extraExtraLarge,
        child: DecoratedBox(
          decoration: BoxDecoration(color: tokens.main.secondaryContainer),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Screen title (displayMedium)
                            // Headline (headlineSmall)
                            // Paragraph (bodyMedium)
                            // Input fields
                            // Primary CTA
                            const Spacer(),
                            // Secondary actions
                            // Text buttons
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
```

## Reference Implementations

See these files for complete examples:
- `lib/features/auth_onboarding/presentation/screens/auth_welcome_screen.dart`
- `lib/features/auth_onboarding/presentation/screens/email_input_screen.dart`
- `lib/features/auth_onboarding/presentation/screens/otp_verification_screen.dart`

## Token References

Import tokens at the top of each screen:
```dart
import 'package:dabbler/design_system/tokens/main_dark.dart' as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart' as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart';
```

---

**Last Updated:** February 1, 2026  
**Status:** Active - All auth/onboarding screens must follow this guide
