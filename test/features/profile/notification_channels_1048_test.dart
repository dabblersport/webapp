// KAN-1048 (NOTIF-4): the channel groups on the notification settings
// screen, from a faked repository: grouped rendering in sort order, the group
// switch (any-on, group RPC), a channel switch, the locked security group, a
// failed save reverting with a toast, the RPC payloads, and the RTL layout.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/data/models/notification_channel.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/notification_channels_repository.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/notification_settings_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';
import 'notification_settings_fakes.dart';

NotificationChannel _ch(
  String key,
  String group,
  int order, {
  bool muted = false,
  bool canMute = true,
}) => NotificationChannel(
  key: key,
  groupKey: group,
  labelEn: 'EN $key',
  labelAr: 'AR $key',
  canMute: canMute,
  muted: muted,
  sortOrder: order,
);

List<NotificationChannel> _channels() => [
  _ch('security_alerts', 'security', 70, canMute: false),
  _ch('games_reminders', 'games', 11),
  _ch('games_invites', 'games', 10, muted: true),
  _ch('social_followers', 'social', 50, muted: true),
  _ch('social_likes', 'social', 51, muted: true),
];

class _FakeChannelsRepo implements NotificationChannelsRepository {
  _FakeChannelsRepo(this.channels);
  List<NotificationChannel> channels;
  bool fail = false;
  final List<(String, String, bool)> calls = [];

  @override
  Future<Result<List<NotificationChannel>, Failure>> list() async =>
      Ok(channels);

  @override
  Future<Result<bool, Failure>> setChannelMuted(String k, bool m) async {
    calls.add(('channel', k, m));
    if (fail) return const Err(Failure(category: FailureCode.server));
    return Ok(m);
  }

  @override
  Future<Result<int, Failure>> setGroupMuted(String g, bool m) async {
    calls.add(('group', g, m));
    if (fail) return const Err(Failure(category: FailureCode.server));
    return const Ok(2);
  }
}

Future<_FakeChannelsRepo> _pump(
  WidgetTester tester,
  Locale locale, {
  bool pushEnabled = true,
}) async {
  tester.view.physicalSize = const Size(393, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeChannelsRepo(_channels());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationSettingsRepositoryProvider.overrideWithValue(
          FakeNotificationSettingsRepo(
            NotificationSettings.defaults(
              'u1',
            ).copyWith(pushEnabled: pushEnabled),
          ),
        ),
        notificationChannelsRepositoryProvider.overrideWithValue(repo),
        notificationOsPushDeniedProvider.overrideWith((ref) async => false),
        notificationMutedConversationsProvider.overrideWith(
          (ref) async => const [],
        ),
      ],
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: const NotificationSettingsScreen(),
      ),
    ),
  );
  await _settle(tester);
  return repo;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DabblerToggle _toggle(WidgetTester tester, String key) => tester.widget(
  find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(DabblerToggle),
  ),
);

Future<void> _tap(WidgetTester tester, String key) async {
  final Finder f = find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(DabblerToggle),
  );
  await tester.ensureVisible(f);
  await tester.tap(f);
  await _settle(tester);
}

void main() {
  setUpAll(initHomeTestSupabase);

  test('groups follow sort_order; channels sort inside a group', () {
    final groups = groupNotificationChannels(_channels());
    expect(groups.map((g) => g.key), ['games', 'social', 'security']);
    expect(groups.first.channels.map((c) => c.key), [
      'games_invites',
      'games_reminders',
    ]);
    expect(groups.first.anyOn, isTrue);
    expect(groups[1].anyOn, isFalse);
    expect(groups.last.canMute, isFalse);
  });

  test('repository sends the KAN-1045 RPCs with their params', () async {
    final calls = <(String, Map<String, dynamic>?)>[];
    final repo = NotificationChannelsRepositoryImpl.withRpc((
      fn, {
      params,
    }) async {
      calls.add((fn, params));
      return switch (fn) {
        'rpc_list_notification_channels' => [
          {
            'channel_key': 'games_invites',
            'group_key': 'games',
            'label_en': 'Invites',
            'label_ar': 'دعوات',
            'can_mute': true,
            'muted': true,
            'sort_order': 10,
          },
        ],
        'rpc_set_notification_group_muted' => 3,
        _ => true,
      };
    });
    final list = (await repo.list()).requireValue;
    expect(list.single.muted, isTrue);
    expect(list.single.label('ar'), 'دعوات');
    await repo.setChannelMuted('games_invites', true);
    expect((await repo.setGroupMuted('games', false)).requireValue, 3);
    expect(calls[1].$1, 'rpc_set_notification_channel_muted');
    expect(calls[1].$2, {'p_channel_key': 'games_invites', 'p_muted': true});
    expect(calls[2].$1, 'rpc_set_notification_group_muted');
    expect(calls[2].$2, {'p_group_key': 'games', 'p_muted': false});
    final failing = NotificationChannelsRepositoryImpl.withRpc(
      (fn, {params}) async => throw Exception('22023'),
    );
    expect((await failing.setChannelMuted('x', true)).isFailure, isTrue);
  });

  for (final Locale locale in const [Locale('en'), Locale('ar')]) {
    final AppLocalizations l = lookupAppLocalizations(locale);
    final String lang = locale.languageCode;

    testWidgets('[$lang] renders groups in order with localized labels', (
      tester,
    ) async {
      await _pump(tester, locale);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('notif-group-games')),
          matching: find.text(l.notif_channels_group_games),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l.notif_channels_all(l.notif_channels_group_social)),
        findsOneWidget,
      );
      final String prefix = lang == 'ar' ? 'AR' : 'EN';
      expect(find.text('$prefix games_invites'), findsOneWidget);
      final double games = tester
          .getTopLeft(find.byKey(const ValueKey('notif-group-games')))
          .dy;
      final double social = tester
          .getTopLeft(find.byKey(const ValueKey('notif-group-social')))
          .dy;
      final double security = tester
          .getTopLeft(find.byKey(const ValueKey('notif-group-security')))
          .dy;
      expect(games < social && social < security, isTrue);
      expect(_toggle(tester, 'notif-group-toggle-games').checked, isTrue);
      expect(_toggle(tester, 'notif-group-toggle-social').checked, isFalse);
      expect(_toggle(tester, 'notif-channel-games_invites').checked, isFalse);
    });
  }

  testWidgets('the group switch calls the group RPC and flips every channel', (
    tester,
  ) async {
    final repo = await _pump(tester, const Locale('en'));
    await _tap(tester, 'notif-group-toggle-social');
    expect(repo.calls, [('group', 'social', false)]);
    expect(_toggle(tester, 'notif-group-toggle-social').checked, isTrue);
    expect(_toggle(tester, 'notif-channel-social_likes').checked, isTrue);
    expect(_toggle(tester, 'notif-channel-social_followers').checked, isTrue);

    await _tap(tester, 'notif-group-toggle-games');
    expect(repo.calls.last, ('group', 'games', true));
    expect(_toggle(tester, 'notif-channel-games_reminders').checked, isFalse);
  });

  testWidgets('a channel switch calls the channel RPC', (tester) async {
    final repo = await _pump(tester, const Locale('en'));
    await _tap(tester, 'notif-channel-games_reminders');
    expect(repo.calls, [('channel', 'games_reminders', true)]);
    // The last on channel went off: the group switch goes off with it.
    expect(_toggle(tester, 'notif-group-toggle-games').checked, isFalse);
  });

  testWidgets('a failed save reverts and shows an error toast', (tester) async {
    final repo = await _pump(tester, const Locale('en'));
    repo.fail = true;
    await _tap(tester, 'notif-channel-games_reminders');
    expect(_toggle(tester, 'notif-channel-games_reminders').checked, isTrue);
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.notif_channels_update_failed), findsOneWidget);
  });

  testWidgets('security is locked on with a note', (tester) async {
    final repo = await _pump(tester, const Locale('en'));
    final l = lookupAppLocalizations(const Locale('en'));
    expect(_toggle(tester, 'notif-group-toggle-security').disabled, isTrue);
    expect(_toggle(tester, 'notif-group-toggle-security').checked, isTrue);
    expect(_toggle(tester, 'notif-channel-security_alerts').disabled, isTrue);
    expect(find.text(l.notif_channels_locked_note), findsOneWidget);
    await _tap(tester, 'notif-channel-security_alerts');
    expect(repo.calls, isEmpty);
  });

  testWidgets('push off locks every channel switch', (tester) async {
    await _pump(tester, const Locale('en'), pushEnabled: false);
    expect(_toggle(tester, 'notif-group-toggle-games').disabled, isTrue);
    expect(_toggle(tester, 'notif-channel-games_invites').disabled, isTrue);
  });

  testWidgets('[ar] RTL: the toggle sits on the left of its label', (
    tester,
  ) async {
    await _pump(tester, const Locale('ar'));
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('notif-group-games'))),
      ),
      TextDirection.rtl,
    );
    final Finder row = find.byKey(
      const ValueKey('notif-channel-games_invites'),
    );
    final double toggleX = tester
        .getCenter(
          find.descendant(of: row, matching: find.byType(DabblerToggle)),
        )
        .dx;
    final double labelX = tester.getCenter(find.text('AR games_invites')).dx;
    expect(toggleX < labelX, isTrue);
    expect(tester.takeException(), isNull);
  });
}
