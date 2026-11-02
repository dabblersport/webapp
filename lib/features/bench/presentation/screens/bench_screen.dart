import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/features/bench/presentation/controllers/bench_controller.dart';
import 'package:dabbler/features/bench/presentation/providers/bench_providers.dart';
import 'package:dabbler/features/bench/presentation/widgets/bench_form.dart';
import 'package:dabbler/features/bench/presentation/widgets/bench_sheets.dart';
import 'package:dabbler/features/bench/presentation/widgets/bench_status_view.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const EdgeInsetsGeometry _bodyPadding = EdgeInsetsDirectional.fromSTEB(
  DabblerSpacing.space6,
  DabblerSpacing.space6,
  DabblerSpacing.space6,
  DabblerSpacing.space10,
);

/// Settings → Bench mode (KAN-706). Not benched: the form and Start bench
/// (confirmed in a sheet). Benched: the status card, End bench (confirmed in
/// a sheet) and Edit, which reopens the form prefilled with Save changes.
/// Offline: the last read status with a warning, and every write disabled.
class BenchScreen extends ConsumerStatefulWidget {
  const BenchScreen({super.key});

  @override
  ConsumerState<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends ConsumerState<BenchScreen> {
  bool _editing = false;

  BenchController get _controller => ref.read(benchControllerProvider.notifier);

  Future<void> _submit(BenchSettings settings, {required bool editing}) async {
    if (!editing) {
      final bool confirmed = await showBenchConfirmSheet(context, settings);
      if (!confirmed || !mounted) return;
    }
    final bool saved = await _controller.save(settings);
    if (saved && mounted) setState(() => _editing = false);
  }

  Future<void> _end() async {
    final bool confirmed = await showBenchEndSheet(context);
    if (!confirmed || !mounted) return;
    await _controller.end();
  }

  void _retry(BenchAction action) {
    final BenchSettings? last = _controller.lastSettings;
    if (action == BenchAction.end) {
      _controller.end();
    } else if (last != null) {
      _controller.save(last);
    }
  }

  void _back() {
    if (_editing) {
      _controller.clearFailure();
      setState(() => _editing = false);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BenchStatus> async = ref.watch(benchStatusProvider);
    final BenchStatus? status = async.valueOrNull;
    final bool editing = _editing && (status?.isBenched ?? false);
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        border: true,
        title: editing ? l10n.bench_edit_title : l10n.bench_screen_title,
        onBack: _back,
      ),
      body: status != null
          ? ListView(
              padding: _bodyPadding,
              children: [_content(l10n, status, editing)],
            )
          : async.hasError
          ? DabblerEmptyState.error(
              title: l10n.bench_error_load_title,
              text: l10n.bench_error_load_body,
              retryLabel: l10n.bench_retry,
              onRetry: () => ref.invalidate(benchStatusProvider),
            )
          : ListView(
              padding: _bodyPadding,
              children: const [BenchLoadingView()],
            ),
    );
  }

  Widget _content(AppLocalizations l10n, BenchStatus status, bool editing) {
    final bool offline = ref.watch(benchOfflineProvider);
    final BenchActionState action = ref.watch(benchControllerProvider);
    final BenchAction? failed = action.failure == null
        ? null
        : action.failedAction;
    final Widget? banner = failed != null
        ? DabblerBanner(
            tone: DabblerBannerTone.error,
            title: failed == BenchAction.save
                ? l10n.bench_error_start_title
                : null,
            message: l10n.bench_error_start_body,
            action: offline
                ? null
                : DabblerBannerAction(
                    label: l10n.bench_retry,
                    onPressed: () => _retry(failed),
                  ),
          )
        : offline
        ? DabblerBanner(
            tone: DabblerBannerTone.warning,
            title: l10n.bench_offline_title,
            message: l10n.bench_offline_body,
          )
        : null;

    if (status.isBenched && !editing) {
      return BenchStatusView(
        status: status,
        offline: offline,
        ending: action.submitting == BenchAction.end,
        locked: action.isSubmitting,
        banner: banner,
        onEnd: _end,
        onEdit: () {
          _controller.clearFailure();
          setState(() => _editing = true);
        },
      );
    }
    return BenchForm(
      key: ValueKey<bool>(editing),
      initial: editing ? status.toSettings() : const BenchSettings(),
      editing: editing,
      submitting: action.submitting == BenchAction.save,
      offline: offline,
      errorBanner: banner,
      onSubmit: (settings) => _submit(settings, editing: editing),
    );
  }
}
