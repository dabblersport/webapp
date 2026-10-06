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
/// authority. An unknown persona resolves into the form as soon as it loads.
class GameCreateGate extends ConsumerWidget {
  const GameCreateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (canCreateGameOrMeetup(ref.watch(activePersonaProvider))) return child;
    final l = AppLocalizations.of(context);
    return DabblerEmptyState(
      icon: 'danger',
      title: l.game_create,
      text: l.game_err_create_refused,
    );
  }
}
