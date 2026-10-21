// KAN-618: the meetup composer owns one client request id per create attempt.
// It is held and exposed only; the repository call is unchanged.
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/create_request_id.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meetup_screens_harness.dart';

/// Records the holder's id at each create call.
class _SpyRepository extends FakeMeetupRepository {
  _SpyRepository(this.holder);
  final CreateRequestId holder;
  final List<String?> ids = <String?>[];

  @override
  Future<Result<String, Failure>> create(
    CreateMeetupInput input, {
    String actorType = 'organiser',
  }) {
    ids.add(holder.current);
    return super.create(input, actorType: actorType);
  }
}

const Failure _offline = Failure(
  category: FailureCode.noInternet,
  message: 'No internet',
);

Future<_SpyRepository> _open(
  WidgetTester tester,
  CreateRequestId holder, {
  ValueChanged<String>? onCreated,
}) async {
  final repo = _SpyRepository(holder);
  await pumpMeetups(
    tester,
    SingleChildScrollView(
      child: MeetupComposerScreen(
        requestId: holder,
        onCreated: onCreated ?? (_) {},
        initialDate: DateTime(2030, 1, 15),
        initialStart: const TimeOfDay(hour: 18, minute: 0),
        initialPlace: const ComposerPlacePick(name: 'Kite Beach'),
      ),
    ),
    repo,
  );
  // The test font is wider than the real one; the When pills overflow here.
  tester.takeException();
  return repo;
}

Future<void> _fill(WidgetTester tester) async {
  await tester.tap(find.byType(DabblerEmojiTile).first);
  await tester.pump();
  await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
  await tester.pump();
  final indoor = find.byWidgetPredicate(
    (w) => w is DabblerChip && w.label == 'Indoor',
  );
  await tester.ensureVisible(indoor);
  await tester.tap(indoor);
  await tester.pump();
}

Future<void> _create(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(DabblerComposerSubmit));
  // The failure message can sit over the button; press it directly.
  tester
      .widget<DabblerComposerSubmit>(find.byType(DabblerComposerSubmit))
      .onPressed!();
  await settle(tester);
}

void main() {
  testWidgets('criterion 2: the id is null until the first Create tap', (
    tester,
  ) async {
    final holder = CreateRequestId();
    final repo = await _open(tester, holder);
    await _fill(tester);
    expect(holder.current, isNull);
    await _create(tester);
    expect(repo.ids.single, isNotNull);
  });

  testWidgets('criterion 3: after a failure the retry reuses the same id', (
    tester,
  ) async {
    final holder = CreateRequestId();
    final repo = await _open(tester, holder);
    repo.createFailure = _offline;
    await _fill(tester);
    await _create(tester);
    final first = holder.current;
    expect(first, isNotNull);
    // The form is kept.
    expect(find.text('Sunrise run'), findsOneWidget);

    await _create(tester);
    expect(repo.createCalls, hasLength(2));
    expect(repo.ids, [first, first]);
    expect(holder.current, first);
  });

  testWidgets('criterion 4: success clears the id; the next create is new', (
    tester,
  ) async {
    final holder = CreateRequestId();
    String? created;
    final repo = await _open(tester, holder, onCreated: (id) => created = id);
    repo.createFailure = _offline;
    await _fill(tester);
    await _create(tester);
    final failedId = holder.current;

    repo.createFailure = null;
    await _create(tester);
    expect(created, 'new1');
    expect(repo.ids.last, failedId);
    expect(holder.current, isNull);

    await _create(tester);
    expect(repo.ids.last, isNotNull);
    expect(repo.ids.last, isNot(failedId));
  });

  testWidgets('criterion 5: editing after a failure gives a new id', (
    tester,
  ) async {
    final holder = CreateRequestId();
    final repo = await _open(tester, holder);
    repo.createFailure = _offline;
    await _fill(tester);
    await _create(tester);
    final first = holder.current;

    await tester.enterText(find.byType(EditableText).first, 'Sunset run');
    await tester.pump();
    await _create(tester);
    expect(repo.ids, hasLength(2));
    expect(repo.ids.last, isNotNull);
    expect(repo.ids.last, isNot(first));
  });

  testWidgets('criterion 5: an edit then restoring the value still gives a '
      'new id', (tester) async {
    final holder = CreateRequestId();
    final repo = await _open(tester, holder);
    repo.createFailure = _offline;
    await _fill(tester);
    await _create(tester);
    final first = holder.current;

    await tester.enterText(find.byType(EditableText).first, 'Sunset run');
    await tester.pump();
    await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
    await tester.pump();
    await _create(tester);
    expect(repo.ids, hasLength(2));
    expect(repo.ids.last, isNotNull);
    expect(repo.ids.last, isNot(first));
  });

  testWidgets('criterion 5: closing the composer clears the id', (
    tester,
  ) async {
    final holder = CreateRequestId();
    final repo = await _open(tester, holder);
    repo.createFailure = _offline;
    await _fill(tester);
    await _create(tester);
    expect(holder.current, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(holder.current, isNull);
  });

  testWidgets('criterion 6: two Create taps in one frame make one submission', (
    tester,
  ) async {
    final holder = CreateRequestId();
    final repo = await _open(tester, holder);
    await _fill(tester);
    await tester.ensureVisible(find.byType(DabblerComposerSubmit));
    final submit = tester.widget<DabblerComposerSubmit>(
      find.byType(DabblerComposerSubmit),
    );
    submit.onPressed!();
    submit.onPressed!();
    await settle(tester);
    expect(repo.createCalls, hasLength(1));
    expect(repo.ids, hasLength(1));
  });
}
