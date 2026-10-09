import 'package:dabbler/core/services/theme_categories.dart';
import 'package:dabbler/core/services/theme_service.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings/settings_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show ThemeMode, TimeOfDay;
import 'package:flutter/widgets.dart';

/// Appearance — `Settings.dc.html` route `appearance`: the light / dark /
/// system segments. The colour theme and the time-based schedule are features
/// the frame does not draw; they follow with the design system's defaults.
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

const _kModes = <(ThemeMode, String)>[
  (ThemeMode.light, 'sun-1'),
  (ThemeMode.dark, 'moon'),
  (ThemeMode.system, 'mobile'),
];

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final ThemeService _themeService = ThemeService();

  String _modeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.light => l10n.appr_light,
    ThemeMode.dark => l10n.appr_dark,
    ThemeMode.system => l10n.appr_system,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerPage(
      topBar: settingsTopBar(
        context,
        title: l10n.appr_title,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: AnimatedBuilder(
        animation: _themeService,
        builder: (context, child) {
          return ListView(
            padding: kSettingsBodyPadding,
            children: [
              _buildThemeModeSection(l10n),
              kSettingsGroupGap,
              _buildThemeCategorySection(l10n),
              kSettingsGroupGap,
              _buildAutoThemeSection(l10n),
              if (_themeService.autoThemeEnabled) ...[
                kSettingsGroupGap,
                _buildTimeScheduleSection(l10n),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeModeSection(AppLocalizations l10n) {
    return DabblerRowGroup.stack(
      header: l10n.appr_group_theme,
      children: [
        DabblerOptionSegments(
          semanticLabel: l10n.appr_group_theme,
          // No mode is highlighted while the time-based theme is on.
          value: _themeService.autoThemeEnabled
              ? null
              : _themeService.themeMode.name,
          items: [
            for (final m in _kModes)
              DabblerOptionSegment(
                id: m.$1.name,
                label: _modeLabel(l10n, m.$1),
                icon: m.$2,
              ),
          ],
          onChanged: (id) {
            final mode = _kModes.firstWhere((m) => m.$1.name == id).$1;
            _themeService.setAutoThemeEnabled(false);
            _themeService.setThemeMode(mode);
            DabblerToastProvider.of(context).show(
              DabblerToastSpec(
                message: l10n.appr_theme_applied(_modeLabel(l10n, mode)),
                tone: DabblerToastTone.success,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThemeCategorySection(AppLocalizations l10n) {
    return DabblerRowGroup(
      header: l10n.appr_group_color,
      note: l10n.appr_group_color_note,
      children: ThemeCategories.supported
          .map((c) => _buildThemeCategoryOption(l10n, c))
          .toList(growable: false),
    );
  }

  Widget _buildThemeCategoryOption(AppLocalizations l10n, String category) {
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
      subtitle: l10n.appr_color_use(name),
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

  Widget _buildAutoThemeSection(AppLocalizations l10n) {
    return DabblerRowGroup(
      header: l10n.appr_group_auto,
      note: l10n.appr_group_auto_note,
      children: [
        DabblerInputRow(
          flat: true,
          showDivider: false,
          leading: settingsRowIcon(context, 'clock'),
          // Opt-in (KAN-488): off reads "Match device", on describes the
          // time-of-day switching.
          title: l10n.appr_auto_switch_label,
          subtitle: _themeService.autoThemeEnabled
              ? l10n.appr_auto_sub
              : l10n.appr_auto_match_device,
          trailing: DabblerToggle(
            checked: _themeService.autoThemeEnabled,
            semanticLabel: l10n.appr_auto_switch_label,
            onChanged: (value) => _themeService.setAutoThemeEnabled(value),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeScheduleSection(AppLocalizations l10n) {
    return DabblerRowGroup(
      header: l10n.appr_group_schedule,
      note: l10n.appr_group_schedule_note,
      children: [
        _buildTimeOption(
          l10n.appr_day_title,
          l10n.appr_day_sub,
          _themeService.dayStartTime,
          (time) => _themeService.setDayStartTime(time),
        ),
        _buildTimeOption(
          l10n.appr_night_title,
          l10n.appr_night_sub,
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
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      onTap: () => _selectTime(title, time, onTimeChanged),
      leading: settingsRowIcon(context, 'sun-fog'),
      title: title,
      subtitle: subtitle,
      value: _themeService.formatTime(time),
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
      showCloseButton: false,
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
