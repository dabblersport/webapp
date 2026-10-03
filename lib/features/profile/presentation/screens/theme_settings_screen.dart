import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show ThemeMode, TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/services/theme_categories.dart';
import 'package:dabbler/core/services/theme_service.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

const _kModes = <(String, String, ThemeMode)>[
  ('Light', 'Always use light theme', ThemeMode.light),
  ('Dark', 'Always use dark theme', ThemeMode.dark),
  ('System', 'Follow device settings', ThemeMode.system),
];

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Theme & Appearance',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: AnimatedBuilder(
        animation: _themeService,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DabblerSpacing.space6,
              DabblerSpacing.space4,
              DabblerSpacing.space6,
              DabblerSpacing.space11,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                const SizedBox(height: DabblerSpacing.space6),
                _buildCurrentThemeStatus(),
                const SizedBox(height: DabblerSpacing.space6),
                _buildThemeModeSection(),
                const SizedBox(height: DabblerSpacing.space6),
                _buildThemeCategorySection(),
                const SizedBox(height: DabblerSpacing.space6),
                _buildAutoThemeSection(),
                if (_themeService.autoThemeEnabled) ...[
                  const SizedBox(height: DabblerSpacing.space6),
                  _buildTimeScheduleSection(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _isDark => _themeService.currentBrightness == Brightness.dark;

  Widget _buildHero() {
    final colors = DabblerColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: DabblerRadius.xlAll,
        border: Border.all(color: colors.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerIcon(
              _isDark ? 'moon' : 'sun-1',
              size: DabblerSizing.tileLg,
              color: colors.brandPrimary,
            ),
            const SizedBox(height: DabblerSpacing.space5),
            DabblerText('Customize your theme', style: DabblerType.title2),
            const SizedBox(height: DabblerSpacing.space3),
            DabblerText(
              'Choose how the app should look and when themes should automatically switch.',
              style: DabblerType.subheadline,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentThemeStatus() {
    final colors = DabblerColors.of(context);
    return DabblerInputRow(
      leading: DabblerIcon(
        _isDark ? 'moon' : 'sun-1',
        size: DabblerSizing.iconMd,
        color: colors.brandPrimary,
      ),
      title: 'Current Theme',
      subtitle: _themeService.getThemeDescription(),
    );
  }

  Widget _buildThemeModeSection() {
    final current = _kModes.firstWhere(
      (m) => m.$3 == _themeService.themeMode,
      orElse: () => _kModes.last,
    );
    return DabblerSection(
      title: 'Theme Mode',
      subtitle: 'Choose how the app should appear',
      children: [
        DabblerTabs(
          variant: DabblerTabsVariant.segmented,
          label: 'Theme Mode',
          // No mode is highlighted while the time-based theme is on.
          allowNoSelection: true,
          value: _themeService.autoThemeEnabled ? null : current.$3.name,
          items: [
            for (final m in _kModes) DabblerTabItem(id: m.$3.name, label: m.$1),
          ],
          onChanged: (id) {
            final mode = _kModes.firstWhere((m) => m.$3.name == id).$3;
            _themeService.setAutoThemeEnabled(false);
            _themeService.setThemeMode(mode);
          },
        ),
        if (!_themeService.autoThemeEnabled)
          DabblerText(
            current.$2,
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
      ],
    );
  }

  Widget _buildThemeCategorySection() {
    return DabblerSection(
      title: 'Color Theme',
      subtitle: 'Apply one token set across the entire app',
      children: ThemeCategories.supported
          .map(_buildThemeCategoryOption)
          .toList(growable: false),
    );
  }

  Widget _buildThemeCategoryOption(String category) {
    final normalized = ThemeCategories.normalize(category);
    final isSelected = _themeService.themeCategory == normalized;
    final colors = DabblerColors.of(context);
    final name = ThemeService.getThemeCategoryDisplayName(normalized);

    return DabblerInputRow(
      onTap: () => _themeService.setThemeCategory(normalized),
      leading: _buildThemePreviewSwatches(_previewFor(normalized)),
      title: name,
      subtitle: 'Use $name tokens app-wide',
      trailing: isSelected
          ? DabblerIcon(
              'tick-circle',
              weight: DabblerIconWeight.bold,
              size: DabblerSizing.iconMd,
              color: colors.brandPrimary,
            )
          : null,
    );
  }

  /// The swatches preview another category's palette, so their colours come
  /// from that category's design-system theme rather than the active tokens.
  Widget _buildThemePreviewSwatches(DabblerColors preview) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(preview.brandPrimary),
        const SizedBox(width: DabblerSpacing.space2),
        _dot(preview.accent),
        const SizedBox(width: DabblerSpacing.space2),
        _dot(preview.surfaceGrey),
      ],
    );
  }

  Widget _dot(Color color) => SizedBox(
    width: DabblerSizing.swatch,
    height: DabblerSizing.swatch,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );

  DabblerColors _previewFor(String category) => DabblerColors.resolve(
    theme: ThemeCategories.dabblerThemeFor(category),
    brightness: _themeService.currentBrightness,
  );

  Widget _buildAutoThemeSection() {
    final colors = DabblerColors.of(context);
    return DabblerSection(
      title: 'Automatic Theme',
      subtitle: 'Automatically switch between light and dark themes',
      children: [
        DabblerInputRow(
          leading: DabblerIcon(
            'clock',
            size: DabblerSizing.iconMd,
            color: _themeService.autoThemeEnabled
                ? colors.brandPrimary
                : colors.textSecondary,
          ),
          title: 'Time-based Theme',
          subtitle: 'Switch themes based on time of day',
          trailing: DabblerToggle(
            checked: _themeService.autoThemeEnabled,
            semanticLabel: 'Time-based Theme',
            onChanged: (value) => _themeService.setAutoThemeEnabled(value),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeScheduleSection() {
    return DabblerSection(
      title: 'Day & Night Schedule',
      subtitle: 'Set when light and dark themes should activate',
      children: [
        _buildTimeOption(
          'Day starts at',
          'Light theme will activate',
          _themeService.dayStartTime,
          (time) => _themeService.setDayStartTime(time),
        ),
        _buildTimeOption(
          'Night starts at',
          'Dark theme will activate',
          _themeService.nightStartTime,
          (time) => _themeService.setNightStartTime(time),
        ),
      ],
    );
  }

  Widget _buildTimeOption(
    String title,
    String subtitle,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onTimeChanged,
  ) {
    final colors = DabblerColors.of(context);
    return DabblerInputRow(
      onTap: () => _selectTime(title, time, onTimeChanged),
      leading: DabblerIcon(
        'sun-fog',
        size: DabblerSizing.iconMd,
        color: colors.brandPrimary,
      ),
      title: title,
      subtitle: subtitle,
      trailing: DabblerText(
        _themeService.formatTime(time),
        style: DabblerType.headline,
        tone: DabblerTextTone.brand,
      ),
    );
  }

  Future<void> _selectTime(
    String title,
    TimeOfDay currentTime,
    ValueChanged<TimeOfDay> onTimeChanged,
  ) async {
    final time = await showDabblerSheet<TimeOfDay>(
      context: context,
      title: title,
      detent: DabblerSheetDetent.content,
      builder: (_) => _TimeSheet(initial: currentTime),
    );
    if (time != null) onTimeChanged(time);
  }
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial});

  final TimeOfDay initial;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late TimeOfDay _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return DabblerTimePicker(
      value: _value,
      minuteStep: 1,
      onChanged: (t) => setState(() => _value = t),
      onConfirm: () => Navigator.pop(context, _value),
      onCancel: () => Navigator.pop(context),
    );
  }
}
