import 'package:dabbler/features/profile/domain/models/persona_rules.dart';

/// KAN-934: the formats Create game offers for a sport.
///
/// A format no active venue space of the sport carries (live data
/// 2026-11-14: Football `football_street`, tagged on no space) is hidden, so
/// the composer never offers a format whose venue list is always empty.
///
/// Nothing is hidden when [spaceKeys] is null (the spaces could not be read)
/// or when no format of the sport has a space at all: such a sport stays
/// creatable without a venue, as before.
List<Map<String, dynamic>> withVenueSpaces(
  List<Map<String, dynamic>> variants,
  Set<String>? spaceKeys,
) {
  if (spaceKeys == null) return variants;
  final kept = <Map<String, dynamic>>[
    for (final v in variants)
      if (spaceKeys.contains(v['variant_key'])) v,
  ];
  return kept.isEmpty ? variants : kept;
}

/// KAN-934: the actor Create game sends as `p_actor_type`. A persona with one
/// capability creates as that one; a Contributor (both) as the one picked in
/// "Create as", player until picked.
String gameComposerActorFor(PersonaType? persona, String? choice) {
  final canPlay = persona?.hasPlayerCapabilities ?? false;
  final canOrganise = persona?.hasOrganiserCapabilities ?? false;
  if (canPlay && canOrganise) return choice ?? 'player';
  return canOrganise ? 'organiser' : 'player';
}
