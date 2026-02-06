/// Sport tags mapping - converts sport keys to their tag names
/// Used for displaying sport-specific tags (e.g., "footballer", "paddler")
const Map<String, String> sportTags = {
  'football': 'footballer',
  'padel': 'paddler',
  'cricket': 'cricketer',
  'basketball': 'basketballer',
  'baseball': 'baseballer',
  'tennis': 'tenniser',
  'badminton': 'badmintonian',
  'rugby': 'rugbyist',
  'volleyball': 'volleyballer',
  'tabletennis': 'ponger',
  'table_tennis': 'ponger',
  'hockey': 'hockeyist',
  'ice_hockey': 'icer',
  'golf': 'golfer',
  'fencing': 'fencer',
  'boxing': 'boxer',
  'mma': 'mixfighter',
  'wrestling': 'wrestler',
  'swimming': 'swimmer',
  'cycling': 'cycler',
  'running': 'runner',
  'athletics': 'trackster',
  'track_field': 'trackster',
  'skateboarding': 'skater',
  'surfing': 'surfer',
  'skiing': 'skier',
  'snowboarding': 'snowboarder',
  'archery': 'archer',
  'shooting': 'marksman',
  'gymnastics': 'gymnast',
  'rowing': 'rower',
  'sailing': 'sailor',
  'climbing': 'climber',
  'parkour': 'traceur',
  'esports': 'e-sportian',
  'darts': 'dartist',
  'snooker': 'cueist',
  'pool': 'cueist',
  'bowling': 'bowler',
  'handball': 'handballer',
  'netball': 'netballer',
  'lacrosse': 'lacrossian',
  'ultimate_frisbee': 'ultimist',
  'softball': 'softballer',
  'martial_arts': 'martialist',
  'karate': 'karateka',
  'taekwondo': 'taekwondonian',
  'judo': 'judoka',
  'sumo': 'sumotorian',
  'box_lacrosse': 'boxlaxer',
  'field_hockey': 'fielder',
  'triathlon': 'triathlete',
  'motorsport': 'motorian',
  'horse_riding': 'equestrian',
  'equestrian': 'equestrian',
  'polo': 'poloist',
  'kayaking': 'kayaker',
  'canoeing': 'canoeist',
  'baduk': 'goist',
  'go': 'goist',
  'chess': 'chesser',
  'tabletop_gaming': 'tabletopper',
};

/// Get the tag name for a sport key
/// Returns the tag if found, otherwise returns a formatted version of the sport key
String getSportTag(String sportKey) {
  final normalizedKey = sportKey.toLowerCase().replaceAll(' ', '_');
  return sportTags[normalizedKey] ??
      normalizedKey
          .split('_')
          .map(
            (word) =>
                word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
          )
          .join(' ');
}

/// Get all available sport keys
List<String> get allSportKeys => sportTags.keys.toList();
