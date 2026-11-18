// KAN-999 (G-06 "request sheet"): an optional note, then Send request. Closes
// (with true) only when the server accepted the request; a refusal stays in
// the sheet with its message.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart'
    show AttendanceCall, attendanceRefusalText;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

typedef ReviewSend = Future<Failure?> Function(String? note);

Future<bool?> showReviewRequestSheet({
  required BuildContext context,
  required ReviewSend onSend,
}) {
  final l = AppLocalizations.of(context);
  return showDabblerSheet<bool>(
    context: context,
    title: l.g06_sheet_title,
    detents: const <double>[0.9],
    builder: (_) => ReviewRequestSheet(onSend: onSend),
  );
}

class ReviewRequestSheet extends StatefulWidget {
  const ReviewRequestSheet({super.key, required this.onSend});

  final ReviewSend onSend;

  @override
  State<ReviewRequestSheet> createState() => _ReviewRequestSheetState();
}

class _ReviewRequestSheetState extends State<ReviewRequestSheet> {
  final TextEditingController _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    final f = await widget.onSend(_note.text);
    if (!mounted) return;
    if (f == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      if (f.code != 'busy')
        _error = attendanceRefusalText(
          l,
          AttendanceCall.requestReview,
          f,
          l.g06_failed,
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DabblerSheetBody(
      actions: DabblerSheetActions(
        children: <Widget>[
          DabblerButton(
            key: const ValueKey<String>('review-send'),
            label: l.g06_send,
            fullWidth: true,
            size: DabblerButtonSize.full,
            loading: _sending,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
      children: <Widget>[
        DabblerText(
          l.g06_sheet_body,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        DabblerTextField(
          key: const ValueKey<String>('review-note'),
          variant: DabblerTextFieldVariant.multiline,
          controller: _note,
          label: l.g06_note_optional,
          errorText: _error,
          enabled: !_sending,
          rows: 3,
        ),
      ],
    );
  }
}
