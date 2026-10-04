import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a skill window maps to its tier by the lower bound', () {
    expect(gamesSkillTierFor(null, null), isNull);
    expect(gamesSkillTierFor(2, 4), GamesSkillFilter.beginner);
    expect(gamesSkillTierFor(4, 6), GamesSkillFilter.intermediate);
    expect(gamesSkillTierFor(7, 9), GamesSkillFilter.advanced);
    expect(gamesSkillTierFor(null, 10), GamesSkillFilter.pro);
  });
}
