// KAN-1003 (W2-F6): the viewer's sign-ins from the KAN-985 ledger. "Signed
// in now" lists the devices whose session is live (this device marked, no
// Sign out on it); every other live device has Sign out, which signs out that
// one device only. "Recent sign-ins" lists the rest. Security notices are
// always on: the note says so, and there is no toggle or mute here.

import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:dabbler/features/security/presentation/security_format.dart';
import 'package:dabbler/features/security/presentation/security_review_screen.dart'
    show securityRefusal;
import 'package:dabbler/features/security/presentation/sign_ins_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignInsScreen extends ConsumerWidget {
  const SignInsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(signInsProvider);
    final ctrl = ref.read(signInsProvider.notifier);
    final topBar = DabblerNavigationTopBar.titled(
      title: l.sec6_list_title,
      onBack: onBack ?? () => context.pop(),
    );
    final rows = state.rows;
    if (rows == null) {
      return DabblerPage(
        topBar: topBar,
        body: state.loadFailure == null
            ? const Center(child: DabblerSpinner())
            : DabblerEmptyState.error(
                title: l.sec6_load_failed,
                retryLabel: l.feed_retry,
                onRetry: ctrl.load,
              ),
      );
    }
    final active = [
      for (final r in rows)
        if (r.isActive || r.isCurrent) r,
    ]..sort((a, b) => a.isCurrent == b.isCurrent ? 0 : (a.isCurrent ? -1 : 1));
    final recent = [
      for (final r in rows)
        if (!(r.isActive || r.isCurrent)) r,
    ];

    Future<void> signOut(SecuritySignIn s) async {
      final f = await ctrl.notMe(s.id);
      if (!context.mounted) return;
      if (f == null) {
        securityToast(
          context,
          l.sec6_signed_out_toast(securityDevice(context, s)),
        );
        return;
      }
      if (f.code == 'busy') return;
      securityToast(context, securityRefusal(l, f), err: true);
    }

    Widget card(SecuritySignIn s) {
      final busy = state.busyId == s.id;
      final canSignOut = s.isActive && !s.isCurrent;
      return DabblerNotificationCard(
        key: ValueKey<String>('sign-in-${s.id}'),
        leading: DabblerNotificationIconTile(
          icon: s.isCurrent ? 'tick-circle' : 'mobile',
          tone: s.isCurrent
              ? DabblerNotificationTone.ok
              : DabblerNotificationTone.neutral,
        ),
        actor: securityDevice(context, s),
        verb: s.isCurrent ? l.sec6_this_device : '',
        meta: securityMeta(context, s).sublist(1),
        pending: busy ? l.sec6_sending : null,
        actions: canSignOut && !busy
            ? <DabblerNotificationCardAction>[
                DabblerNotificationCardAction(
                  l.sec6_sign_out,
                  onPressed: () => signOut(s),
                ),
              ]
            : const <DabblerNotificationCardAction>[],
        result: s.state == SignInState.secured
            ? DabblerNotificationResult(
                icon: 'logout',
                text: l.sec6_signed_out,
                tone: DabblerNotificationTone.neutral,
              )
            : null,
      );
    }

    const gap = DabblerGap.v(DabblerSpacing.space2);
    return DabblerPage(
      topBar: topBar,
      body: ListView(
        padding: DabblerInsets.screen,
        children: <Widget>[
          DabblerText(
            l.sec6_always_on,
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
          if (rows.isEmpty)
            DabblerEmptyState(icon: 'security', title: l.sec6_empty),
          if (active.isNotEmpty) ...[
            const DabblerGap.v(DabblerSpacing.space6),
            DabblerText(l.sec6_active, style: DabblerType.headline),
            const DabblerGap.v(DabblerSpacing.space2),
            for (final s in active) ...[card(s), gap],
          ],
          if (recent.isNotEmpty) ...[
            const DabblerGap.v(DabblerSpacing.space6),
            DabblerText(l.sec6_recent, style: DabblerType.headline),
            const DabblerGap.v(DabblerSpacing.space2),
            for (final s in recent) ...[card(s), gap],
          ],
        ],
      ),
    );
  }
}
