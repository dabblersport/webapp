// KAN-998 (G-04): /check-in/:eventId — the player check-in screen
// (root-level, no shell). Registered only while FeatureFlags.playerCheckIn.

import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:go_router/go_router.dart';

RouteBase get checkInRoute => GoRoute(
  path: '/check-in/:eventId',
  name: RouteNames.checkIn,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: CheckInScreen(
      eventId: state.pathParameters['eventId']!,
      title: state.uri.queryParameters['title'],
      venue: state.uri.queryParameters['venue'],
    ),
    type: SharedAxisType.horizontal,
  ),
);
