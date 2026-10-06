import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/presentation_context.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _proc = FeedbackProcessing(kind: ProcessingKind.spinnerLabel, label: 'J');
const _info = FeedbackInformation(message: 'i');
const _warn = FeedbackInformation(message: 'w', tone: InfoTone.warning);
const _ok = FeedbackResult.success('ok');
const _err = FeedbackResult.error('err');

void main() {
  late ProviderContainer c;
  FeedbackCenter center() => c.read(feedbackCenterProvider.notifier);
  FeedbackCenterState s() => c.read(feedbackCenterProvider);

  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  group('model', () {
    test('initial state is Idle and absent', () {
      expect(s().visible, isA<FeedbackIdle>());
      expect(s().surface, ShellSurface.absent);
    });
    test('priority order: error > processing > success > warning > info', () {
      final ps = [
        _err,
        _proc,
        _ok,
        _warn,
        _info,
      ].map(feedbackPriority).toList();
      expect(ps, [...ps]..sort());
      expect(ps.toSet().length, 5);
    });
    test('error with retry is sticky, plain error is not', () {
      expect(
        FeedbackResult.error(
          'e',
          action: FeedbackAction(label: 'Retry', onPressed: () {}),
        ).isSticky,
        isTrue,
      );
      expect(_err.isSticky, isFalse);
      expect(_ok.isSticky, isFalse);
    });
    test('progress clamps and becomes determinate', () {
      final p = _proc.withProgress(1.7);
      expect(p.progress, 1);
      expect(p.kind, ProcessingKind.determinate);
    });
  });

  group('surface current (action area)', () {
    setUp(() => center().setSurface(ShellSurface.current));

    test('one current; others queued by priority then arrival', () {
      center().inform(_info);
      center().inform(_warn);
      center().inform(const FeedbackInformation(message: 'i2'));
      expect(s().current!.state, _warn);
      expect(s().current!.target, FeedbackTarget.actionArea);
      expect(s().queue.map((e) => (e.state as FeedbackInformation).message), [
        'i2',
      ]);
    });

    test('info never interrupts processing; progress keeps flowing', () {
      final id = center().begin(_proc);
      center().inform(_info);
      expect(s().current!.id, id);
      center().progress(id, 0.4);
      expect((s().current!.state as FeedbackProcessing).progress, 0.4);
      expect(s().queue.single.state, _info);
    });

    test('success does not interrupt processing; error does', () {
      final id = center().begin(_proc);
      center().announce(_ok);
      expect(s().current!.id, id);
      final e = center().announce(_err);
      expect(s().current!.id, e);
      expect(s().queue.any((x) => x.id == id), isTrue);
    });

    test('newest processing is current; older keeps running in queue', () {
      final a = center().begin(_proc);
      final b = center().begin(_proc);
      expect(s().current!.id, b);
      center().succeed(a, _ok);
      expect(s().current!.id, b);
      expect(s().queue.single.state, _ok);
    });

    test('same operation id replaces in place', () {
      final id = center().begin(_proc);
      center().succeed(id, _ok);
      expect(s().current!.id, id);
      expect(s().current!.state, _ok);
      expect(s().queue, isEmpty);
    });

    test('dedupe by key replaces state and keeps position', () {
      center().begin(_proc);
      final a = center().inform(_info, key: 'k');
      final b = center().inform(
        const FeedbackInformation(message: 'i-new'),
        key: 'k',
      );
      expect(b, a);
      expect(s().queue.length, 1);
      expect((s().queue.single.state as FeedbackInformation).message, 'i-new');
    });

    test('dismissed key suppresses Information but never Results', () {
      final a = center().inform(_info, key: 'k');
      center().dismiss(a);
      expect(s().dismissedKeys, contains('k'));
      center().inform(_info, key: 'k');
      expect(s().current, isNull);
      center().announce(_ok, key: 'k');
      expect(s().current!.state, _ok);
    });

    test('consumed (timeout/dismiss) pops the next', () {
      final a = center().announce(_ok);
      center().inform(_info);
      center().consumed(a);
      expect(s().current!.state, _info);
      center().consumed(s().current!.id);
      expect(s().visible, isA<FeedbackIdle>());
    });

    test('higher priority preempts dismissible info, which is dropped', () {
      center().inform(_info);
      center().announce(_ok);
      expect(s().current!.state, _ok);
      expect(s().queue, isEmpty);
    });

    test('sticky non-dismissible info is re-queued when preempted', () {
      const sticky = FeedbackInformation(
        message: 's',
        dismissible: false,
        duration: Duration.zero,
      );
      center().inform(sticky);
      center().announce(_ok);
      expect(s().queue.single.state, sticky);
    });

    test('error with retry stays current until handled', () {
      final e = center().announce(
        FeedbackResult.error(
          'e',
          action: FeedbackAction(label: 'Retry', onPressed: () {}),
        ),
      );
      center().begin(_proc);
      center().announce(_err);
      expect(s().current!.id, e);
      center().consumed(e);
      expect(s().current!.state, _err);
    });

    test('queue capped at 5, oldest information dropped first', () {
      center().begin(_proc);
      for (var i = 0; i < 4; i++) {
        center().inform(FeedbackInformation(message: 'i$i'));
      }
      center().announce(_ok);
      center().announce(_ok, key: 'x');
      expect(s().queue.length, FeedbackCenter.maxQueue);
      final msgs = s().queue
          .map((e) => e.state)
          .whereType<FeedbackInformation>()
          .map((e) => e.message);
      expect(msgs, isNot(contains('i0')));
    });

    test('blocked surface holds; presented when unblocked', () {
      center().setSurface(ShellSurface.blocked);
      center().announce(_ok);
      expect(s().current!.target, FeedbackTarget.hold);
      expect(s().outbox, isEmpty);
      center().setSurface(ShellSurface.current);
      expect(s().current!.target, FeedbackTarget.actionArea);
    });
  });

  group('branch change', () {
    test('page-scoped cleared, shell-scoped survives', () {
      center().setSurface(ShellSurface.current);
      center().setBranch(0);
      final shell = center().begin(_proc);
      center().inform(_info, scope: FeedbackScope.page);
      center().begin(_proc, scope: FeedbackScope.page);
      center().setBranch(1);
      final all = [s().current, ...s().queue].whereType<FeedbackEntry>();
      expect(all.map((e) => e.id), [shell]);
    });
    test('same branch index clears nothing', () {
      center().setSurface(ShellSurface.current);
      center().setBranch(2);
      center().inform(_info, scope: FeedbackScope.page);
      center().setBranch(2);
      expect(s().current, isNotNull);
    });
  });

  group('one-presenter guarantee (surface absent = today)', () {
    test('processing is not presented; info/result go to toast once', () {
      final id = center().begin(_proc);
      expect(s().current!.target, FeedbackTarget.none);
      expect(s().outbox, isEmpty);
      center().inform(_info);
      expect(s().outbox.single.target, FeedbackTarget.toast);
      expect(s().current!.id, id);
      center().succeed(id, _ok);
      expect(s().outbox.length, 2);
      expect(s().current, isNull);
    });

    test('result delivered as toast is never re-shown in action area', () {
      final id = center().begin(_proc);
      center().succeed(id, _ok);
      center().delivered(s().outbox.single.id);
      center().setSurface(ShellSurface.current);
      expect(s().current, isNull);
      expect(s().outbox, isEmpty);
    });

    test('an entry has exactly one target', () {
      center().setSurface(ShellSurface.current);
      final a = center().announce(_ok);
      center().inform(_warn);
      expect(s().current!.target, FeedbackTarget.actionArea);
      expect(s().outbox, isEmpty);
      center().setSurface(ShellSurface.absent);
      // The already-presented action-area entry is not duplicated as toast.
      expect(s().outbox.map((e) => e.id), isNot(contains(a)));
      expect(s().outbox.single.state, _warn);
    });

    test('op resumes in action area when returning before it resolves', () {
      final id = center().begin(_proc);
      center().setSurface(ShellSurface.current);
      expect(s().current!.id, id);
      expect(s().current!.target, FeedbackTarget.actionArea);
    });
  });

  group('run lifecycle', () {
    test('processing -> success; returns the task Result', () async {
      final f = center().run<int>(
        processing: _proc,
        task: () async => const Ok(3),
        success: (v) => FeedbackResult.success('got $v'),
        failure: (f, r) => _err,
      );
      expect(s().current!.isProcessing, isTrue);
      final r = await f;
      expect(r.requireValue, 3);
      expect((s().outbox.single.state as FeedbackResult).message, 'got 3');
    });

    test('error -> retry -> success on the same operation id', () async {
      var calls = 0;
      VoidCallback? retry;
      center().setSurface(ShellSurface.current);
      final r = await center().run<int>(
        key: 'op',
        processing: _proc,
        task: () async => ++calls == 1
            ? const Err(Failure(category: FailureCode.unknown, message: 'x'))
            : const Ok(1),
        success: (_) => _ok,
        failure: (f, rt) {
          retry = rt;
          return FeedbackResult.error(
            f.message,
            action: FeedbackAction(label: 'Retry', onPressed: rt),
          );
        },
      );
      expect(r.isFailure, isTrue);
      final id = s().current!.id;
      expect((s().current!.state as FeedbackResult).isSticky, isTrue);
      retry!();
      expect(s().current!.id, id);
      expect(s().current!.isProcessing, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(s().current!.id, id);
      expect(s().current!.state, _ok);
      expect(calls, 2);
    });

    test('a throwing task becomes an error Result, never throws', () async {
      final r = await center().run<int>(
        processing: _proc,
        task: () async => throw StateError('boom'),
        success: (_) => _ok,
        failure: (f, _) => _err,
      );
      expect(r.isFailure, isTrue);
      expect(s().outbox.single.state, _err);
    });
  });
}
