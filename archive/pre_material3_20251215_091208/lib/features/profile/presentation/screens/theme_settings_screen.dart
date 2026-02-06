import 'package:flutter/material.dart';
import 'package:dabbler/core/services/theme_service.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _themeService,
          builder: (context, child) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Header
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  sliver: SliverToBoxAdapter(child: _buildHeader(context)),
                ),
                // Hero Card
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(child: _buildHeroCard(context)),
                ),
                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildCurrentThemeStatus(),
                        const SizedBox(height: 20),
                        _buildThemeModeSection(),
                        const SizedBox(height: 20),
                        _buildAutoThemeSection(),
                        if (_themeService.autoThemeEnabled) ...[
                          const SizedBox(height: 20),
                          _buildTimeScheduleSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme & Appearance',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = _themeService.currentBrightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF4A148C) : const Color(0xFFE0C7FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDark ? Icons.nightlight_round : Icons.wb_sunny,
            size: 48,
            color: isDark ? Colors.white : Colors.black87,
          ),
          const SizedBox(height: 16),
          Text(
            'Customize your theme',
            style: textTheme.headlineSmall?.copyWith(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose how the app should look and when themes should automatically switch.',
            style: textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? Colors.white.withOpacity(0.85)
                  : Colors.black.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentThemeStatus() {
    final isDark = _themeService.currentBrightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny,
                size: 24,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Theme',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _themeService.getThemeDescription(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeSection() {
    return _buildSettingsCard(
      'Theme Mode',
      'Choose how the app should appear',
      [
        _buildThemeModeOption(
          'Light',
          'Always use light theme',
          Icons.wb_sunny,
          ThemeMode.light,
        ),
        _buildThemeModeOption(
          'Dark',
          'Always use dark theme',
          Icons.nightlight_round,
          ThemeMode.dark,
        ),
        _buildThemeModeOption(
          'System',
          'Follow device settings',
          Icons.computer,
          ThemeMode.system,
        ),
      ],
    );
  }

  Widget _buildAutoThemeSection() {
    return _buildSettingsCard(
      'Automatic Theme',
      'Automatically switch between light and dark themes',
      [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _themeService.autoThemeEnabled
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _themeService.autoThemeEnabled
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 20,
                color: _themeService.autoThemeEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time-based Theme',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Switch themes based on time of day',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _themeService.autoThemeEnabled,
                onChanged: (value) {
                  _themeService.setAutoThemeEnabled(value);
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeScheduleSection() {
    return _buildSettingsCard(
      'Day & Night Schedule',
      'Set when light and dark themes should activate',
      [
        _buildTimeOption(
          'Day starts at',
          'Light theme will activate',
          Icons.wb_twilight,
          _themeService.dayStartTime,
          (time) => _themeService.setDayStartTime(time),
        ),
        const SizedBox(height: 12),
        _buildTimeOption(
          'Night starts at',
          'Dark theme will activate',
          Icons.wb_twilight,
          _themeService.nightStartTime,
          (time) => _themeService.setNightStartTime(time),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    String title,
    String subtitle,
    List<Widget> children,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeOption(
    String title,
    String subtitle,
    IconData icon,
    ThemeMode mode,
  ) {
    final isSelected =
        _themeService.themeMode == mode && !_themeService.autoThemeEnabled;

    return GestureDetector(
      onTap: () {
        _themeService.setAutoThemeEnabled(false);
        _themeService.setThemeMode(mode);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOption(
    String title,
    String subtitle,
    IconData icon,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
  ) {
    return GestureDetector(
      onTap: () => _selectTime(time, onTimeChanged),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _themeService.formatTime(time),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(
    TimeOfDay currentTime,
    Function(TimeOfDay) onTimeChanged,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              dialBackgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialTextColor: Theme.of(context).textTheme.bodyLarge?.color,
              entryModeIconColor: Theme.of(context).colorScheme.primary,
              hourMinuteTextColor: Theme.of(context).colorScheme.primary,
              dayPeriodTextColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      onTimeChanged(time);
    }
  }
}
