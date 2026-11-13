// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-877: the Activity log search is now one editable, full-width DS search
// field. The filter button is gone: the category chips already filter. The
// widget holds no search logic — it owns only its TextEditingController and
// reports through [onChanged] / [onClear]. Wiring is KAN-879.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ActivitySearchRow extends StatefulWidget {
  const ActivitySearchRow({
    super.key,
    this.query = '',
    this.onChanged,
    this.onClear,
  });

  /// The current query, owned by the parent.
  final String query;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called after the clear button empties the field.
  final VoidCallback? onClear;

  @override
  State<ActivitySearchRow> createState() => _ActivitySearchRowState();
}

class _ActivitySearchRowState extends State<ActivitySearchRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );

  @override
  void didUpdateWidget(covariant ActivitySearchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a change the parent made, and only if the field does not already
    // show it — so a parent rebuild with a lagging query never wipes typing.
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        bottom: DabblerSpacing.space3,
      ),
      child: SizedBox(
        width: double.infinity,
        child: DabblerSearchField(
          controller: _controller,
          placeholder: AppLocalizations.of(context).activity_search_hint,
          onChanged: (String value) => widget.onChanged?.call(value),
          onCleared: () => widget.onClear?.call(),
        ),
      ),
    );
  }
}
