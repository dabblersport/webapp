import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/design_system.dart';

/// Quick examples of using the token-based theme system

// Example 1: Basic theme application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dabbler',
      theme: TokenBasedTheme.build(AppThemeMode.mainLight),
      darkTheme: TokenBasedTheme.build(AppThemeMode.mainDark),
      home: const Scaffold(body: Center(child: Text('Home Screen'))),
    );
  }
}

// Example 2: Dynamic theme switching
class ThemeSwitcher extends StatefulWidget {
  const ThemeSwitcher({super.key});

  @override
  State<ThemeSwitcher> createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<ThemeSwitcher> {
  AppThemeMode _currentTheme = AppThemeMode.mainLight;

  void _switchTheme(String category, bool isDark) {
    setState(() {
      switch (category) {
        case 'main':
          _currentTheme = isDark
              ? AppThemeMode.mainDark
              : AppThemeMode.mainLight;
          break;
        case 'social':
          _currentTheme = isDark
              ? AppThemeMode.socialDark
              : AppThemeMode.socialLight;
          break;
        case 'sports':
          _currentTheme = isDark
              ? AppThemeMode.sportsDark
              : AppThemeMode.sportsLight;
          break;
        case 'activities':
          _currentTheme = isDark
              ? AppThemeMode.activitiesDark
              : AppThemeMode.activitiesLight;
          break;
        case 'profile':
          _currentTheme = isDark
              ? AppThemeMode.profileDark
              : AppThemeMode.profileLight;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TokenBasedTheme.build(_currentTheme),
      child: Scaffold(
        appBar: AppBar(title: const Text('Theme Switcher')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _switchTheme('main', false),
                child: const Text('Main Light'),
              ),
              ElevatedButton(
                onPressed: () => _switchTheme('social', false),
                child: const Text('Social Light'),
              ),
              ElevatedButton(
                onPressed: () => _switchTheme('sports', true),
                child: const Text('Sports Dark'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Example 3: Using color tokens directly
class TokenColorExample extends StatelessWidget {
  const TokenColorExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Access tokens via theme mode
    final tokens = AppThemeMode.mainLight.colorTokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.base,
        border: Border.all(color: tokens.stroke),
      ),
      child: Column(
        children: [
          Container(
            color: tokens.header,
            padding: EdgeInsets.all(DesignTokens.spacingMd),
            child: Text(
              'Header',
              style: TextStyle(
                color: tokens.titleOnHead,
                fontSize: DesignTokens.fontSizeBase,
                fontWeight: DesignTokens.fontWeightBold,
              ),
            ),
          ),
          Container(
            color: tokens.section,
            padding: EdgeInsets.all(DesignTokens.spacingSm),
            child: Text(
              'Section',
              style: TextStyle(
                color: tokens.titleOnSec,
                fontSize: DesignTokens.fontSizeSm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Example 4: Using Material 3 ColorScheme (recommended)
class Material3Example extends StatelessWidget {
  const Material3Example({super.key});

  @override
  Widget build(BuildContext context) {
    // Access via Material 3 ColorScheme
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Primary button
        FilledButton(onPressed: () {}, child: const Text('Primary Action')),

        // Card with surface colors
        Card(
          child: Padding(
            padding: EdgeInsets.all(DesignTokens.spacingSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card Title', style: textTheme.titleMedium),
                SizedBox(height: DesignTokens.spacingXs),
                Text('Card body text', style: textTheme.bodyMedium),
              ],
            ),
          ),
        ),

        // Container with semantic colors
        Container(
          padding: EdgeInsets.all(DesignTokens.spacingMd),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Primary Container',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

// Example 5: Category-based theme routing
class CategoryRouter extends StatelessWidget {
  final String category; // 'main', 'social', 'sports', 'activities', 'profile'
  final bool isDarkMode;
  final Widget child;

  const CategoryRouter({
    super.key,
    required this.category,
    required this.isDarkMode,
    required this.child,
  });

  AppThemeMode _getThemeMode() {
    switch (category) {
      case 'social':
        return isDarkMode ? AppThemeMode.socialDark : AppThemeMode.socialLight;
      case 'sports':
        return isDarkMode ? AppThemeMode.sportsDark : AppThemeMode.sportsLight;
      case 'activities':
        return isDarkMode
            ? AppThemeMode.activitiesDark
            : AppThemeMode.activitiesLight;
      case 'profile':
        return isDarkMode
            ? AppThemeMode.profileDark
            : AppThemeMode.profileLight;
      default:
        return isDarkMode ? AppThemeMode.mainDark : AppThemeMode.mainLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: TokenBasedTheme.build(_getThemeMode()), child: child);
  }
}

// Example 6: Responsive spacing
class ResponsiveSpacing extends StatelessWidget {
  const ResponsiveSpacing({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingMd,
        vertical: DesignTokens.spacingSm,
      ),
      child: Column(
        children: [
          // Consistent spacing throughout
          SizedBox(height: DesignTokens.spacingLg),
          Text('Title', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: DesignTokens.spacingXs),
          Text('Subtitle', style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: DesignTokens.spacingMd),
          // Content
        ],
      ),
    );
  }
}

// Example 7: All themes at once (for testing/preview)
class AllThemesPreview extends StatelessWidget {
  const AllThemesPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final allThemes = TokenBasedTheme.getAllThemes();

    return ListView(
      children: allThemes.entries.map((entry) {
        return Theme(
          data: entry.value,
          child: Card(
            child: ListTile(
              title: Text(entry.key.name),
              subtitle: Text('Category: ${entry.key.category}'),
              tileColor: entry.value.colorScheme.surface,
              textColor: entry.value.colorScheme.onSurface,
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.value.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
