import 'package:dabbler/utils/constants/route_constants.dart';

/// The redirect of the admin Reports route (KAN-552), kept free of Supabase
/// and GoRouter types so it can be tested with fakes.
///
/// Flags off, no session, an admin check that says no or throws: all land
/// away from the screen (Home, or the landing page without a session). Only a
/// confirmed admin with both flags on gets `null` (stay).
Future<String?> messageReportsRedirect({
  required bool flagsOn,
  required bool hasSession,
  required Future<bool> Function() isAdmin,
}) async {
  if (!flagsOn) return RoutePaths.home;
  if (!hasSession) return RoutePaths.landing;
  try {
    return await isAdmin() ? null : RoutePaths.home;
  } catch (_) {
    return RoutePaths.home;
  }
}
