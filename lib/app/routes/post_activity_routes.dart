// KAN-1000 (G-02, G-03): /post-activity/:eventId — the 48h post-activity
// flow; /result/:eventId — the result tally and the organiser's approval;
// /result/:eventId/final — the organiser's final score entry. Root-level, no
// shell; registered only while FeatureFlags.postActivity.

import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/features/post_activity/presentation/final_score_screen.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_screen.dart';
import 'package:dabbler/features/post_activity/presentation/result_approval_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

GoRoute _route(
  String path,
  String name,
  Widget Function(String eventId, String? title) child,
) => GoRoute(
  path: path,
  name: name,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: child(
      state.pathParameters['eventId']!,
      state.uri.queryParameters['title'],
    ),
    type: SharedAxisType.horizontal,
  ),
);

RouteBase get postActivityRoute => _route(
  '/post-activity/:eventId',
  RouteNames.postActivity,
  (id, title) => PostActivityScreen(eventId: id, title: title),
);

RouteBase get resultApprovalRoute => _route(
  '/result/:eventId',
  RouteNames.resultApproval,
  (id, title) => ResultApprovalScreen(eventId: id, title: title),
);

RouteBase get resultFinalRoute => _route(
  '/result/:eventId/final',
  RouteNames.resultFinal,
  (id, title) => FinalScoreScreen(eventId: id, title: title),
);
