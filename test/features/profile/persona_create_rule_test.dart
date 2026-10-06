import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// CEO ruling 2026-10-06: Create game and Create meet-up are for the player
/// and the organiser; an unknown persona is not allowed.
void main() {
  test('player and organiser may create a game or a meet-up', () {
    expect(canCreateGameOrMeetup(PersonaType.player), isTrue);
    expect(canCreateGameOrMeetup(PersonaType.organiser), isTrue);
  });

  test('socialiser and host may not', () {
    expect(canCreateGameOrMeetup(PersonaType.socialiser), isFalse);
    expect(canCreateGameOrMeetup(PersonaType.host), isFalse);
  });

  test('an unknown persona may not (hidden until known)', () {
    expect(canCreateGameOrMeetup(null), isFalse);
  });

  test('personaTypeOrNull parses exactly and never guesses', () {
    expect(personaTypeOrNull('player'), PersonaType.player);
    expect(personaTypeOrNull('Organiser'), PersonaType.organiser);
    expect(personaTypeOrNull('host'), PersonaType.host);
    expect(personaTypeOrNull('socialiser'), PersonaType.socialiser);
    expect(personaTypeOrNull('coach'), isNull);
    expect(personaTypeOrNull(''), isNull);
    expect(personaTypeOrNull(null), isNull);
  });
}
