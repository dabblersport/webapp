import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/profile_sports_screen.dart'
    show SkillLevel;
import 'package:dabbler/features/social/providers/post_providers.dart'
    show sportsListProvider;
import 'package:dabbler/features/sports/data/sport_follow_repository.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/enums/game_enums.dart' show kSkillBandWriteValues;
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-1060: before a join (game or meetup) of [sport], makes sure the sport
/// is in the active persona's My sports with a chosen level. Returns true
/// when the join may go on.
///
/// * An active card with a set level: true at once.
/// * An active card whose level was never chosen: a "Set your {sport} level"
///   sheet, then `rpc_set_sport_level`, then true.
/// * No active card: an "Add {sport} to your sports" sheet with the level
///   picker, then `rpc_add_my_sport` at that level, then true.
///
/// A dismissal returns false and writes nothing. A failure to check or to
/// save returns false with the reason shown; nothing is joined on a guess.
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

  final Result<MySportCard, Failure> card = await container
      .read(sportOverviewRepositoryProvider)
      .mySportCard(profileId, sport);
  if (!context.mounted) return false;
  if (card is Err<MySportCard, Failure>) {
    _toast(context, l.sport_overview_error_text);
    return false;
  }
  final MySportCard status = card.requireValue;
  if (status == MySportCard.ready) return true;

  final bool adding = status == MySportCard.none;
  final String name = sport.name(Localizations.localeOf(context).languageCode);
  final int? level = await showAppSheet<int>(
    context: context,
    title: adding
        ? l.sport_overview_join_add_title(name)
        : l.sport_overview_join_level_title(name),
    detent: DabblerSheetDetent.content,
    builder: (BuildContext sheet) => SportJoinLevelSheet(
      confirmLabel: adding
          ? l.sport_overview_join_add_confirm
          : l.sport_overview_join_level_confirm,
      onConfirm: (int v) => Navigator.of(sheet).pop(v),
    ),
  );
  if (level == null || !context.mounted) return false;

  final SportFollowRepository repo = container.read(
    sportFollowRepositoryProvider,
  );
  final Result<SportFollowOutcome, Failure> saved = adding
      ? await repo.addToMySports(profileId, sport, skillLevel: level)
      : await repo.setLevel(profileId, sport, level);
  final bool ok = switch (saved) {
    Ok(value: SportFollowOutcome.added) ||
    Ok(value: SportFollowOutcome.levelSet) ||
    Ok(value: SportFollowOutcome.unchanged) => true,
    _ => false,
  };
  if (!context.mounted) return false;
  if (!ok) {
    _toast(context, l.sport_overview_join_failed);
    return false;
  }
  await container.read(profileControllerProvider.notifier).refreshProfile();
  container.invalidate(mySportCardProvider);
  container.invalidate(sportOverviewCountsProvider);
  return true;
}

/// The gate for a join whose item names its sport by id, key or English
/// name (the listings carry only some of them). The sport is looked up in the
/// sports catalogue; one that cannot be found lets the join's own RPC decide.
Future<bool> confirmSportForJoin({
  required BuildContext context,
  required WidgetRef ref,
  String? sportId,
  String? sportKey,
  String? sportName,
}) async {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final SportInfo? sport = await resolveJoinSport(
    container,
    sportId: sportId,
    sportKey: sportKey,
    sportName: sportName,
  );
  if (!context.mounted) return false;
  if (sport == null) return true;
  return confirmSportProfileForJoin(context: context, ref: ref, sport: sport);
}

/// The [SportInfo] of the catalogue row matching [sportId], else [sportKey],
/// else [sportName]; null when none matches or the catalogue fails.
Future<SportInfo?> resolveJoinSport(
  ProviderContainer container, {
  String? sportId,
  String? sportKey,
  String? sportName,
}) async {
  if (sportId == null && sportKey == null && sportName == null) return null;
  // The catalogue is auto-disposed; hold it for the length of the read.
  final ProviderSubscription<Future<List<Map<String, dynamic>>>> hold =
      container.listen(sportsListProvider.future, (_, _) {});
  try {
    final List<Map<String, dynamic>> rows = await hold.read();
    String? lower(Object? v) => (v as String?)?.trim().toLowerCase();
    final Map<String, dynamic>? row =
        _first(rows, (r) => sportId != null && r['id'] == sportId) ??
        _first(
          rows,
          (r) => sportKey != null && lower(r['sport_key']) == lower(sportKey),
        ) ??
        _first(
          rows,
          (r) => sportName != null && lower(r['name_en']) == lower(sportName),
        );
    if (row == null) return null;
    return SportInfo(
      id: row['id'] as String,
      nameEn: (row['name_en'] as String?) ?? '',
      sportKey: row['sport_key'] as String?,
    );
  } catch (_) {
    return null;
  } finally {
    hold.close();
  }
}

Map<String, dynamic>? _first(
  List<Map<String, dynamic>> rows,
  bool Function(Map<String, dynamic>) test,
) {
  for (final Map<String, dynamic> r in rows) {
    if (test(r)) return r;
  }
  return null;
}

/// The join gate's sheet body: the Settings level picker (Beginner /
/// Intermediate / Advanced, stored on the 1-10 scale) and the primary button.
class SportJoinLevelSheet extends StatefulWidget {
  const SportJoinLevelSheet({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String confirmLabel;

  /// Called with the chosen 1-10 value.
  final ValueChanged<int> onConfirm;

  @override
  State<SportJoinLevelSheet> createState() => _SportJoinLevelSheetState();
}

class _SportJoinLevelSheetState extends State<SportJoinLevelSheet> {
  SkillLevel _level = SkillLevel.beginner;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerText(
          l.sport_overview_join_level_text,
          style: DabblerType.smallTight,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        Wrap(
          spacing: DabblerSpacing.space3,
          runSpacing: DabblerSpacing.space3,
          children: <Widget>[
            for (final SkillLevel level in SkillLevel.values)
              DabblerChip(
                label: level.label(l),
                selected: _level == level,
                onTap: () => setState(() => _level = level),
              ),
          ],
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerButton(
          label: widget.confirmLabel,
          tone: DabblerButtonTone.primary,
          size: DabblerButtonSize.block,
          fullWidth: true,
          onPressed: () =>
              widget.onConfirm(kSkillBandWriteValues[_level.index]),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String message) {
  DabblerToastProvider.of(
    context,
  ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
}
