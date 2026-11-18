// KAN-999 (G-05 "editing a row"): Mark attended / Mark no-show plus a reason
// the player sees. The reason is required; Save calls the server and closes
// only on success. A refusal stays in the sheet with its message.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/attendance/data/attendance_review_repository.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart'
    show AttendanceCall, attendanceRefusalText, attendanceToast;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

typedef AttendanceSave =
    Future<Failure?> Function(AttendanceMark mark, String reason);

Future<void> showAttendanceCorrectSheet({
  required BuildContext context,
  required AttendanceRow row,
  required AttendanceSave onSave,
}) {
  final l = AppLocalizations.of(context);
  return showDabblerSheet<void>(
    context: context,
    title: l.g05_edit_title,
    detent: DabblerSheetDetent.content,
    builder: (_) => AttendanceCorrectSheet(row: row, onSave: onSave),
  );
}

class AttendanceCorrectSheet extends StatefulWidget {
  const AttendanceCorrectSheet({
    super.key,
    required this.row,
    required this.onSave,
  });

  final AttendanceRow row;
  final AttendanceSave onSave;

  @override
  State<AttendanceCorrectSheet> createState() => _AttendanceCorrectSheetState();
}

class _AttendanceCorrectSheetState extends State<AttendanceCorrectSheet> {
  late AttendanceMark _mark =
      widget.row.status == AttendanceRowStatus.notCheckedIn ||
          widget.row.status == AttendanceRowStatus.correctedNoShow
      ? AttendanceMark.attended
      : AttendanceMark.noShow;
  final TextEditingController _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = l.g05_reason_required);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final f = await widget.onSave(_mark, _reason.text);
    if (!mounted) return;
    if (f == null) {
      attendanceToast(context, l.g05_saved);
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      if (f.code != 'busy')
        _error = attendanceRefusalText(
          l,
          AttendanceCall.correct,
          f,
          l.g05_failed,
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = widget.row.displayName ?? l.g05_unknown_player;
    Widget option(AttendanceMark m, String label) => DabblerRadio(
      key: ValueKey<String>('attendance-mark-${m.wire}'),
      selected: _mark == m,
      label: label,
      disabled: _saving,
      onChanged: (_) => setState(() => _mark = m),
    );
    return DabblerSheetBody(
      actions: DabblerSheetActions(
        children: <Widget>[
          DabblerButton(
            key: const ValueKey<String>('attendance-save'),
            label: l.g05_save,
            fullWidth: true,
            size: DabblerButtonSize.full,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      children: <Widget>[
        DabblerText(context.isolate(name), style: DabblerType.headline),
        option(AttendanceMark.attended, l.g05_mark_attended),
        option(AttendanceMark.noShow, l.g05_mark_no_show),
        DabblerTextField(
          key: const ValueKey<String>('attendance-reason'),
          variant: DabblerTextFieldVariant.multiline,
          controller: _reason,
          label: l.g05_reason_label,
          helperText: l.g05_reason_hint,
          errorText: _error,
          enabled: !_saving,
          rows: 3,
        ),
      ],
    );
  }
}
