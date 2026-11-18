// KAN-1003 (W2-F6, G-08, H.1): the review of a security notice. A new
// sign-in shows device, time and approximate city from the ledger, with
// "This was me" and "Secure my account" (signs out that one device, then
// opens the password change; no Face ID). A password or email change shows
// when it happened and "Wasn't you? Secure your account". Security notices
// are always on: there is no mute and no toggle here. The card is the
// inbox's card (W1-F2).

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:dabbler/features/security/presentation/security_format.dart';
import 'package:dabbler/features/security/presentation/sign_ins_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The message for a refused answer.
String securityRefusal(AppLocalizations l, Failure f) => switch (f.code) {
  '42501' => l.sec6_confirm_elsewhere,
  '22023' || 'P0002' => l.sec6_already,
  _ => l.sec6_failed,
};

class SecurityReviewScreen extends ConsumerWidget {
  const SecurityReviewScreen({
    super.key,
    required this.kind,
    this.signInId,
    this.changedAt,
    this.onBack,
  });

  final SecurityNoticeKind kind;

  /// The ledger row of a new sign-in.
  final String? signInId;

  /// When a password or email change happened, when known.
  final DateTime? changedAt;
  final VoidCallback? onBack;

  static const _shield = DabblerNotificationIconTile(
    icon: 'security',
    tone: DabblerNotificationTone.brand,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final topBar = DabblerNavigationTopBar.titled(
      title: l.sec6_review_title,
      onBack: onBack ?? () => context.pop(),
    );
    final Widget body = kind == SecurityNoticeKind.newSignIn
        ? _NewSignIn(signInId: signInId)
        : _change(context, l);
    return DabblerPage(topBar: topBar, body: body);
  }

  Widget _change(BuildContext context, AppLocalizations l) {
    final title = kind == SecurityNoticeKind.passwordChanged
        ? l.sec_t_security_password_changed
        : l.sec_t_security_email_changed;
    final at = changedAt;
    return ListView(
      padding: DabblerInsets.screen,
      children: <Widget>[
        DabblerNotificationCard(
          key: ValueKey<String>('security-${kind.wire}'),
          leading: _shield,
          actor: title,
          unread: true,
          sub: l.sec6_change_hint,
          meta: <DabblerNotificationMeta>[
            if (at != null)
              DabblerNotificationMeta(
                'clock',
                l.sec6_changed_at(securityWhen(context, at)),
              ),
          ],
          actions: <DabblerNotificationCardAction>[
            DabblerNotificationCardAction(
              l.sec6_wasnt_you,
              primary: true,
              onPressed: () => context.push(RoutePaths.settingsAccountPassword),
            ),
            DabblerNotificationCardAction(
              l.sec6_review_sign_ins,
              onPressed: () => context.push(RoutePaths.securitySignIns),
            ),
          ],
        ),
      ],
    );
  }
}

class _NewSignIn extends ConsumerWidget {
  const _NewSignIn({required this.signInId});

  final String? signInId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(signInsProvider);
    final ctrl = ref.read(signInsProvider.notifier);
    if (state.rows == null) {
      return state.loadFailure == null
          ? const Center(child: DabblerSpinner())
          : DabblerEmptyState.error(
              title: l.sec6_load_failed,
              retryLabel: l.feed_retry,
              onRetry: ctrl.load,
            );
    }
    final id = signInId;
    final s = id == null ? null : state.byId(id);
    if (s == null) {
      return DabblerEmptyState(icon: 'security', title: l.sec6_not_found);
    }
    final busy = state.busyId == s.id;

    Future<void> confirm() async {
      final f = await ctrl.confirm(s.id);
      if (!context.mounted || f == null || f.code == 'busy') return;
      securityToast(context, securityRefusal(l, f), err: true);
    }

    Future<void> secure() async {
      final f = await ctrl.notMe(s.id);
      if (!context.mounted) return;
      if (f == null) {
        context.push(RoutePaths.settingsAccountPassword);
        return;
      }
      if (f.code == 'busy') return;
      securityToast(context, securityRefusal(l, f), err: true);
    }

    final Widget card = switch (s.state) {
      SignInState.confirmed => DabblerNotificationCard(
        key: const ValueKey<String>('security-confirmed'),
        leading: SecurityReviewScreen._shield,
        actor: l.sec6_new_signin,
        meta: securityMeta(context, s),
        result: DabblerNotificationResult(
          icon: 'tick-circle',
          text: l.sec6_confirmed,
          tone: DabblerNotificationTone.ok,
        ),
      ),
      SignInState.secured => DabblerNotificationCard(
        key: const ValueKey<String>('security-secured'),
        leading: SecurityReviewScreen._shield,
        actor: l.sec6_new_signin,
        meta: securityMeta(context, s),
        result: DabblerNotificationResult(
          icon: 'logout',
          text: l.sec6_secured,
          tone: DabblerNotificationTone.warn,
          linkLabel: l.sec6_change_password,
          onLink: () => context.push(RoutePaths.settingsAccountPassword),
        ),
      ),
      _ when s.isCurrent => DabblerNotificationCard(
        key: const ValueKey<String>('security-current'),
        leading: SecurityReviewScreen._shield,
        actor: l.sec6_new_signin,
        sub: l.sec6_current_note,
        meta: securityMeta(context, s),
      ),
      SignInState.known => DabblerNotificationCard(
        key: const ValueKey<String>('security-known'),
        leading: SecurityReviewScreen._shield,
        actor: l.sec6_new_signin,
        meta: securityMeta(context, s),
        result: DabblerNotificationResult(
          icon: 'tick-circle',
          text: l.sec6_known,
          tone: DabblerNotificationTone.neutral,
        ),
      ),
      _ => DabblerNotificationCard(
        key: const ValueKey<String>('security-new'),
        leading: SecurityReviewScreen._shield,
        actor: l.sec6_new_signin,
        unread: true,
        sub: l.sec_b_security_new_signin,
        meta: securityMeta(context, s),
        pending: busy ? l.sec6_sending : null,
        actions: busy
            ? const <DabblerNotificationCardAction>[]
            : <DabblerNotificationCardAction>[
                DabblerNotificationCardAction(
                  l.notif_action_this_was_me,
                  onPressed: confirm,
                ),
                DabblerNotificationCardAction(
                  l.sec6_secure,
                  primary: true,
                  onPressed: secure,
                ),
              ],
      ),
    };
    return ListView(padding: DabblerInsets.screen, children: <Widget>[card]);
  }
}
