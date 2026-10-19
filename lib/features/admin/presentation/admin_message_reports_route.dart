import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/admin/presentation/screens/admin_message_reports_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';

/// The admin Reports route's gate (KAN-552), the same order as the existing
/// admin routes (`platform_routes.dart`): no session -> landing; then the
/// flags; then the existing `is_admin` check. A non-admin, a failed check or
/// flags off -> Home. Injectable so tests need no Supabase instance.
Future<String?> adminMessageReportsRedirect({
  required bool hasSession,
  required bool enabled,
  required Future<bool> Function() isAdmin,
}) async {
  if (!hasSession) return RoutePaths.landing;
  if (!enabled) return RoutePaths.home;
  try {
    return await isAdmin() ? null : RoutePaths.home;
  } catch (_) {
    return RoutePaths.home;
  }
}

/// The admin Reports route with the shared transition wrapper.
GoRoute adminMessageReportsRoute({
  GlobalKey<NavigatorState>? parentNavigatorKey,
  required bool Function() hasSession,
  required bool Function() enabled,
  required Future<bool> Function() isAdmin,
}) => GoRoute(
  parentNavigatorKey: parentNavigatorKey,
  path: RoutePaths.adminMessageReports,
  redirect: (context, state) => adminMessageReportsRedirect(
    hasSession: hasSession(),
    enabled: enabled(),
    isAdmin: isAdmin,
  ),
  pageBuilder: (context, state) => SharedAxisTransitionPage(
    key: state.pageKey,
    child: const AdminMessageReportsScreen(),
    type: SharedAxisType.horizontal,
  ),
);
