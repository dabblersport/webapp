import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/setting_sync_hint.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';

/// KAN-608: the inline "not synced, tap to retry" line shows only while the
/// setting is queued, in English and Arabic, and a tap retries.
class _Handler extends SettingSyncHandler {
  int pushes = 0;
  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async => null;
  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async =>
      pushes++;
  @override
  Future<void> adoptServer(String accountId) async {}
}

void main() {
  late _Handler handler;
  late SettingsSyncNotifier sync;
  var offline = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    handler = _Handler();
    offline = true;
    sync = SettingsSyncNotifier(
      accountId: 'A',
      handlers: {SettingKeys.notifications: handler},
      isOffline: () => offline,
      observeLifecycle: false,
    );
    // The ProviderScope that holds it disposes it.
  });

  Future<void> pumpHint(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsSyncProvider.overrideWith((ref) => sync)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            locale: locale,
          ),
          home: const Scaffold(
            body: SettingSyncHint([SettingKeys.notifications]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hidden when nothing is queued', (tester) async {
    await pumpHint(tester, const Locale('en'));
    expect(find.textContaining('Not synced'), findsNothing);
  });

  for (final c in [
    (const Locale('en'), 'Will sync when online'),
    (const Locale('ar'), 'ستتم المزامنة عند الاتصال'),
  ]) {
    testWidgets('shown while queued (${c.$1.languageCode}), tap retries', (
      tester,
    ) async {
      await pumpHint(tester, c.$1);
      await tester.runAsync(() async {
        await sync.submit(SettingKeys.notifications, {'v': 1}); // offline
      });
      await tester.pump();
      expect(find.text(c.$2), findsOneWidget);
      expect(handler.pushes, 0);

      offline = false; // the connection is back; the user taps the line
      await tester.tap(find.text(c.$2));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(handler.pushes, 1);
      expect(find.text(c.$2), findsNothing);
    });
  }
}
