import 'package:dabbler/data/models/core/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-615: the users row parses with and without language_updated_at.
void main() {
  final row = <String, dynamic>{
    'id': 'u1',
    'language': 'ar',
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-02-01T00:00:00Z',
  };

  test('supabase row without language_updated_at parses, null', () {
    expect(UserModel.fromSupabaseJson(row).languageUpdatedAt, isNull);
  });

  test('supabase row with language_updated_at parses', () {
    final u = UserModel.fromSupabaseJson({
      ...row,
      'language_updated_at': '2026-03-01T10:00:00Z',
    });
    expect(u.languageUpdatedAt, DateTime.utc(2026, 3, 1, 10));
  });

  test('local json round trip keeps it, and null stays null', () {
    final u = UserModel.fromSupabaseJson({
      ...row,
      'language_updated_at': '2026-03-01T10:00:00Z',
    });
    expect(
      UserModel.fromJson(u.toJson()).languageUpdatedAt,
      u.languageUpdatedAt,
    );
    final n = UserModel.fromSupabaseJson(row);
    expect(UserModel.fromJson(n.toJson()).languageUpdatedAt, isNull);
    expect(u.copyWith(language: 'en').languageUpdatedAt, u.languageUpdatedAt);
  });
}
