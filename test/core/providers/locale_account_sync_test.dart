// KAN-1058: the language saved on the account (profiles.language) drives the
// locale for the whole app from start-up, before any screen loads the profile.
// Before the fix only the Profile screen loaded the profile, so Feeds (the
// first tab) stayed English for an Arabic account.

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/providers/locale_account_sync.dart';
import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account extends StateNotifier<String?> implements CacheAccountNotifier {
  _Account(super.state);
}

/// Stands in for the app root: it watches the sync and the locale exactly as
/// `main.dart` does, and shows a Feeds-tab probe that reads l10n.
class _Root extends ConsumerWidget {
  const _Root();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeAccountSyncProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Text(
          AppLocalizations.of(context).manage_sports_title,
          key: const Key('feeds-probe'),
        ),
      ),
    );
  }
}

Widget _app(String? userId, String? saved) => ProviderScope(
  overrides: [
    cacheAccountIdProvider.overrideWith((ref) => _Account(userId)),
    savedLanguageLoaderProvider.overrideWithValue(
      (String id) async =>
          Ok<SavedLanguage?, Failure>((profileId: 'p-$id', language: saved)),
    ),
  ],
  child: const _Root(),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('fresh session: saved Arabic drives the first screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app('u1', 'ar'));
    await _settle(tester);
    final probe = find.byKey(const Key('feeds-probe'));
    expect(tester.widget<Text>(probe).data, 'إدارة الرياضات');
    expect(Directionality.of(tester.element(probe)), TextDirection.rtl);
  });

  testWidgets('saved Arabic overrides a stale English in local storage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'mock_language': 'en'});
    await tester.pumpWidget(_app('u1', 'ar'));
    await _settle(tester);
    final probe = find.byKey(const Key('feeds-probe'));
    expect(Directionality.of(tester.element(probe)), TextDirection.rtl);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mock_language'), 'ar');
  });

  testWidgets('signed out: local storage decides', (tester) async {
    SharedPreferences.setMockInitialValues({'mock_language': 'en'});
    await tester.pumpWidget(_app(null, 'ar'));
    await _settle(tester);
    final probe = find.byKey(const Key('feeds-probe'));
    expect(tester.widget<Text>(probe).data, 'Manage Sports');
    expect(Directionality.of(tester.element(probe)), TextDirection.ltr);
  });
}
