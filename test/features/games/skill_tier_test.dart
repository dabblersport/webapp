import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a skill window maps to its tier by the lower bound', () {
    expect(gamesSkillTierFor(null, null), isNull);
    expect(gamesSkillTierFor(2, 4), GamesSkillFilter.beginner);
    expect(gamesSkillTierFor(4, 6), GamesSkillFilter.intermediate);
    expect(gamesSkillTierFor(7, 9), GamesSkillFilter.advanced);
    // One scale, no Pro: everything from 7 up is Advanced.
    expect(gamesSkillTierFor(null, 10), GamesSkillFilter.advanced);
    expect(gamesSkillTierFor(9, 10), GamesSkillFilter.advanced);
    expect(gamesSkillTierFor(7, 10), GamesSkillFilter.advanced);
    expect(GamesSkillFilter.values.map((f) => f.name), [
      'any',
      'beginner',
      'intermediate',
      'advanced',
    ]);
  });

  test('the Advanced filter overlaps every window that reaches 7', () {
    expect(GamesSkillFilter.advanced.range, (7, 10));
    expect(GamesSkillFilter.advanced.matches(9, 10), isTrue);
    expect(GamesSkillFilter.advanced.matches(7, 8), isTrue);
    expect(GamesSkillFilter.advanced.matches(1, 3), isFalse);
  });
}
