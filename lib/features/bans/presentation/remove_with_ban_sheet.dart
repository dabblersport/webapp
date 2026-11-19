// KAN-1014: the host's removal sheet. One choice — remove only, remove and
// ban from this event (or series), remove and ban from all the host's events
// — plus an optional reason. Pops with the [RemovalChoice]; the caller makes
// the server call.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/bans/domain/ban_models.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

Future<RemovalChoice?> showRemoveWithBanSheet({
  required BuildContext context,
  required String name,
  required String description,
  bool isSeries = false,
}) {
  final l = AppLocalizations.of(context);
  return showDabblerSheet<RemovalChoice>(
    context: context,
    title: l.ban_remove_title(context.isolate(name)),
    detent: DabblerSheetDetent.content,
    builder: (_) =>
        RemoveWithBanSheet(description: description, isSeries: isSeries),
  );
}

class RemoveWithBanSheet extends StatefulWidget {
  const RemoveWithBanSheet({
    super.key,
    required this.description,
    this.isSeries = false,
  });

  final String description;
  final bool isSeries;

  @override
  State<RemoveWithBanSheet> createState() => _RemoveWithBanSheetState();
}

class _RemoveWithBanSheetState extends State<RemoveWithBanSheet> {
  BanScope _scope = BanScope.none;
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reason.text.trim();
    Navigator.of(
      context,
    ).pop(RemovalChoice(scope: _scope, reason: reason.isEmpty ? null : reason));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget option(BanScope s, String label) => DabblerRadio(
      key: ValueKey<String>('ban-scope-${s.wire}'),
      selected: _scope == s,
      label: label,
      onChanged: (_) => setState(() => _scope = s),
    );
    return DabblerSheetBody(
      actions: DabblerSheetActions(
        children: <Widget>[
          DabblerButton(
            key: const ValueKey<String>('ban-remove-confirm'),
            label: l.ban_remove_confirm,
            fullWidth: true,
            size: DabblerButtonSize.full,
            tone: DabblerButtonTone.destructive,
            onPressed: _confirm,
          ),
        ],
      ),
      children: <Widget>[
        DabblerText(widget.description, style: DabblerType.subheadline),
        option(BanScope.none, l.ban_remove_only),
        option(
          BanScope.event,
          widget.isSeries ? l.ban_remove_series : l.ban_remove_event,
        ),
        option(BanScope.organiser, l.ban_remove_all),
        DabblerTextField(
          key: const ValueKey<String>('ban-reason'),
          variant: DabblerTextFieldVariant.multiline,
          controller: _reason,
          label: l.ban_reason_label,
          rows: 2,
        ),
      ],
    );
  }
}
