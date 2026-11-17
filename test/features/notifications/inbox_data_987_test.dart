// KAN-987 (W1-F1): the envelope v2 fields parse (and a legacy row without
// them still does), and the bell badge follows the server count and the auth
// user: sign-in, sign-out and account switch, without a reload.
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'presentation/controllers/notifications_controller_test.dart'
    show FakeRealtime, FakeRepo, n;

/// A signed-in account the test can switch.
class _Account extends CacheAccountNotifier {
  _Account(super.accountId) : super.fixed();
  void set(String? id) => state = id;
}

const Map<String, dynamic> _legacyRow = {
  'id': 'n1',
  'to_user_id': 'u1',
  'kind_key': 'game.updated',
  'title': 'A game you joined was updated',
  'body': null,
  'action_route': '/sports/games/g1',
  'context': {'entity_id': 'g1'},
  'priority': 'normal',
  'is_read': false,
  'interaction_count': 0,
  'created_at': '2026-11-16T10:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('a legacy row (none of the v2 fields) parses as schema 1', () {
      final row = AppNotification.fromJson(_legacyRow);
      expect(row.schemaVersion, 1);
      expect(row.isV2, isFalse);
      expect(row.templateKey, isNull);
      expect(row.args, isEmpty);
      expect(row.groupKey, isNull);
      expect(row.title, 'A game you joined was updated');
      expect(row.actionRoute, '/sports/games/g1');
    });

    test('explicit nulls on a legacy row parse too', () {
      final row = AppNotification.fromJson({
        ..._legacyRow,
        'template_key': null,
        'args': null,
        'source_event_id': null,
        'dedupe_key': null,
        'group_key': null,
        'schema_version': null,
      });
      expect(row.schemaVersion, 1);
      expect(row.args, isEmpty);
    });

    test('a v2 row carries every envelope field', () {
      final row = AppNotification.fromJson({
        ..._legacyRow,
        'kind_key': 'game.time_changed',
        'template_key': 'game.time_changed',
        'args': {'title': 'Padel', 'title_ar': 'بادل', 'old': '6 PM'},
        'source_event_id': 'ev-42',
        'dedupe_key': 'game.time_changed:g1:3',
        'group_key': 'game:g1',
        'schema_version': 2,
      });
      expect(row.isV2, isTrue);
      expect(row.templateKey, 'game.time_changed');
      expect(row.args['title_ar'], 'بادل');
      expect(row.sourceEventId, 'ev-42');
      expect(row.dedupeKey, 'game.time_changed:g1:3');
      expect(row.groupKey, 'game:g1');
      expect(AppNotification.fromJson(row.toJson()), row);
    });
  });

  group('bell badge provider', () {
    late FakeRepo repo;
    late Map<String, FakeRealtime> channels;
    late _Account account;

    ProviderContainer container() {
      repo = FakeRepo();
      channels = {};
      account = _Account('u1');
      final c = ProviderContainer(
        overrides: [
          cacheAccountIdProvider.overrideWith((ref) => account),
          notificationsRepositoryProvider.overrideWithValue(repo),
          notificationRealtimeServiceProvider.overrideWith(
            (ref, userId) => channels.putIfAbsent(userId, FakeRealtime.new),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('is the server count, and follows Realtime and reads', () async {
      final c = container();
      repo.pages[null] = Ok([n('a'), n('b')]);
      repo.count = const Ok(12);
      final seen = <int>[];
      c.listen<int>(
        unreadNotificationCountProvider,
        (_, v) => seen.add(v),
        fireImmediately: true,
      );
      await pumpEventQueue();
      expect(c.read(unreadNotificationCountProvider), 12);

      repo.count = const Ok(13);
      channels['u1']!.onInsert!(n('c', createdAt: DateTime.utc(2026, 9)));
      await pumpEventQueue();
      expect(c.read(unreadNotificationCountProvider), 13);

      repo.count = const Ok(0);
      await c
          .read(notificationsControllerProvider('u1').notifier)
          .markAllRead();
      expect(c.read(unreadNotificationCountProvider), 0);
      expect(seen.first, 0, reason: 'nothing before the server answers');
    });

    test('sign-out clears the count, the list and the channel; another '
        'account reads its own', () async {
      final c = container();
      repo.pages[null] = Ok([n('a')]);
      repo.count = const Ok(4);
      c.listen<int>(unreadNotificationCountProvider, (_, __) {});
      await pumpEventQueue();
      expect(c.read(unreadNotificationCountProvider), 4);
      expect(channels['u1']!.subscribed, ['u1']);

      account.set(null);
      await pumpEventQueue();
      expect(c.read(unreadNotificationCountProvider), 0);
      expect(channels['u1']!.onInsert, isNull, reason: 'unsubscribed');
      expect(
        c.read(notificationsControllerProvider('u1')).notifications,
        isEmpty,
      );

      repo.count = const Ok(2);
      account.set('u2');
      await pumpEventQueue();
      expect(c.read(unreadNotificationCountProvider), 2);
      expect(channels['u2']!.subscribed, ['u2']);
      expect(channels['u1']!.onInsert, isNull, reason: 'u1 stays closed');
    });
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final (count, label) in const [(0, null), (7, '7'), (150, '99+')]) {
      testWidgets('${locale.languageCode}: badge for $count', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              unreadNotificationCountProvider.overrideWithValue(count),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: DabblerDesignSystemTheme.withFonts(
                DabblerDesignSystemTheme.withTokens(renderThemeBase()),
                locale: locale,
              ),
              home: const Scaffold(body: Center(child: NotificationBadge())),
            ),
          ),
        );
        if (label == null) {
          expect(find.byType(Text), findsNothing);
        } else {
          expect(find.text(label), findsOneWidget);
        }
      });
    }
  }
}
