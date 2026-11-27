// KAN-1052: the viewer's own sports scope Games, Meetups and Venues.
//
// KAN-1056: the viewer's sports are the union of the profile's `interests`,
// the active profile's `sport_profiles.sport_id` rows and its primary sport.
// Interests mirror `sport_profiles` only for contributors (a trigger enforces
// it); legacy personas can hold sport_profiles rows missing from interests. The flags come from the active sports catalogue
// (`sportsProvider`, `public.sports`), so no new query is made. Manage Sports
// refreshes the profile, and every section watching this provider follows.

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profiles_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The three listing sections the viewer's sports scope.
enum SportSection { games, meetups, venues }

/// The viewer's sports, with their `is_challenge_sport` / `can_solo` flags.
///
/// Empty means "no scope": signed out, no profile, or no sports. Every section
/// then shows everything, as before KAN-1052.
class MySports {
  const MySports(this.sports);

  /// No scope: show every section and every sport.
  static const MySports none = MySports(<Sport>[]);

  /// Builds the viewer's sports from the [catalogue] and the [ids] on the
  /// profile. Ids missing from the catalogue (inactive sports) are dropped.
  factory MySports.fromIds(List<Sport> catalogue, Iterable<String?> ids) {
    final wanted = <String>{
      for (final id in ids)
        if (id != null && id.isNotEmpty) id,
    };
    if (wanted.isEmpty) return none;
    return MySports([
      for (final s in catalogue)
        if (wanted.contains(s.id)) s,
    ]);
  }

  final List<Sport> sports;

  /// Whether the viewer's sports narrow anything at all.
  bool get isScoped => sports.isNotEmpty;

  bool get hasChallengeSport => sports.any((s) => s.isChallengeSport);
  bool get hasSoloSport => sports.any((s) => s.canSolo);

  /// Games show while unscoped, or while the viewer has a challenge sport.
  bool get showsGames => !isScoped || hasChallengeSport;

  /// Meetups show while unscoped, or while the viewer has a can-solo sport.
  bool get showsMeetups => !isScoped || hasSoloSport;

  /// Whether [section] has a place in the navigation.
  bool shows(SportSection section) => switch (section) {
    SportSection.games => showsGames,
    SportSection.meetups => showsMeetups,
    SportSection.venues => true,
  };

  /// The ids of the viewer's sports that belong in [section]: challenge
  /// sports for Games, can-solo sports for Meetups, all of them for Venues.
  /// Null when unscoped (no narrowing).
  Set<String>? idsFor(SportSection section) {
    if (!isScoped) return null;
    return {
      for (final s in sports)
        if (switch (section) {
          SportSection.games => s.isChallengeSport,
          SportSection.meetups => s.canSolo,
          SportSection.venues => true,
        })
          s.id,
    };
  }

  /// [catalogue] narrowed to the viewer's sports for [section]. The whole
  /// [catalogue] when unscoped, when [browseAll] is on, or when nothing in it
  /// is the viewer's (never an empty tab bar).
  List<T> scope<T>(
    List<T> catalogue,
    SportSection section,
    String Function(T) idOf, {
    bool browseAll = false,
  }) {
    final ids = idsFor(section);
    if (browseAll || ids == null) return catalogue;
    final mine = catalogue.where((s) => ids.contains(idOf(s))).toList();
    return mine.isEmpty ? catalogue : mine;
  }

  /// Whether [catalogue] holds sports outside the viewer's [section] scope,
  /// i.e. whether a "Browse all sports" entry has anything to add.
  bool hasMore<T>(
    List<T> catalogue,
    SportSection section,
    String Function(T) idOf,
  ) => scope(catalogue, section, idOf).length < catalogue.length;
}

/// The viewer's sports (KAN-1052). Resolves to [MySports.none] while signed
/// out or without sports, and on a catalogue failure (show everything rather
/// than nothing).
final mySportsProvider = FutureProvider.autoDispose<MySports>((ref) async {
  final profile = ref.watch(profileControllerProvider.select((s) => s.profile));
  if (profile == null) return MySports.none;
  // Re-fetched whenever the profile changes (Manage Sports refreshes it).
  final rows = await ref
      .watch(sportProfilesRepositoryProvider)
      .getSportIdsForProfile(profile.id);
  final ids = <String?>[
    ...?profile.interests,
    ...rows.fold((_) => const <String>[], (v) => v),
    profile.primarySport,
    profile.preferredSport,
  ];
  if (ids.every((id) => id == null || id.isEmpty)) return MySports.none;
  try {
    final catalogue = await ref.watch(sportsProvider.future);
    return MySports.fromIds(catalogue, ids);
  } catch (_) {
    return MySports.none;
  }
});

/// The viewer's sports for the main navigation (KAN-1056): null while they
/// are still loading, so the gated Games / Meetups tabs stay out of the bar
/// instead of flashing in. Signed out or without a profile resolves at once.
final mySportsNavProvider = Provider.autoDispose<MySports?>((ref) {
  final bootstrapping = ref.watch(initializeProfileDataProvider).isLoading;
  final profileState = ref.watch(
    profileControllerProvider.select((s) => (s.profile == null, s.isLoading)),
  );
  if (profileState.$1) {
    return (bootstrapping || profileState.$2) ? null : MySports.none;
  }
  final mine = ref.watch(mySportsProvider);
  return mine.hasValue ? mine.value : (mine.isLoading ? null : MySports.none);
});

/// The viewer's sports, synchronously: [MySports.none] until resolved, so
/// nothing is hidden while loading.
final mySportsNowProvider = Provider.autoDispose<MySports>(
  (ref) => ref.watch(mySportsProvider).valueOrNull ?? MySports.none,
);

/// "Browse all sports" is on in [SportSection] (discovery beyond the
/// viewer's own sports). Off by default.
final browseAllSportsProvider = StateProvider.family<bool, SportSection>(
  (ref, section) => false,
);
