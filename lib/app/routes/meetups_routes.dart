// Meetups — the detail route (the listing is a shell branch in
// home_shell_route.dart). Both are registered only while
// FeatureFlags.enableMeetups is true.

import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:go_router/go_router.dart';

// /meetups/:meetupId — meetup detail (root-level, no shell/bottom-nav)
RouteBase get meetupDetailRoute => GoRoute(
  path: '/meetups/:meetupId',
  name: RouteNames.meetupDetail,
  parentNavigatorKey: rootNavigatorKey,
  redirect: (context, state) =>
      FeatureFlags.enableMeetups ? null : RoutePaths.home,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: MeetupDetailScreen(meetupId: state.pathParameters['meetupId']!),
    type: SharedAxisType.horizontal,
  ),
);

// /create-meetup — the Create meet-up drawer (organiser-only entry; the server
// enforces organiser_required).
RouteBase get createMeetupRoute => GoRoute(
  path: RoutePaths.createMeetup,
  name: RouteNames.createMeetup,
  parentNavigatorKey: rootNavigatorKey,
  redirect: (context, state) =>
      FeatureFlags.enableMeetups ? null : RoutePaths.home,
  pageBuilder: (context, state) => AdaptiveModalPage(
    key: state.pageKey,
    child: const MeetupComposerScreen(),
  ),
);
