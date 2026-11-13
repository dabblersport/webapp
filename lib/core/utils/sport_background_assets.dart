import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The bundled sport backgrounds (`assets/images/sport_background/`), one per
/// design-system sport key. Shared by every surface that shows one (Welcome,
/// venue Spaces), so no feature imports another feature's widgets for them.
/// Every other key has none.
const Map<String, String> sportBackgroundAssets = <String, String>{
  'football': 'assets/images/sport_background/football.webp',
  'basketball': 'assets/images/sport_background/basketball.webp',
  'badminton': 'assets/images/sport_background/badminton.webp',
  'cycling': 'assets/images/sport_background/cycling.webp',
  'cricket': 'assets/images/sport_background/cricket.webp',
  'gym': 'assets/images/sport_background/gym.webp',
  'tennis': 'assets/images/sport_background/tennis.webp',
  'padel': 'assets/images/sport_background/padel.webp',
  'swimming': 'assets/images/sport_background/swimming.webp',
  'running': 'assets/images/sport_background/running.webp',
  'volleyball': 'assets/images/sport_background/volleyball.webp',
};

/// The background asset for a design-system sport [key], or null (no key,
/// unknown key, or a sport without a background).
String? sportBackgroundAsset(String? key) {
  if (key == null) return null;
  final sport = DabblerSport.fromKey(key.trim().toLowerCase());
  return sport == null ? null : sportBackgroundAssets[sport.key];
}

/// The cover-fit background for [key], or null when the sport has none.
Widget? sportBackgroundWidget(String? key, {Key? widgetKey}) {
  final asset = sportBackgroundAsset(key);
  if (asset == null) return null;
  return DabblerSportBackground.maybe(
    DabblerSport.fromKey(key!.trim().toLowerCase())!,
    key: widgetKey ?? ValueKey<String>('sport-background-$asset'),
    artwork: DabblerSportArtwork.asset(asset),
  );
}

/// The venue Spaces card photos (`assets/images/card/<key>_card.png`), one per
/// design-system sport key. Only the Spaces cards use them; Welcome and every
/// other surface keep [sportBackgroundAssets].
const Map<String, String> sportCardAssets = <String, String>{
  'football': 'assets/images/card/football_card.png',
  'basketball': 'assets/images/card/basketball_card.png',
  'badminton': 'assets/images/card/badminton_card.png',
  'cycling': 'assets/images/card/cycling_card.png',
  'cricket': 'assets/images/card/cricket_card.png',
  'gym': 'assets/images/card/gym_card.png',
  'tennis': 'assets/images/card/tennis_card.png',
  'padel': 'assets/images/card/padel_card.png',
  'swimming': 'assets/images/card/swimming_card.png',
  'running': 'assets/images/card/running_card.png',
  'volleyball': 'assets/images/card/volleyball_card.png',
};

/// The card photo asset for a design-system sport [key], or null.
String? sportCardAsset(String? key) {
  if (key == null) return null;
  final sport = DabblerSport.fromKey(key.trim().toLowerCase());
  return sport == null ? null : sportCardAssets[sport.key];
}

/// The cover-fit card photo for [key], or null when the sport has none.
Widget? sportCardWidget(String? key, {Key? widgetKey}) {
  final asset = sportCardAsset(key);
  if (asset == null) return null;
  return DabblerSportBackground.maybe(
    DabblerSport.fromKey(key!.trim().toLowerCase())!,
    key: widgetKey ?? ValueKey<String>('sport-card-$asset'),
    artwork: DabblerSportArtwork.asset(asset),
  );
}
