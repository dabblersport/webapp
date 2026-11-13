import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-622: before a join (game or meetup) of [sport], makes sure the active
/// persona has a sport profile for it. Returns true when the join may go on.
///
/// With a profile: true at once. Without one, asks "Do you want to create
/// profile?": No (or a dismissal) returns false and nothing is created or
/// joined. Yes calls `rpc_create_sport_profile` (Practicing) and adds the sport
/// to Following, then returns true so the real join runs and its real result
/// is shown. A failure to check or to create returns false with the reason
/// shown; nothing is joined on a guess.
Future<bool> confirmSportProfileForJoin({
  required BuildContext context,
  required WidgetRef ref,
  required SportInfo sport,
}) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final String? profileId = ref.read(profileControllerProvider).profile?.id;
  // No active persona to check: the join's own RPC decides.
  if (profileId == null) return true;

  final repo = ref.read(sportOverviewRepositoryProvider);
  final Result<bool, Failure> has = await repo.hasSportProfile(
    profileId,
    sport,
  );
  if (!context.mounted) return false;
  if (has is Err<bool, Failure>) {
    _toast(context, l.sport_overview_error_text);
    return false;
  }
  if (has.requireValue) return true;

  final bool? yes = await showDabblerDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => DabblerDialog(
      title: l.sport_overview_join_profile_title,
      description: l.sport_overview_join_profile_text(
        sport.name(Localizations.localeOf(context).languageCode),
      ),
      onClose: () => Navigator.of(dialog).pop(false),
      primaryAction: DabblerDialogAction(
        label: l.sport_overview_join_profile_yes,
        onPressed: () => Navigator.of(dialog).pop(true),
      ),
      secondaryAction: DabblerDialogAction(
        label: l.sport_overview_join_profile_no,
        onPressed: () => Navigator.of(dialog).pop(false),
      ),
    ),
  );
  if (yes != true || !context.mounted) return false;

  final Result<void, Failure> created = await repo.createSportProfile(
    profileId,
    sport,
  );
  if (!context.mounted) return false;
  if (created is Err<void, Failure>) {
    _toast(context, l.sport_overview_join_profile_failed);
    return false;
  }
  // The profile makes the sport Practicing; it is Following too.
  await container.read(sportFollowRepositoryProvider).follow(profileId, sport);
  await container.read(profileControllerProvider.notifier).refreshProfile();
  return true;
}

void _toast(BuildContext context, String message) {
  DabblerToastProvider.of(
    context,
  ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
}
