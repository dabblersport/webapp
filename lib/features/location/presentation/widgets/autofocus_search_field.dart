import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

// ── Search field with the old `autofocus: true` ─────────────────────

/// DabblerSearchField takes no `autofocus`; this requests focus after the
/// first frame, which is what the replaced TextField's `autofocus` did.
class AutofocusSearchField extends StatefulWidget {
  const AutofocusSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  State<AutofocusSearchField> createState() => _AutofocusSearchFieldState();
}

class _AutofocusSearchFieldState extends State<AutofocusSearchField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DabblerSearchField(
      controller: widget.controller,
      focusNode: _focusNode,
      placeholder: widget.placeholder,
      onChanged: widget.onChanged,
      onCleared: () => widget.onChanged(''),
    );
  }
}
