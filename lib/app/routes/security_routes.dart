// KAN-1003 (W2-F6): /security/review/:kind — the review of one security
// notice (?id= the ledger row of a new sign-in, ?at= when a password or
// email change happened); /security/sign-ins — the sign-in list. Root-level,
// no shell; registered only while FeatureFlags.securityScreens.

import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/core/utils/instant.dart';
import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:dabbler/features/security/presentation/security_review_screen.dart';
import 'package:dabbler/features/security/presentation/sign_ins_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:go_router/go_router.dart';

RouteBase get securityReviewRoute => GoRoute(
  path: '/security/review/:kind',
  name: RouteNames.securityReview,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: SecurityReviewScreen(
      kind:
          SecurityNoticeKind.parse(state.pathParameters['kind']) ??
          SecurityNoticeKind.newSignIn,
      signInId: state.uri.queryParameters['id'],
      changedAt: parseInstantLocal(state.uri.queryParameters['at']),
    ),
    type: SharedAxisType.horizontal,
  ),
);

RouteBase get securitySignInsRoute => GoRoute(
  path: RoutePaths.securitySignIns,
  name: RouteNames.securitySignIns,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: const SignInsScreen(),
    type: SharedAxisType.horizontal,
  ),
);
