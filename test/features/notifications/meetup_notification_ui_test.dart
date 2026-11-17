import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_row.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/notification_settings_screen.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/notification_settings_repository.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

class _Repo implements NotificationSettingsRepository {
  @override
  Future<Result<NotificationSettings, Failure>> load() async =>
      Ok(NotificationSettings.defaults('u1'));
  @override
  Future<Result<NotificationSettings, Failure>> update(
    Map<String, dynamic> patch,
  ) async => Ok(NotificationSettings.defaults('u1'));
  @override
  Future<Result<NotificationSettings, Failure>> setTimezone(String tz) async =>
      Ok(NotificationSettings.defaults('u1'));
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(393, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationSettingsRepositoryProvider.overrideWithValue(_Repo()),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(initHomeTestSupabase);

  // KAN-991: meetup kinds are switched by the Meetups category (in-app and
  // push), not one row per kind.
  testWidgets('settings shows the Meetups category', (tester) async {
    await _pump(tester, const NotificationSettingsScreen());
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.notif_settings_cat_meetups), findsWidgets);
    expect(find.text(l.notif_settings_kind_meetup_rsvps), findsNothing);
  });

  testWidgets('the existing row renders a meetup notification', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: NotificationRow(
          notification: AppNotification(
            id: 'n1',
            toUserId: 'u1',
            kindKey: 'meetup.request_approved',
            title: 'Request approved',
            isRead: false,
            createdAt: DateTime.now(),
          ),
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Request approved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
