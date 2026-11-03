// KAN-738: the meetup data source writes only through RPCs. Events become the
// shared parent (KAN-708), so a direct table write here would be a second,
// unauthorised write path. The test reads the source: no `.insert`, `.update`,
// `.upsert` or `.delete` on a table, every `.from(...)` is a read, and each
// mutation goes through `.rpc(...)`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const path =
      'lib/features/meetups/data/datasources/supabase_meetup_datasource.dart';

  late String src;

  setUpAll(() {
    // Drop line comments so prose cannot satisfy or break a match.
    src = File(path)
        .readAsLinesSync()
        .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');
  });

  // Each `_client.from(...)` statement, up to its terminating semicolon.
  List<String> fromStatements() => RegExp(
    r'_client\s*\.from\([^;]*;',
  ).allMatches(src).map((m) => m.group(0)!).toList();

  test('no direct table write', () {
    final writes = RegExp(r'\.(insert|update|upsert|delete)\s*\(');
    expect(fromStatements().where(writes.hasMatch), isEmpty);
    expect(
      RegExp(r'_client\s*\.(insert|update|upsert|delete)').hasMatch(src),
      isFalse,
    );
  });

  test('every .from(...) chain is a select read', () {
    final froms = fromStatements();
    expect(
      froms,
      hasLength(3),
      reason: 'v_meetup_list, sports, sport_variants',
    );
    expect(froms.every((f) => f.contains('.select(')), isTrue);
  });

  test('every mutation goes through .rpc', () {
    final rpcs = RegExp(
      r'\.rpc\(\s*SupabaseConfig\.(\w+)',
    ).allMatches(src).map((m) => m.group(1)).toSet();
    expect(
      rpcs,
      containsAll(<String>[
        'rpcCreateMeetupFn',
        'rpcMeetupRsvpFn',
        'rpcMeetupCancelFn',
        'rpcMeetupUpdateFn',
        'rpcMeetupDecideRequestFn',
        'rpcMeetupRemoveAttendeeFn',
      ]),
    );
  });
}
