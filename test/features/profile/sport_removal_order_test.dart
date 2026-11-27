import 'package:dabbler/features/profile/domain/services/sport_removal.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSteps implements SportRemovalSteps {
  _FakeSteps({this.interestFailures = 0});

  int interestFailures;
  final List<String> calls = [];

  @override
  Future<List<Map<String, dynamic>>> deleteSportRecord() async {
    calls.add('delete');
    return [
      {'profile_id': 'p1', 'sport': 'padel', 'skill_level': 3},
    ];
  }

  @override
  Future<void> updateInterests(List<String> interests) async {
    calls.add('interests:${interests.join(',')}');
    if (interestFailures > 0) {
      interestFailures--;
      throw Exception('contributor_sports_incomplete');
    }
  }

  @override
  Future<void> restoreSportRecord(List<Map<String, dynamic>> rows) async {
    calls.add('restore:${rows.first['skill_level']}');
  }
}

void main() {
  test('deletes the sport row before updating interests', () async {
    final steps = _FakeSteps();
    final result = await removeSportInOrder(steps, ['a']);
    expect(result.isSuccess, isTrue);
    expect(steps.calls, ['delete', 'interests:a']);
  });

  test('retries the interests write once', () async {
    final steps = _FakeSteps(interestFailures: 1);
    final result = await removeSportInOrder(steps, ['a']);
    expect(result.isSuccess, isTrue);
    expect(steps.calls, ['delete', 'interests:a', 'interests:a']);
  });

  test('restores the deleted row when interests keeps failing', () async {
    final steps = _FakeSteps(interestFailures: 2);
    final result = await removeSportInOrder(steps, ['a']);
    expect(result.isFailure, isTrue);
    expect(steps.calls, ['delete', 'interests:a', 'interests:a', 'restore:3']);
  });
}
