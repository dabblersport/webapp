// KAN-991: the rows and helpers the notification settings sections share.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Minutes after local midnight as a clock time in the device's 12/24-hour
/// setting (`MediaQuery.alwaysUse24HourFormat`, decision I-7), Western digits.
String notifSettingsClock(BuildContext context, int minutes) {
  final String locale = Localizations.localeOf(context).toLanguageTag();
  final DateTime at = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
  final DateFormat f = MediaQuery.alwaysUse24HourFormatOf(context)
      ? DateFormat.Hm(locale)
      : DateFormat.jm(locale);
  return DabblerType.toWesternDigits(f.format(at));
}

/// One switch row: icon, title, subtitle, toggle. [disabled] greys the toggle
/// and ignores taps.
class NotifSettingsSwitchRow extends StatelessWidget {
  const NotifSettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  final String title;
  final String? subtitle;

  /// DS icon name rendered through [DabblerIcon].
  final String? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      dense: true,
      title: title,
      subtitle: subtitle,
      enabled: !disabled,
      onTap: disabled ? null : () => onChanged(!value),
      leading: icon == null
          ? null
          : DabblerIcon(
              icon!,
              size: DabblerSizing.iconMd,
              color: colors.textSecondary,
            ),
      trailing: DabblerToggle(
        checked: value,
        onChanged: disabled ? null : onChanged,
        disabled: disabled,
        semanticLabel: title,
      ),
    );
  }
}

/// A toggle with its channel label above it ("In-app", "Push"), for the
/// category table.
class NotifSettingsChannelToggle extends StatelessWidget {
  const NotifSettingsChannelToggle({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  final String label;
  final String semanticLabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DabblerText(
          label,
          style: DabblerType.caption2,
          tone: DabblerTextTone.secondary,
        ),
        const SizedBox(height: DabblerSpacing.space1),
        DabblerToggle(
          checked: value,
          onChanged: disabled ? null : onChanged,
          disabled: disabled,
          semanticLabel: semanticLabel,
        ),
      ],
    );
  }
}

/// A secondary note under a section.
class NotifSettingsNote extends StatelessWidget {
  const NotifSettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space2,
        vertical: DabblerSpacing.space2,
      ),
      child: DabblerText(
        text,
        style: DabblerType.caption1,
        tone: DabblerTextTone.secondary,
      ),
    );
  }
}
