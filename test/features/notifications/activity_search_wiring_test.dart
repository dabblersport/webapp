// KAN-873: the Activity log search field on NotificationsScreenV2 is wired to
// ActivityLogController.changeQuery. Typing narrows the list, a chip keeps the
// query, clearing restores the selected category's list, and there is no
// filter icon beside the field.

import 'dart:convert';

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/notifications/presentation/screens/notifications_screen_v2.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_search_row.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_chips.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_test_harness.dart';
import '../profile/settings_test_overrides.dart' show FakeNotificationSettings;
import '../../support/render_mode.dart';

const String _userId = 'u-me';

String _fakeSession(String userId) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final int exp =
      DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/
      1000;
  final String jwt =
      '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': userId, 'exp': exp, 'aud': 'authenticated', 'role': 'authenticated'})}.sig';
  return jsonEncode({
    'access_token': jwt,
    'token_type': 'bearer',
    'expires_in': 2592000,
    'expires_at': exp,
    'refresh_token': 'r',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2024-01-01T00:00:00Z',
    },
  });
}

class _FakeNotifs extends StateNotifier<NotificationsState>
    implements NotificationsController {
  _FakeNotifs() : super(const NotificationsState());
  @override
  Future<void> refresh() async {}
  @override
  Future<void> loadMore() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mirrors the real controller's category/query contract: neither setter
/// resets the other. Records every changeQuery call.
class _FakeActivity extends StateNotifier<ActivityLogState>
    implements ActivityLogController {
  _FakeActivity(super.state);
  final List<String> queries = <String>[];
  @override
  Future<void> load() async {}
  @override
  void changeCategory(String? category) =>
      state = state.copyWith(category: category ?? 'all');
  @override
  void changeQuery(String query) {
    queries.add(query);
    state = state.copyWith(query: query);
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> loadMore() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// The list groups rows under a local-day header ("Today · …" vs "Yesterday ·
// …"). A fixture of "now minus minutes" lands on yesterday just after local
// midnight, and the longer header overflows the 357 px test row in the Ahem
// test font. Anchor to local midnight so every row is always today.
DateTime _earlyToday(int offsetSeconds) {
  final DateTime now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(seconds: offsetSeconds));
}

ActivityFeedEvent _event(String id, String type, String title) =>
    ActivityFeedEvent(
      id: id,
      subjectType: type,
      subjectId: '$id-s',
      verb: 'joined',
      timeBucket: 'past',
      happenedAt: _earlyToday(id.length),
      priority: 1,
      payload: {'title': title},
    );

List<ActivityFeedEvent> _activities() => [
  _event('a1', 'game', 'You joined Friday Football'),
  _event('a2', 'reward', 'Earned 50 points'),
  _event('a3', 'game', 'Created Sunday Padel'),
  _event('a4', 'reward', 'Earned Football badge'),
];

Future<_FakeActivity> _openLog(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _FakeActivity fake = _FakeActivity(
    ActivityLogState(
      activities: _activities(),
      loaded: true,
      feedHasMore: false,
      socialHasMore: false,
    ),
  );
  const Locale locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsControllerProvider(
          _userId,
        ).overrideWith((ref) => _FakeNotifs()),
        activityLogControllerProvider.overrideWith((ref) => fake),
        myProfileIdProvider.overrideWith((ref) async => null),
        notificationSettingsControllerProvider.overrideWith(
          (ref) => FakeNotificationSettings(
            const NotificationSettings(
              userId: _userId,
              quietStartMin: 23 * 60,
              quietEndMin: 7 * 60,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: const NotificationsScreenV2(),
      ),
    ),
  );
  await _settle(tester);
  await tester.tap(
    find.text(lookupAppLocalizations(locale).notif_title_activity_log),
  );
  await _settle(tester);
  return fake;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _field => find.descendant(
  of: find.byType(ActivitySearchRow),
  matching: find.byType(EditableText),
);

Finder get _clearButton => find.byWidgetPredicate(
  (Widget w) => w is DabblerIcon && w.name == DabblerTextField.clearIconName,
);

/// The chip row builds lazily: drag it until the chip is built, then tap.
Future<void> _tapChip(WidgetTester tester, String label) async {
  final Finder chip = find.text(label);
  await tester.dragUntilVisible(
    chip,
    find.byType(ChipsRow),
    const Offset(-200, 0),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(chip);
}

int _rows() => find.byType(DabblerActivityRow).evaluate().length;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initHomeTestSupabase();
    await Supabase.instance.client.auth.recoverSession(_fakeSession(_userId));
  });

  testWidgets('typing calls changeQuery and narrows the list', (tester) async {
    final fake = await _openLog(tester);
    expect(_rows(), 4);
    await tester.enterText(_field, 'football');
    await _settle(tester);
    expect(fake.queries.last, 'football');
    expect(fake.state.query, 'football');
    expect(_rows(), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a category chip keeps the query', (tester) async {
    final fake = await _openLog(tester);
    await tester.enterText(_field, 'football');
    await _settle(tester);
    await _tapChip(tester, l10n.notif_chip_rewards);
    await _settle(tester);
    expect(fake.state.category, 'reward');
    expect(fake.state.query, 'football');
    expect(_rows(), 1);
    expect(find.text('Earned Football badge'), findsOneWidget);
  });

  testWidgets('clearing restores the selected category list', (tester) async {
    final fake = await _openLog(tester);
    await _tapChip(tester, l10n.notif_chip_rewards);
    await _settle(tester);
    await tester.enterText(_field, 'football');
    await _settle(tester);
    expect(_rows(), 1);
    expect(_clearButton, findsOneWidget);
    await tester.tap(_clearButton);
    await _settle(tester);
    expect(fake.queries.last, '');
    expect(fake.state.query, '');
    expect(fake.state.category, 'reward');
    expect(_rows(), 2);
  });

  testWidgets('no filter icon button next to the search field', (tester) async {
    await _openLog(tester);
    final Finder row = find.byType(ActivitySearchRow);
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byType(IconButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.byType(DabblerButton)),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is DabblerIcon && w.name == 'filter',
      ),
      findsNothing,
    );
    final ActivitySearchRow widget = tester.widget(row);
    expect(widget.onChanged, isNotNull);
    expect(widget.onClear, isNotNull);
    expect(find.byType(ChipsRow), findsOneWidget);
  });
}
