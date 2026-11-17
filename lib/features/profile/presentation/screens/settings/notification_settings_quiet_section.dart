// KAN-991 (G-09, F-14, I-2, I-3, I-7): the quiet hours editor. A toggle,
// From and To in the device's 12/24-hour format, a note on what still
// alerts, and Save. Start equal to end is invalid and blocks Save. Turning it
// on with no window starts from 00:00 – 08:00. The server default stays off
// until KAN-979 delivers pushes silently.

import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings_keys.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';

import 'notification_settings_rows.dart';

class NotificationSettingsQuietSection extends StatefulWidget {
  const NotificationSettingsQuietSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final NotificationSettings settings;
  final NotificationSettingsController controller;

  @override
  State<NotificationSettingsQuietSection> createState() =>
      _NotificationSettingsQuietSectionState();
}

class _NotificationSettingsQuietSectionState
    extends State<NotificationSettingsQuietSection> {
  late bool _on;
  late int _start;
  late int _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant NotificationSettingsQuietSection old) {
    super.didUpdateWidget(old);
    final bool changed =
        old.settings.quietStartMin != widget.settings.quietStartMin ||
        old.settings.quietEndMin != widget.settings.quietEndMin;
    if (changed) _reset();
  }

  void _reset() {
    final NotificationSettings s = widget.settings;
    _on = s.hasQuietHours;
    _start = s.quietStartMin ?? kQuietDefaultStartMin;
    _end = s.quietEndMin ?? kQuietDefaultEndMin;
  }

  bool get _invalid => _on && _start == _end;

  bool get _dirty {
    final NotificationSettings s = widget.settings;
    if (_on != s.hasQuietHours) return true;
    return _on && (_start != s.quietStartMin || _end != s.quietEndMin);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final QuietHoursSave outcome = await widget.controller.saveQuietHours(
      enabled: _on,
      startMin: _start,
      endMin: _end,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome == QuietHoursSave.saved) {
      DabblerToastProvider.of(context).show(
        DabblerToastSpec(
          message: AppLocalizations.of(context).notif_settings_quiet_saved,
          tone: DabblerToastTone.success,
        ),
      );
    }
  }

  void _pick(String title, int minutes, ValueChanged<int> onPicked) {
    unawaited(
      showAppSheet<void>(
        context: context,
        title: title,
        detent: DabblerSheetDetent.content,
        builder: (_) => _QuietTimeSheet(
          initial: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
          onPicked: (TimeOfDay t) => onPicked(t.hour * 60 + t.minute),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String from = notifSettingsClock(context, _start);
    final String to = notifSettingsClock(context, _end);
    return DabblerRowGroup(
      header: l10n.notif_settings_quiet_header,
      children: [
        NotifSettingsSwitchRow(
          key: const ValueKey<String>('notif-quiet-toggle'),
          title: l10n.notif_quiet_hours_title,
          subtitle: _on
              ? l10n.notif_settings_quiet_toggle_on(from, to)
              : l10n.notif_settings_quiet_toggle_off,
          icon: 'moon',
          value: _on,
          onChanged: (bool on) => setState(() => _on = on),
        ),
        if (_on) ...[
          _timeRow(
            context,
            key: 'from',
            label: l10n.notif_settings_quiet_from,
            value: from,
            onTap: () => _pick(
              l10n.notif_settings_quiet_from,
              _start,
              (int m) => setState(() => _start = m),
            ),
          ),
          _timeRow(
            context,
            key: 'to',
            label: l10n.notif_settings_quiet_to,
            value: to,
            onTap: () => _pick(
              l10n.notif_settings_quiet_to,
              _end,
              (int m) => setState(() => _end = m),
            ),
          ),
          if (_invalid)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: DabblerSpacing.space2,
              ),
              child: DabblerText(
                l10n.notif_settings_quiet_invalid,
                key: const ValueKey<String>('notif-quiet-invalid'),
                style: DabblerType.caption1,
                tone: DabblerTextTone.error,
              ),
            ),
        ],
        NotifSettingsNote(l10n.notif_settings_quiet_note),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space2),
          child: DabblerButton(
            key: const ValueKey<String>('notif-quiet-save'),
            label: l10n.notif_settings_quiet_save,
            size: DabblerButtonSize.small,
            onPressed: (_dirty && !_invalid && !_saving) ? _save : null,
          ),
        ),
      ],
    );
  }

  Widget _timeRow(
    BuildContext context, {
    required String key,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final DabblerColors colors = DabblerColors.of(context);
    return DabblerInputRow(
      key: ValueKey<String>('notif-quiet-$key'),
      flat: true,
      showDivider: false,
      dense: true,
      title: label,
      leading: DabblerIcon(
        'clock',
        size: DabblerSizing.iconMd,
        color: colors.textSecondary,
      ),
      value: value,
      onTap: onTap,
    );
  }
}

/// The DS time picker in a sheet. It has hour, minute and AM/PM columns only;
/// a 24-hour mode is a design-system change (KAN-991 report).
class _QuietTimeSheet extends StatefulWidget {
  const _QuietTimeSheet({required this.initial, required this.onPicked});

  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  State<_QuietTimeSheet> createState() => _QuietTimeSheetState();
}

class _QuietTimeSheetState extends State<_QuietTimeSheet> {
  late TimeOfDay _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return DabblerTimePicker(
      value: _value,
      onChanged: (TimeOfDay t) => setState(() => _value = t),
      onConfirm: () {
        widget.onPicked(_value);
        Navigator.pop(context);
      },
      onCancel: () => Navigator.pop(context),
    );
  }
}
