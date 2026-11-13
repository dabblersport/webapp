import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-647: contributor/partner are first-class, the four legacy personas keep
/// their exact behaviour, unknown is explicit, and a one-profile account has
/// no Add / Convert / switch path.
void main() {
  const six = {
    'player': PersonaType.player,
    'organiser': PersonaType.organiser,
    'host': PersonaType.host,
    'socialiser': PersonaType.socialiser,
    'contributor': PersonaType.contributor,
    'partner': PersonaType.partner,
  };

  group('parsing', () {
    six.forEach((name, type) {
      test('$name parses in both parsers', () {
        expect(personaTypeOrNull(name), type);
        expect(PersonaType.fromString(name.toUpperCase()), type);
      });
    });

    test('unknown is null, never Player', () {
      expect(personaTypeOrNull('coach'), isNull);
      expect(PersonaType.fromString('coach'), isNull);
      expect(PersonaType.fromString(null), isNull);
    });

    test('ActivePersonaProfile keeps an unknown persona as null', () {
      final p = ActivePersonaProfile.fromJson({
        'id': 'p1',
        'persona_type': 'coach',
      });
      expect(p.personaType, isNull);
      final c = ActivePersonaProfile.fromJson({
        'id': 'p2',
        'persona_type': 'contributor',
      });
      expect(c.personaType, PersonaType.contributor);
    });
  });

  group('capabilities', () {
    test('contributor is the union of player and organiser', () {
      const c = PersonaType.contributor;
      expect(c.hasPlayerCapabilities, isTrue);
      expect(c.hasOrganiserCapabilities, isTrue);
      expect(c.hasHostCapabilities, isFalse);
      expect(canCreateGameOrMeetup(c), isTrue);
    });

    test('partner is host-equivalent and cannot create games', () {
      const p = PersonaType.partner;
      expect(p.hasHostCapabilities, isTrue);
      expect(p.hasPlayerCapabilities, isFalse);
      expect(p.hasOrganiserCapabilities, isFalse);
      expect(canCreateGameOrMeetup(p), isFalse);
    });

    test('legacy capabilities are unchanged', () {
      expect(canCreateGameOrMeetup(PersonaType.player), isTrue);
      expect(canCreateGameOrMeetup(PersonaType.organiser), isTrue);
      expect(canCreateGameOrMeetup(PersonaType.host), isFalse);
      expect(canCreateGameOrMeetup(PersonaType.socialiser), isFalse);
      expect(canCreateGameOrMeetup(null), isFalse);
      expect(PersonaType.host.hasHostCapabilities, isTrue);
    });
  });

  group('one-profile rules', () {
    test('a unified account is offered nothing to add or convert', () {
      for (final u in [PersonaType.contributor, PersonaType.partner]) {
        expect(
          PersonaRules.getAvailablePersonas(currentPersonas: {u}),
          isEmpty,
        );
        for (final t in PersonaType.values.where((t) => t != u)) {
          expect(
            PersonaRules.evaluateAvailability(
              currentPersonas: {u},
              targetPersona: t,
            ).actionType,
            PersonaActionType.forbidden,
          );
        }
      }
    });

    test('a unified persona is never offered to a legacy account', () {
      for (final legacy in [
        PersonaType.player,
        PersonaType.organiser,
        PersonaType.host,
        PersonaType.socialiser,
      ]) {
        final offered = PersonaRules.getAvailablePersonas(
          currentPersonas: {legacy},
        ).map((a) => a.targetPersona);
        expect(offered.contains(PersonaType.contributor), isFalse);
        expect(offered.contains(PersonaType.partner), isFalse);
      }
    });

    test('legacy add / convert behaviour is preserved', () {
      expect(
        PersonaRules.evaluateAvailability(
          currentPersonas: {PersonaType.player},
          targetPersona: PersonaType.organiser,
        ).actionType,
        PersonaActionType.add,
      );
      expect(
        PersonaRules.evaluateAvailability(
          currentPersonas: {PersonaType.socialiser},
          targetPersona: PersonaType.player,
        ).actionType,
        PersonaActionType.convert,
      );
      expect(PersonaRules.maxActiveProfiles, 2);
      expect(PersonaRules.canAddNewProfile(1), isTrue);
    });

    test('PersonaState: unified account is at limit, legacy is not', () {
      const unified = PersonaState(
        activeProfiles: [
          ActivePersonaProfile(
            profileId: 'p',
            personaType: PersonaType.contributor,
          ),
        ],
      );
      expect(unified.isUnifiedAccount, isTrue);
      expect(unified.isAtProfileLimit, isTrue);
      expect(unified.canAddNewProfile, isFalse);
      expect(unified.availablePersonas, isEmpty);

      const legacy = PersonaState(
        activeProfiles: [
          ActivePersonaProfile(profileId: 'p', personaType: PersonaType.player),
        ],
      );
      expect(legacy.isUnifiedAccount, isFalse);
      expect(legacy.isAtProfileLimit, isFalse);
      expect(legacy.canAddNewProfile, isTrue);
    });

    test('a historical inactive row beside a unified one stays readable', () {
      const s = PersonaState(
        activeProfiles: [
          ActivePersonaProfile(
            profileId: 'old',
            personaType: PersonaType.player,
            isActive: false,
          ),
          ActivePersonaProfile(
            profileId: 'new',
            personaType: PersonaType.partner,
          ),
        ],
      );
      expect(s.activeProfileCount, 2);
      expect(s.isUnifiedAccount, isTrue);
      expect(isUnifiedAccount(s.activePersonaTypes), isTrue);
      expect(isUnifiedAccount([PersonaType.player, null]), isFalse);
    });
  });
}
