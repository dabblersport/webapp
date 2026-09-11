import 'package:flutter_test/flutter_test.dart';
import 'package:dabbler/data/models/squad.dart';

/// KAN-192 (T-077 Am.3, frontend child of KAN-176).
///
/// `KAN-191` makes `squads.owner_profile_id` / `squads.owner_user_id` nullable
/// (`DROP NOT NULL` + FK `SET NULL`) so that erasing a user blanks the owner
/// rather than deleting the squad. Before that migration lands, the client has
/// to survive reading such a row: on the old non-nullable model a null owner
/// threw `type 'Null' is not a subtype of type 'String'` during deserialization
/// — a hard crash on read, not a graceful failure.
///
/// These tests decode real JSON rather than inspecting the model definition,
/// which is what AC2 asks for.
Map<String, dynamic> squadRow({
  Object? ownerProfileId = 'owner-profile-1',
  Object? ownerUserId = 'owner-user-1',
}) => {
  'id': 'squad-1',
  'sport': 'football',
  'owner_profile_id': ownerProfileId,
  'owner_user_id': ownerUserId,
  'name': 'The Regulars',
  'is_active': true,
  'created_at': '2026-01-01T00:00:00.000Z',
  'updated_at': '2026-01-02T00:00:00.000Z',
  'created_by_user_id': 'creator-user-1',
};

void main() {
  group('Squad.fromJson with a nulled owner (KAN-191 erasure shape)', () {
    test('decodes a row where both owner fields are null without throwing', () {
      // The exact row shape delete_my_account leaves behind after erasure.
      final squad = Squad.fromJson(
        squadRow(ownerProfileId: null, ownerUserId: null),
      );

      expect(squad.ownerProfileId, isNull);
      expect(squad.ownerUserId, isNull);

      // The rest of the squad must survive intact — erasure blanks the owner,
      // it does not damage the squad.
      expect(squad.id, 'squad-1');
      expect(squad.name, 'The Regulars');
      expect(squad.sport, 'football');
      expect(squad.isActive, true);
      expect(squad.createdByUserId, 'creator-user-1');
    });

    test('decodes a row where only owner_profile_id is null', () {
      final squad = Squad.fromJson(squadRow(ownerProfileId: null));

      expect(squad.ownerProfileId, isNull);
      expect(squad.ownerUserId, 'owner-user-1');
    });

    test('decodes a row where only owner_user_id is null', () {
      final squad = Squad.fromJson(squadRow(ownerUserId: null));

      expect(squad.ownerProfileId, 'owner-profile-1');
      expect(squad.ownerUserId, isNull);
    });

    test('still decodes a fully populated row unchanged', () {
      // Every row in production today is non-null; relaxing the model must not
      // change how those decode.
      final squad = Squad.fromJson(squadRow());

      expect(squad.ownerProfileId, 'owner-profile-1');
      expect(squad.ownerUserId, 'owner-user-1');
    });

    test('round-trips a nulled owner back to null, not to a placeholder', () {
      final json = Squad.fromJson(
        squadRow(ownerProfileId: null, ownerUserId: null),
      ).toJson();

      expect(json['owner_profile_id'], isNull);
      expect(json['owner_user_id'], isNull);
    });
  });
}
