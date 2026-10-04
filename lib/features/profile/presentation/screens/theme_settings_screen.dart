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

const _kModes = <(String, String, ThemeMode, String)>[
  ('Light', 'Always use light theme', ThemeMode.light, 'sun-1'),
  ('Dark', 'Always use dark theme', ThemeMode.dark, 'moon'),
  ('System', 'Follow device settings', ThemeMode.system, 'mobile'),
];

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Theme & Appearance',
        border: true,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: AnimatedBuilder(
        animation: _themeService,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space5,
              DabblerSpacing.space6,
              DabblerSpacing.space5,
              DabblerSpacing.space10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildThemeModeSection(),
                const DabblerGap.v(DabblerSpacing.space6),
                _buildThemeCategorySection(),
                const DabblerGap.v(DabblerSpacing.space6),
                _buildAutoThemeSection(),
                if (_themeService.autoThemeEnabled) ...[
                  const DabblerGap.v(DabblerSpacing.space6),
                  _buildTimeScheduleSection(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeModeSection() {
    final current = _kModes.firstWhere(
      (m) => m.$3 == _themeService.themeMode,
      orElse: () => _kModes.last,
    );
    return DabblerRowGroup(
      header: 'Theme Mode',
      note: _themeService.autoThemeEnabled
          ? 'Choose how the app should appear'
          : current.$2,
      children: [
        DabblerTabs(
          variant: DabblerTabsVariant.segmented,
          label: 'Theme Mode',
          fullWidth: true,
          // No mode is highlighted while the time-based theme is on.
          allowNoSelection: true,
          value: _themeService.autoThemeEnabled ? null : current.$3.name,
          items: [
            for (final m in _kModes)
              DabblerTabItem(
                id: m.$3.name,
                label: m.$1,
                icon: DabblerIcon(m.$4),
              ),
          ],
          onChanged: (id) {
            final mode = _kModes.firstWhere((m) => m.$3.name == id).$3;
            _themeService.setAutoThemeEnabled(false);
            _themeService.setThemeMode(mode);
          },
        ),
      ],
    );
  }

  Widget _buildThemeCategorySection() {
    return DabblerRowGroup(
      header: 'Color Theme',
      note: 'Apply one token set across the entire app',
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
      flat: true,
      showDivider: false,
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
    return DabblerColorDots(
      colors: [preview.brandPrimary, preview.accent, preview.surfaceGrey],
    );
  }

  DabblerColors _previewFor(String category) => DabblerColors.resolve(
    theme: ThemeCategories.dabblerThemeFor(category),
    brightness: _themeService.currentBrightness,
  );

  Widget _buildAutoThemeSection() {
    final colors = DabblerColors.of(context);
    return DabblerRowGroup(
      header: 'Automatic Theme',
      note: 'Automatically switch between light and dark themes',
      children: [
        DabblerInputRow(
          flat: true,
          showDivider: false,
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
    return DabblerRowGroup(
      header: 'Day & Night Schedule',
      note: 'Set when light and dark themes should activate',
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
      flat: true,
      showDivider: false,
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
