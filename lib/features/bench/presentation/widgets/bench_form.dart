import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/features/bench/presentation/widgets/bench_sheets.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The bench form: explainer, reason, end date and the four visibility
/// toggles, then Start bench (or Save changes when editing). The parent
/// decides what submitting does; this widget owns only the field values.
class BenchForm extends StatefulWidget {
  const BenchForm({
    super.key,
    required this.initial,
    required this.editing,
    required this.submitting,
    required this.offline,
    required this.onSubmit,
    this.errorBanner,
  });

  /// The starting values: defaults to start, the current bench to edit.
  final BenchSettings initial;

  /// Edit mode: the button reads Save changes.
  final bool editing;
  final bool submitting;

  /// Offline disables the button; nothing is queued.
  final bool offline;
  final ValueChanged<BenchSettings> onSubmit;

  /// A failed write's banner, shown above the explainer.
  final Widget? errorBanner;

  @override
  State<BenchForm> createState() => _BenchFormState();
}

class _BenchFormState extends State<BenchForm> {
  late BenchSettings _settings = widget.initial;
  late final TextEditingController _reason = TextEditingController(
    text: widget.initial.reason ?? '',
  );

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showBenchEndDateSheet(
      context,
      initial: _settings.benchUntil,
    );
    if (picked != null && mounted) {
      setState(() => _settings = _settings.copyWith(benchUntil: picked));
    }
  }

  void _submit() => widget.onSubmit(_settings.copyWith(reason: _reason.text));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool locked = widget.submitting || widget.offline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.errorBanner != null) ...[
          widget.errorBanner!,
          const DabblerGap.v(DabblerSpacing.space6),
        ],
        const BenchExplainer(),
        const DabblerGap.v(DabblerSpacing.space6),
        DabblerTextField(
          controller: _reason,
          label: l10n.bench_reason_label,
          placeholder: l10n.bench_reason_placeholder,
          helperText: l10n.bench_reason_helper,
          enabled: !widget.submitting,
        ),
        const DabblerGap.v(DabblerSpacing.space6),
        DabblerDateField(
          value: _settings.benchUntil,
          minimum: _today(),
          label: l10n.bench_end_label,
          placeholder: l10n.bench_end_placeholder,
          helperText: l10n.bench_end_helper,
          enabled: !widget.submitting,
          onChanged: (day) => setState(
            () => _settings = day == null
                ? _settings.copyWith(clearBenchUntil: true)
                : _settings.copyWith(benchUntil: day),
          ),
          onOpenPicker: widget.submitting ? null : _pickEndDate,
        ),
        const DabblerGap.v(DabblerSpacing.space6),
        DabblerRowGroup(
          children: [
            _toggle(
              icon: 'eye-slash',
              title: l10n.bench_toggle_feed,
              subtitle: l10n.bench_toggle_feed_sub,
              checked: _settings.hideInFeed,
              onChanged: (v) => _settings.copyWith(hideInFeed: v),
            ),
            _toggle(
              icon: 'search-normal',
              title: l10n.bench_toggle_search,
              subtitle: l10n.bench_toggle_search_sub,
              checked: _settings.hideInSearch,
              onChanged: (v) => _settings.copyWith(hideInSearch: v),
            ),
            _toggle(
              icon: 'user-add',
              title: l10n.bench_toggle_friends,
              subtitle: l10n.bench_toggle_friends_sub,
              checked: _settings.blockFriendRequests,
              onChanged: (v) => _settings.copyWith(blockFriendRequests: v),
            ),
            _toggle(
              icon: 'notification-bing',
              title: l10n.bench_toggle_notifs,
              subtitle: l10n.bench_toggle_notifs_sub,
              checked: _settings.suppressSocialNotifications,
              onChanged: (v) =>
                  _settings.copyWith(suppressSocialNotifications: v),
            ),
          ],
        ),
        const DabblerGap.v(DabblerSpacing.space7),
        DabblerButton(
          label: widget.editing ? l10n.bench_save : l10n.bench_start,
          fullWidth: true,
          loading: widget.submitting,
          disabled: locked,
          onPressed: locked ? null : _submit,
        ),
      ],
    );
  }

  Widget _toggle({
    required String icon,
    required String title,
    required String subtitle,
    required bool checked,
    required BenchSettings Function(bool value) onChanged,
  }) => DabblerInputRow.toggle(
    flat: true,
    showDivider: false,
    leading: DabblerIcon(
      icon,
      size: DabblerSizing.iconRow,
      color: DabblerColors.of(context).textSecondary,
    ),
    title: title,
    subtitle: subtitle,
    checked: checked,
    disabled: widget.submitting,
    toggleSemanticLabel: title,
    onChanged: (value) => setState(() => _settings = onChanged(value)),
  );

  static DateTime _today() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

/// "Take a break from the social side": what pauses and what keeps working.
class BenchExplainer extends StatelessWidget {
  const BenchExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DabblerColors colors = DabblerColors.of(context);
    Widget item(String icon, String text) => Padding(
      padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DabblerIcon(
            icon,
            size: DabblerSizing.iconInline,
            color: colors.textSecondary,
          ),
          const DabblerGap.h(DabblerSpacing.space3),
          Expanded(child: DabblerText(text, style: DabblerType.subheadline)),
        ],
      ),
    );
    return DabblerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerText(l10n.bench_explain_title, style: DabblerType.title3),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            l10n.bench_explain_body,
            style: DabblerType.subheadline,
            tone: DabblerTextTone.secondary,
          ),
          const DabblerGap.v(DabblerSpacing.space6),
          DabblerText(
            l10n.bench_paused_head,
            style: DabblerType.headline,
            weight: DabblerTextWeight.semibold,
          ),
          item('close-circle', l10n.bench_paused_1),
          item('close-circle', l10n.bench_paused_2),
          item('close-circle', l10n.bench_paused_3),
          const DabblerGap.v(DabblerSpacing.space6),
          DabblerText(
            l10n.bench_keep_head,
            style: DabblerType.headline,
            weight: DabblerTextWeight.semibold,
          ),
          item('tick-circle', l10n.bench_keep_1),
          item('tick-circle', l10n.bench_keep_2),
        ],
      ),
    );
  }
}
