// Meetups — the detail route (the listing is a shell branch in
// home_shell_route.dart). Both are registered only while
// FeatureFlags.enableMeetups is true.

import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_edit_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_manage_screen.dart';
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

// /meetups/:meetupId/manage — host-only roster and actions. The Details entry
// shows only when the card says is_host; every action is checked server-side.
RouteBase get meetupManageRoute => GoRoute(
  path: '/meetups/:meetupId/manage',
  name: RouteNames.meetupManage,
  parentNavigatorKey: rootNavigatorKey,
  redirect: (context, state) =>
      FeatureFlags.enableMeetups ? null : RoutePaths.home,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: MeetupManageScreen(meetupId: state.pathParameters['meetupId']!),
    type: SharedAxisType.horizontal,
  ),
);

// /meetups/:meetupId/edit — the create drawer, prefilled.
RouteBase get meetupEditRoute => GoRoute(
  path: '/meetups/:meetupId/edit',
  name: RouteNames.meetupEdit,
  parentNavigatorKey: rootNavigatorKey,
  redirect: (context, state) =>
      FeatureFlags.enableMeetups ? null : RoutePaths.home,
  pageBuilder: (context, state) => AdaptiveModalPage(
    key: state.pageKey,
    child: MeetupEditScreen(meetupId: state.pathParameters['meetupId']!),
  ),
);
