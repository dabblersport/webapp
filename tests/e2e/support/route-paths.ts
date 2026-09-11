/**
 * Mirrors the subset of `lib/utils/constants/route_constants.dart`'s
 * `RoutePaths` this harness needs. KAN-166 is testability tooling only and
 * may not import or modify Dart source (that boundary is KAN-165's), so
 * these are duplicated string literals, not a shared source of truth.
 *
 * If a route changes in route_constants.dart, these must be updated by
 * hand — there is no build-time link between the two.
 */
export const RoutePaths = {
  landing: '/landing',
  authWelcome: '/auth-welcome',
} as const;
