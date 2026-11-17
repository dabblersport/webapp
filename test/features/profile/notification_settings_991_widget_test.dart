// KAN-991: the notification settings screen, every section and state, in EN
// and AR. Categories with in-app and push (no Email, SMS, Friends, Login
// alerts or Booking row; Security always on), message preview, the quiet
// hours editor (off, default, custom, invalid; 12h and 24h), reminder rungs,
// the muted list (empty, list, Unmute, Undo), the OS-denied state and a
// failed save.

import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_prefs_sheet.dart';
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

class _Env {
  _Env(NotificationSettings s, {bool fail = false, this.osDenied = false})
    : repo = FakeNotificationSettingsRepo(s, failUpdates: fail);

  final FakeNotificationSettingsRepo repo;
  final bool osDenied;
  List<MyConversation> chats = const <MyConversation>[];
  final List<(String, bool)> chatMutes = <(String, bool)>[];
  int openedSettings = 0;
}

Future<_Env> _pump(
  WidgetTester tester,
  Locale locale,
  _Env env, {
  bool use24h = true,
  Widget home = const NotificationSettingsScreen(),
}) async {
  tester.view.physicalSize = const Size(393, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationSettingsRepositoryProvider.overrideWithValue(env.repo),
        notificationOsPushDeniedProvider.overrideWith(
          (ref) async => env.osDenied,
        ),
        notificationMutedConversationsProvider.overrideWith(
          (ref) async => env.chats,
        ),
        notificationSetConversationMutedProvider.overrideWithValue((
          id,
          muted,
        ) async {
          env.chatMutes.add((id, muted));
          return true;
        }),
        notificationOpenSystemSettingsProvider.overrideWithValue(
          () async => env.openedSettings++,
        ),
      ],
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
          child: DabblerToastProvider(child: child!),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: home,
      ),
    ),
  );
  await _settle(tester);
  return env;
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

Future<void> _tapToggle(WidgetTester tester, String key) async {
  final Finder f = find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(DabblerToggle),
  );
  await tester.ensureVisible(f);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final Finder f = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _pickTime(WidgetTester tester, String row, TimeOfDay t) async {
  await _tapKey(tester, row);
  final DabblerTimePicker picker = tester.widget(
    find.byType(DabblerTimePicker),
  );
  picker.onChanged!(t);
  await tester.pump();
  tester.widget<DabblerTimePicker>(find.byType(DabblerTimePicker)).onConfirm!();
  await _settle(tester);
}

DabblerButton _save(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey<String>('notif-quiet-save')));

MyConversation _chat(String id, String title) => MyConversation(
  conversationId: id,
  gameId: 'g-$id',
  state: MyConversationState.values.first,
  title: title,
  muted: true,
);

void main() {
  setUpAll(initHomeTestSupabase);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final AppLocalizations l = lookupAppLocalizations(locale);
    final String lang = locale.languageCode;

    testWidgets('[$lang] categories: in-app + push, no removed rows', (
      tester,
    ) async {
      await _pump(tester, locale, _Env(NotificationSettings.defaults('u1')));
      expect(tester.takeException(), isNull);
      for (final t in [
        l.notif_settings_cat_social,
        l.notif_settings_cat_messages,
        l.notif_settings_cat_games,
        l.notif_settings_cat_meetups,
        l.notif_settings_cat_system,
        l.notif_settings_cat_security,
      ]) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      for (final gone in [
        l.notif_settings_email,
        l.notif_settings_sms,
        l.notif_settings_kind_friends,
        l.notif_settings_kind_booking,
        l.notif_pref_payments_title,
        l.notif_settings_quiet_urgent,
        l.notif_settings_quiet_all,
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      for (final c in ['social', 'messages', 'games', 'meetups']) {
        expect(_toggle(tester, 'notif-$c-in_app').checked, isTrue);
        expect(_toggle(tester, 'notif-$c-push').checked, isTrue);
      }
      // Rewards & announcements is in-app only (SET-01).
      expect(find.byKey(const ValueKey('notif-system-in_app')), findsOneWidget);
      expect(find.byKey(const ValueKey('notif-system-push')), findsNothing);
      expect(find.byKey(const ValueKey('notif-booking-in_app')), findsNothing);
    });

    testWidgets('[$lang] security is always on and cannot be switched', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(NotificationSettings.defaults('u1')),
      );
      final DabblerToggle t = _toggle(tester, 'notif-category-security');
      expect(t.checked, isTrue);
      expect(t.disabled, isTrue);
      expect(t.onChanged, isNull);
      await _tapToggle(tester, 'notif-category-security');
      expect(env.repo.patches, isEmpty);
    });

    testWidgets('[$lang] a category switch saves that channel only', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(NotificationSettings.defaults('u1')),
      );
      await _tapToggle(tester, 'notif-games-push');
      expect(env.repo.patches.single, {
        'category_prefs': {
          'games': {'push': false},
        },
      });
      expect(_toggle(tester, 'notif-games-push').checked, isFalse);
      expect(_toggle(tester, 'notif-games-in_app').checked, isTrue);
    });

    testWidgets('[$lang] a failed save restores the value and says so', (
      tester,
    ) async {
      await _pump(
        tester,
        locale,
        _Env(NotificationSettings.defaults('u1'), fail: true),
      );
      await _tapToggle(tester, 'notif-social-in_app');
      expect(_toggle(tester, 'notif-social-in_app').checked, isTrue);
      expect(find.text(l.notif_settings_update_failed('boom')), findsOneWidget);
    });

    testWidgets('[$lang] OS denied: banner, push disabled, in-app works', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(NotificationSettings.defaults('u1'), osDenied: true),
      );
      expect(find.byKey(const ValueKey('notif-os-denied')), findsOneWidget);
      expect(find.text(l.notif_settings_os_denied_title), findsOneWidget);
      for (final c in ['social', 'messages', 'games', 'meetups']) {
        expect(_toggle(tester, 'notif-$c-push').disabled, isTrue, reason: c);
        expect(_toggle(tester, 'notif-$c-in_app').disabled, isFalse);
      }
      expect(_toggle(tester, 'notif-rung-going-24h').disabled, isTrue);
      await _tapToggle(tester, 'notif-social-in_app');
      expect(env.repo.patches.single, {
        'category_prefs': {
          'social': {'in_app': false},
        },
      });
      await tester.tap(find.text(l.notif_settings_open_settings));
      await _settle(tester);
      expect(env.openedSettings, 1);
    });

    testWidgets('[$lang] OS allowed: no banner, push enabled', (tester) async {
      await _pump(tester, locale, _Env(NotificationSettings.defaults('u1')));
      expect(find.byKey(const ValueKey('notif-os-denied')), findsNothing);
      expect(_toggle(tester, 'notif-social-push').disabled, isFalse);
    });

    testWidgets('[$lang] message preview: default, then sender only', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(NotificationSettings.defaults('u1')),
      );
      final DabblerRadio full = tester.widget(
        find.byKey(const ValueKey('notif-preview-full')),
      );
      expect(full.selected, isTrue);
      expect(
        find.text(l.notif_settings_preview_sample_message),
        findsOneWidget,
      );
      expect(find.text(l.notif_settings_preview_note), findsOneWidget);
      await _tapKey(tester, 'notif-preview-name');
      expect(env.repo.patches.single, {'message_preview': 'sender_only'});
      expect(find.text(l.notif_settings_preview_sample_hidden), findsOneWidget);
      expect(find.text(l.notif_settings_preview_sample_message), findsNothing);
    });

    testWidgets('[$lang] quiet hours off, then on at 00:00 – 08:00, saved', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(NotificationSettings.defaults('u1')),
      );
      expect(find.text(l.notif_settings_quiet_toggle_off), findsOneWidget);
      expect(find.byKey(const ValueKey('notif-quiet-from')), findsNothing);
      expect(_save(tester).onPressed, isNull);
      expect(find.text(l.notif_settings_quiet_note), findsOneWidget);
      await _tapToggle(tester, 'notif-quiet-toggle');
      expect(
        find.text(l.notif_settings_quiet_toggle_on('00:00', '08:00')),
        findsOneWidget,
      );
      expect(env.repo.patches, isEmpty, reason: 'nothing saved before Save');
      await _tapKey(tester, 'notif-quiet-save');
      expect(env.repo.patches.single, {
        'quiet_hours_enabled': true,
        'quiet_start_min': 0,
        'quiet_end_min': 480,
      });
      expect(find.text(l.notif_settings_quiet_saved), findsOneWidget);
    });

    testWidgets('[$lang] quiet hours custom, then invalid blocks Save', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(
          const NotificationSettings(
            userId: 'u1',
            quietStartMin: 22 * 60 + 30,
            quietEndMin: 6 * 60 + 30,
          ),
        ),
      );
      expect(
        find.text(l.notif_settings_quiet_toggle_on('22:30', '06:30')),
        findsOneWidget,
      );
      await _pickTime(
        tester,
        'notif-quiet-to',
        const TimeOfDay(hour: 22, minute: 30),
      );
      expect(find.byKey(const ValueKey('notif-quiet-invalid')), findsOneWidget);
      expect(find.text(l.notif_settings_quiet_invalid), findsOneWidget);
      expect(_save(tester).onPressed, isNull);
      await _pickTime(
        tester,
        'notif-quiet-to',
        const TimeOfDay(hour: 7, minute: 0),
      );
      expect(find.byKey(const ValueKey('notif-quiet-invalid')), findsNothing);
      await _tapKey(tester, 'notif-quiet-save');
      expect(env.repo.patches.single, {
        'quiet_hours_enabled': true,
        'quiet_start_min': 1350,
        'quiet_end_min': 420,
      });
    });

    testWidgets('[$lang] quiet hours follow a 12-hour device', (tester) async {
      await _pump(
        tester,
        locale,
        _Env(
          const NotificationSettings(
            userId: 'u1',
            quietStartMin: 23 * 60,
            quietEndMin: 7 * 60,
          ),
        ),
        use24h: false,
      );
      final Finder value = find.descendant(
        of: find.byKey(const ValueKey('notif-quiet-from')),
        matching: find.textContaining('11:00'),
      );
      expect(value, findsOneWidget);
      expect(find.textContaining('23:00'), findsNothing);
      // The 09:00 rung label follows it too.
      expect(find.textContaining('9:00'), findsWidgets);
      expect(find.textContaining('09:00'), findsNothing);
    });

    testWidgets('[$lang] reminders: four rungs each, saved separately', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(NotificationSettings.defaults('u1')),
      );
      for (final g in ['going', 'interested']) {
        for (final r in ['24h', '09:00', '2h', '30m']) {
          expect(_toggle(tester, 'notif-rung-$g-$r').checked, isTrue);
        }
      }
      expect(
        find.text(l.notif_settings_rung_morning_interested_sub),
        findsOneWidget,
      );
      await _tapToggle(tester, 'notif-rung-interested-09:00');
      expect(env.repo.patches.single, {
        'reminder_rungs': {
          'interested': {'09:00': false},
        },
      });
      expect(_toggle(tester, 'notif-rung-interested-09:00').checked, isFalse);
      expect(_toggle(tester, 'notif-rung-going-09:00').checked, isTrue);
    });

    testWidgets('[$lang] muted list empty: "Nothing muted"', (tester) async {
      await _pump(tester, locale, _Env(NotificationSettings.defaults('u1')));
      expect(find.byKey(const ValueKey('notif-muted-empty')), findsOneWidget);
      expect(find.text(l.notif_settings_muted_empty_title), findsOneWidget);
    });

    testWidgets('[$lang] muted list: Unmute, then Undo', (tester) async {
      final env = _Env(
        const NotificationSettings(
          userId: 'u1',
          mutedKinds: ['social.post_liked'],
        ),
      )..chats = [_chat('c1', 'Padel crew')];
      await _pump(tester, locale, env);
      expect(find.byKey(const ValueKey('notif-muted-empty')), findsNothing);
      expect(find.text(l.notif_settings_muted_kinds), findsOneWidget);
      expect(find.text(l.notif_settings_muted_conversations), findsOneWidget);
      expect(find.text('Padel crew'), findsOneWidget);

      final Finder unmuteKind = find.descendant(
        of: find.byKey(const ValueKey('notif-muted-kind-social.post_liked')),
        matching: find.text(l.notif_settings_unmute),
      );
      await tester.ensureVisible(unmuteKind);
      await tester.tap(unmuteKind);
      await _settle(tester);
      expect(env.repo.patches.single, {'muted_kinds': <String>[]});
      expect(find.byKey(const ValueKey('notif-muted-undo')), findsOneWidget);
      await tester.tap(find.text(l.notif_settings_undo));
      await _settle(tester);
      expect(env.repo.patches.last, {
        'muted_kinds': ['social.post_liked'],
      });

      final Finder unmuteChat = find.descendant(
        of: find.byKey(const ValueKey('notif-muted-chat-c1')),
        matching: find.text(l.notif_settings_unmute),
      );
      await tester.ensureVisible(unmuteChat);
      await tester.tap(unmuteChat);
      await _settle(tester);
      expect(env.chatMutes, [('c1', false)]);
      expect(find.text(l.notif_settings_unmuted('Padel crew')), findsOneWidget);
      await tester.tap(find.text(l.notif_settings_undo));
      await _settle(tester);
      expect(env.chatMutes, [('c1', false), ('c1', true)]);
    });

    testWidgets('[$lang] prefs sheet: one switch per category, no Payments', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        locale,
        _Env(
          const NotificationSettings(
            userId: 'u1',
            quietStartMin: 23 * 60,
            quietEndMin: 7 * 60,
          ),
        ),
        use24h: false,
        home: Builder(
          builder: (context) =>
              DabblerPage(body: NotifPrefsSheetBody(onOpenFullSettings: () {})),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerToggle), findsNWidgets(5));
      expect(find.text(l.notif_pref_payments_title), findsNothing);
      expect(find.textContaining('11:00'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('notif-pref-games')),
          matching: find.byType(DabblerToggle),
        ),
      );
      await _settle(tester);
      expect(env.repo.patches, [
        {
          'category_prefs': {
            'games': {'in_app': false},
          },
        },
        {
          'category_prefs': {
            'games': {'push': false},
          },
        },
      ]);
    });
  }
}
