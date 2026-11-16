import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-959: the For you tab's sport filter — a `sports.id`, or null for
/// "All sports". Not autoDispose: the choice persists across tab switches.
/// [feedNotifierProvider] sends it to `get_home_feed` as `p_sport_id` and
/// reloads from page 1 when it changes.
final forYouSportProvider = StateProvider<String?>((ref) => null);
