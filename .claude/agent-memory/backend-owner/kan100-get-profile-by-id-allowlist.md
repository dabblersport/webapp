---
name: kan100-get-profile-by-id-allowlist
description: get_profile_by_id now uses a 21-col allowlist + owner-only bypass for inactive profiles (P-028); geo_lat/geo_lng in Dart datasource are wrong column names
metadata:
  type: project
---

KAN-100 (P-028, 2026-09-01): `get_profile_by_id` migration authored at
`supabase/migrations/20260901110000_kan100_get_profile_by_id_allowlist_and_visibility.sql`
(not yet applied — cto applies under G-002). Replaces `row_to_json(p.*)` with
a named 21-column allowlist and narrows the `is_active = false` SECURITY
DEFINER bypass to `p.user_id = auth.uid()` only — a stranger now gets null
for a benched persona, same as a nonexistent id. Excludes lat/lng, last_seen,
news, reputation/legacy scoring cols, and internal state cols from the RPC
permanently — profile location on this RPC is city-only, never precise coords.

**Separately confirmed while verifying this ticket:** the live `profiles`
table has `latitude, longitude` columns. `lib/features/profile/data/datasources/supabase_profile_datasource.dart:12-13`
(`_baseProfileColumns`) requests `geo_lat, geo_lng` instead — those columns
don't exist. Also missing from that same Dart list: `persona_type`,
`primary_sport`, despite `UserProfile` consuming both. Handed to
flutter-feature-agent; not fixed by backend-owner since it's a Dart file.

**Why:** third instance of a Dart-side column list drifting from the live
schema without anyone noticing until a ticket forced verification — see also
[[opening-hours-renamed-and-reshaped]].
**How to apply:** don't trust `_baseProfileColumns` or any similar hardcoded
Dart column list as ground truth for what a table has; verify against
`information_schema.columns` before reusing it in a migration or RLS check.
