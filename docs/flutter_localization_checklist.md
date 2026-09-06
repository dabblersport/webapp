# Flutter Localization Checklist — Arabic & English

> Use this checklist with Claude Code to audit your Flutter project before implementing Arabic/English localization.
> Mark each item as `[x]` done, `[-]` missing, or `[~]` not applicable.

---

## 1. pubspec.yaml Dependencies

- [ ] `flutter_localizations` SDK added
  - `flutter_localizations: sdk: flutter` under `dependencies:`
- [ ] `intl` package added
  - `intl: ^0.19.0` or latest
- [ ] `generate: true` flag set
  - Under `flutter:` section — enables ARB code generation
- [ ] `easy_localization` added *(if preferred over ARB)*
  - Alternative approach — pick one or the other, not both

---

## 2. l10n Configuration File

- [ ] `l10n.yaml` exists at project root
  - Required for `flutter gen-l10n` to work
- [ ] `arb-dir` points to `lib/l10n`
  - `arb-dir: lib/l10n`
- [ ] `template-arb-file` set to `app_en.arb`
  - `template-arb-file: app_en.arb`
- [ ] `output-localization-file` configured
  - `output-localization-file: app_localizations.dart`

---

## 3. ARB Translation Files

- [ ] `lib/l10n/` directory exists
  - Folder that holds all `.arb` files
- [ ] `app_en.arb` created (English)
  - `@@locale: en` + all string keys defined
- [ ] `app_ar.arb` created (Arabic)
  - `@@locale: ar` + all keys translated to Arabic
- [ ] All UI strings extracted to ARB keys
  - No hardcoded English or Arabic text remaining in widgets
- [ ] Plurals handled with ARB plural syntax
  - e.g. `{count, plural, one{item} other{items}}`

**Example `app_en.arb`:**
```json
{
  "@@locale": "en",
  "welcomeMessage": "Welcome",
  "loginButton": "Login",
  "emailHint": "Enter your email"
}
```

**Example `app_ar.arb`:**
```json
{
  "@@locale": "ar",
  "welcomeMessage": "مرحباً",
  "loginButton": "تسجيل الدخول",
  "emailHint": "أدخل بريدك الإلكتروني"
}
```

---

## 4. Code Generation

- [ ] `flutter gen-l10n` has been run
  ```bash
  flutter gen-l10n
  ```
- [ ] Generated files are excluded from git
  - Add `.dart_tool/flutter_gen` to `.gitignore`
- [ ] Build runs without l10n errors
  ```bash
  flutter build apk
  ```

---

## 5. MaterialApp Setup

- [ ] `localizationsDelegates` list added to `MaterialApp`
  - `AppLocalizations.localizationsDelegates` passed in
- [ ] `supportedLocales` includes both `Locale('en')` and `Locale('ar')`
- [ ] `AppLocalizations` imported in `main.dart`
  ```dart
  import 'package:flutter_gen/gen_l10n/app_localizations.dart';
  ```

**Example:**
```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: const [
    Locale('en'),
    Locale('ar'),
  ],
  home: MyHomePage(),
);
```

---

## 6. RTL (Right-to-Left) Support

- [ ] No hardcoded `TextDirection.ltr` in widgets
  - Breaks Arabic layout — let locale handle direction automatically
- [ ] Asymmetric padding uses `EdgeInsetsDirectional`
  - Use `EdgeInsetsDirectional` instead of `EdgeInsets` for start/end padding
- [ ] Directional icons are mirrored for RTL
  - Back arrow, forward arrow, etc. should flip in Arabic
- [ ] RTL layout tested in Flutter DevTools
  - Accessibility → Text Direction toggle
- [ ] No hardcoded `TextAlign.left`
  - Use `TextAlign.start` instead so it flips correctly in RTL

---

## 7. Language Switcher & Persistence

- [ ] State management solution chosen for locale
  - Provider, Riverpod, GetX, or Bloc — pick one
- [ ] `LocaleProvider` (or equivalent) implemented
  - Holds current `Locale` and notifies `MaterialApp` on change
- [ ] `shared_preferences` dependency added
  - For persisting the user's language choice across sessions
- [ ] Locale saved on change
  ```dart
  prefs.setString('locale', locale.languageCode);
  ```
- [ ] Saved locale loaded on app startup
  - Read prefs before `runApp` and set as initial locale

**Example provider:**
```dart
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
```

---

## 8. Fonts

- [ ] Arabic-compatible font added *(recommended)*
  - `Cairo`, `Tajawal`, or `Noto Sans Arabic` via `google_fonts` package
- [ ] Font declared in `pubspec.yaml` assets *(if bundled locally)*
  - Or using `google_fonts` package at runtime (no asset declaration needed)
- [ ] `TextTheme` updated to use the Arabic-friendly font
  - Applied via `ThemeData` so all text inherits it automatically

---

## 9. Testing & QA

- [ ] Widget tests provide localization delegates
  - Wrap test widgets in `MaterialApp` with `localizationsDelegates`
- [ ] Both locales manually tested on a device/emulator
  - Switch locale and verify layout does not break
- [ ] Long Arabic strings tested for overflow
  - Arabic text can be longer than English — test with real translations
- [ ] Date/number formatting is locale-aware
  - Use `intl`'s `DateFormat` and `NumberFormat` with locale parameter

---

## Quick Reference Commands

| Task | Command |
|---|---|
| Generate l10n code | `flutter gen-l10n` |
| Run app | `flutter run` |
| Build APK | `flutter build apk` |
| Add package | `flutter pub add <package>` |
| Get dependencies | `flutter pub get` |

---

## Progress Tracker

| Section | Status | Notes |
|---|---|---|
| pubspec.yaml dependencies | ⬜ | |
| l10n configuration file | ⬜ | |
| ARB translation files | ⬜ | |
| Code generation | ⬜ | |
| MaterialApp setup | ⬜ | |
| RTL support | ⬜ | |
| Language switcher & persistence | ⬜ | |
| Fonts | ⬜ | |
| Testing & QA | ⬜ | |

> ⬜ Not started &nbsp;|&nbsp; 🔄 In progress &nbsp;|&nbsp; ✅ Done &nbsp;|&nbsp; ➖ N/A
