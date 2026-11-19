/// KAN-988: pumps one or more NotificationRows with a fake action handler.
library;

import 'dart:async';

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_actions.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_row.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls; each [run] answers with [outcome] after [gate] completes.
class FakeNotifActions implements NotifActionHandler {
  FakeNotifActions({this.outcome = NotifActionOutcome.success});

  NotifActionOutcome outcome;
  Completer<void>? gate;
  final List<String> calls = <String>[];

  @override
  Future<NotifActionOutcome> run(
    NotificationActionId action,
    AppNotification n,
  ) async {
    calls.add('run:${action.name}:${n.id}');
    if (gate != null) await gate!.future;
    return outcome;
  }

  @override
  Future<bool> setRead(AppNotification n, {required bool read}) async {
    calls.add('read:$read');
    return true;
  }

  @override
  Future<bool> setKindMuted(String kindKey, {required bool muted}) async {
    calls.add('muteKind:$kindKey:$muted');
    return true;
  }

  @override
  Future<bool> setConversationMuted(
    String conversationId, {
    required bool muted,
  }) async {
    calls.add('muteConversation:$conversationId:$muted');
    return true;
  }
}

AppNotification notif(
  String kind, {
  String id = 'n1',
  String title = 'Title',
  String? body,
  Map<String, dynamic>? payload,
  Map<String, dynamic> args = const <String, dynamic>{},
  bool read = false,
  DateTime? at,
}) => AppNotification(
  id: id,
  toUserId: 'me',
  kindKey: kind,
  title: title,
  body: body,
  payload: payload,
  args: args,
  isRead: read,
  createdAt: at ?? DateTime.now().subtract(const Duration(minutes: 2)),
);

/// Pumps [rows] in [locale] with [handler]; returns the localizations and
/// the taps on rows (`open:<id>`).
Future<(AppLocalizations, List<String>)> pumpRows(
  WidgetTester tester,
  List<AppNotification> rows, {
  Locale locale = const Locale('en'),
  FakeNotifActions? handler,
  bool use24h = false,
}) async {
  final opened = <String>[];
  tester.view.physicalSize = const Size(393, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notifActionHandlerProvider.overrideWithValue(
          handler ?? FakeNotifActions(),
        ),
        // No signed-in profile: the follow-back lookup stays false.
        myProfileIdProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                for (final n in rows)
                  NotificationRow(
                    key: ValueKey<String>('row-${n.id}'),
                    notification: n,
                    onTap: () => opened.add('open:${n.id}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (lookupAppLocalizations(locale), opened);
}

Finder rowOf(String id) => find.byKey(ValueKey<String>('row-$id'));

Finder inRow(String id, Finder f) =>
    find.descendant(of: rowOf(id), matching: f);
