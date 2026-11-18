// KAN-999 (G-05, G-06): /attendance/:eventId — the organiser's attendance
// list; /no-show/:eventId — the player's no-show and review state. Both
// root-level, no shell; registered only while FeatureFlags.organiserAttendance.

import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart';
import 'package:dabbler/features/attendance/presentation/no_show_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:go_router/go_router.dart';

RouteBase get attendanceRoute => GoRoute(
  path: '/attendance/:eventId',
  name: RouteNames.attendance,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: AttendanceListScreen(
      eventId: state.pathParameters['eventId']!,
      title: state.uri.queryParameters['title'],
    ),
    type: SharedAxisType.horizontal,
  ),
);

RouteBase get noShowRoute => GoRoute(
  path: '/no-show/:eventId',
  name: RouteNames.noShow,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: NoShowScreen(
      eventId: state.pathParameters['eventId']!,
      title: state.uri.queryParameters['title'],
    ),
    type: SharedAxisType.horizontal,
  ),
);
