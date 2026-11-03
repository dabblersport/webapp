import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/features/bench/presentation/controllers/bench_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'bench_mocks.mocks.dart';

void main() {
  late MockBenchRepository repo;
  late int written;
  late BenchController controller;

  setUp(() {
    repo = MockBenchRepository();
    written = 0;
    controller = BenchController(repository: repo, onWritten: () => written++);
  });

  tearDown(() => controller.dispose());

  test('a successful save refreshes the status and clears state', () async {
    const settings = BenchSettings();
    when(repo.save(settings)).thenAnswer((_) async => const Ok(unit));

    expect(await controller.save(settings), isTrue);

    verify(repo.save(settings)).called(1);
    expect(written, 1);
    expect(controller.state.isSubmitting, isFalse);
    expect(controller.state.failure, isNull);
    expect(controller.lastSettings, settings);
  });

  test('a successful end refreshes the status', () async {
    when(repo.end()).thenAnswer((_) async => const Ok(unit));

    expect(await controller.end(), isTrue);

    verify(repo.end()).called(1);
    expect(written, 1);
  });

  test('a failed save records the failure and does not refresh', () async {
    const failure = Failure(message: 'not_authenticated');
    when(repo.save(any)).thenAnswer((_) async => const Err(failure));

    expect(await controller.save(const BenchSettings()), isFalse);

    expect(written, 0);
    expect(controller.state.failedAction, BenchAction.save);
    expect(controller.state.failure, failure);

    controller.clearFailure();
    expect(controller.state.failure, isNull);
  });

  test('a failed end records the end action', () async {
    when(
      repo.end(),
    ).thenAnswer((_) async => const Err(Failure(message: 'offline')));

    expect(await controller.end(), isFalse);

    expect(written, 0);
    expect(controller.state.failedAction, BenchAction.end);
  });
}
