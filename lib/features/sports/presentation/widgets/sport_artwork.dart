import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// KAN-591: the supplied sport artwork, by the `sports.sport_key` the data
/// carries. The file names are the supplied ones, case-sensitive and
/// misspellings included (`Badmition`, `Volyball`, `Rakby`, `Bowloing`): they
/// are never renamed, and the artwork is never edited.
///
/// Only a sport the data names is mapped. `Frame 5.svg` ships in the folder but
/// is not mapped: nothing in the supplied set says which sport it is for, and
/// a sport is never guessed from a drawing. `Golf` and `Bowloing` are named by
/// their files; no `sports` row has those keys yet, so they are inert until one
/// does.
const Map<String, String> kSportArtworkFiles = <String, String>{
  'football': 'Football.svg',
  'basketball': 'Basketball.svg',
  'swimming': 'Swimming.svg',
  'running': 'Running.svg',
  'cycling': 'Cycling.svg',
  'road_cycling': 'Cycling.svg',
  'cricket': 'Cricket.svg',
  'gym_training': 'GYM.svg',
  'tennis': 'Tennis.svg',
  'padel': 'Padel.svg',
  'golf': 'Golf.svg',
  'table_tennis': 'Ping-Pong.svg',
  'pool_billiards': 'Pool.svg',
  'badminton': 'Badmition.svg',
  'volleyball': 'Volyball.svg',
  'rugby_union': 'Rakby.svg',
  'bowling': 'Bowloing.svg',
};

const String kSportArtworkFolder = 'assets/sport-icon';

/// The asset path for [sportKey], or null when no supplied artwork is mapped.
String? sportArtworkAsset(String? sportKey) {
  final String? file = kSportArtworkFiles[sportKey?.trim()];
  return file == null ? null : '$kSportArtworkFolder/$file';
}

/// The artwork of one sport at [size], or the design system's sport icon (its
/// own generic glyph for a key it does not know) when none is supplied.
class SportArtwork extends StatelessWidget {
  const SportArtwork({
    super.key,
    required this.sportKey,
    required this.size,
    this.semanticLabel,
  });

  final String? sportKey;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final String? asset = sportArtworkAsset(sportKey);
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: semanticLabel,
      );
    }
    final String? key = sportKey?.trim();
    return DabblerSportIcon.fromKey(
      // The design system names sports in kebab-case; the data uses snake_case.
      key == null || key.isEmpty ? 'unknown' : key.replaceAll('_', '-'),
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}
