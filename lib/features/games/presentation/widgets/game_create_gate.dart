import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Guards a Create game entry reached directly (a deep link): a persona that
/// may not create a game (`canCreateGameOrMeetup`: socialiser, host, or not
/// known yet) sees the generic refusal and the form is never built. The
/// Create menu hides the tile for them already; the server stays the
/// authority.
///
/// KAN-934: a direct load or refresh of `/create-game` never builds the home
/// shell, so nothing had loaded the profile and the persona stayed unknown:
/// every user was refused. While the persona is unknown the gate now runs the
/// profile bootstrap itself (`initializeProfileDataProvider`, the same one the
/// shell runs, once per session) and shows a spinner; it refuses only once the
/// bootstrap has finished without a persona that may create.
class GameCreateGate extends ConsumerWidget {
  const GameCreateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(activePersonaProvider);
    if (canCreateGameOrMeetup(persona)) return child;
    if (persona == null && ref.watch(initializeProfileDataProvider).isLoading) {
      return const Padding(
        padding: EdgeInsetsDirectional.all(DabblerSpacing.space8),
        child: Center(child: DabblerSpinner()),
      );
    }
    final l = AppLocalizations.of(context);
    return DabblerEmptyState(
      icon: 'danger',
      title: l.game_create,
      text: l.game_err_create_refused,
    );
  }
}
