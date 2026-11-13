// KAN-618: the holder of one client request id per create attempt.
import 'package:dabbler/core/utils/create_request_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final v4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('current is null until the first attempt', () {
    expect(CreateRequestId().current, isNull);
  });

  test('begin() makes a uuid v4 and returns the same id on a retry', () {
    final holder = CreateRequestId();
    final first = holder.begin();
    expect(first, matches(v4));
    expect(holder.current, first);
    expect(holder.begin(), first);
    expect(holder.current, first);
  });

  test('after clear() begin() returns a different id', () {
    final holder = CreateRequestId();
    final first = holder.begin();
    holder.clear();
    expect(holder.current, isNull);
    final second = holder.begin();
    expect(second, isNot(first));
    expect(second, matches(v4));
  });

  test('two holders never share an id', () {
    final a = CreateRequestId();
    final b = CreateRequestId();
    expect(a.begin(), isNot(b.begin()));
  });
}
