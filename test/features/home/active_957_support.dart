/// KAN-957: opens Home on its Active tab with every source faked.
library;

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_test_harness.dart';

/// 16 Nov 2026, 15:00 local — the clock every KAN-957 test reads.
final DateTime activeNow = DateTime(2026, 11, 16, 15);

final desktopOnly = TargetPlatformVariant.only(TargetPlatform.macOS);

const List<Locale> activeLocales = <Locale>[Locale('en'), Locale('ar')];

List<String> _lastPushed = <String>[];

/// The routes the last [openActiveTab] screen pushed (the harness's
/// catch-all route records them).
List<String> get activePushed => _lastPushed;

/// Pumps Home and taps the Active tab. [cities] answers the city sheet.
Future<AppLocalizations> openActiveTab(
  WidgetTester tester, {
  required ActiveFeedState state,
  Locale locale = const Locale('en'),
  List<String> cities = const <String>['Abu Dhabi', 'Dubai'],
}) async {
  final pumped = await pumpHome(
    tester,
    feedState: const FeedData(items: <FeedItem>[], hasMore: false),
    activeState: state,
    locale: locale,
    overrides: <Override>[
      homeNowProvider.overrideWithValue(() => activeNow),
      activeCitiesProvider.overrideWith((ref) async => cities),
    ],
  );
  _lastPushed = pumped.pushed;
  final l = lookupAppLocalizations(locale);
  await tapFeedTab(tester, FeedTab.active.label(l));
  return l;
}

Future<void> tapFeedTab(WidgetTester tester, String label) async {
  final tab = find.text(label).first;
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The live filter state behind the screen.
ActiveFilter activeFilterOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomeScreen)),
).read(activeFilterProvider);

void setActiveFilter(WidgetTester tester, ActiveFilter f) =>
    ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    ).read(activeFilterProvider.notifier).state = f;
