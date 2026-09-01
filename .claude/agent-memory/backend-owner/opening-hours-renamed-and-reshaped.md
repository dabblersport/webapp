---
name: opening-hours-renamed-and-reshaped
description: venue_opening_hours was renamed to opening_hours AND its keying changed from (venue_id, weekday int) to (venue_space_id, day_group text) — a rename comment alone would have been wrong
metadata:
  type: project
---

KAN-63 item 1: `find_slots(uuid,date,integer)` raised 42P01 querying `public.venue_opening_hours`. The PO's ticket comment hypothesized "likely just a renamed identifier" (`to_regclass` showed `venue_opening_hours`→null, `opening_hours`→exists) and flagged to verify columns before assuming it was only the table name.

**It wasn't just the name.** Live `opening_hours` is keyed by `(venue_space_id, day_group)` — unique index `opening_hours_space_day_unique` — not `(venue_id, weekday int)`. Every row (2668/2668) has `venue_space_id` populated. `day_group` is text: `'weekdays' | 'fri' | 'sat' | 'sun'` (UAE week, Fri–Sat weekend), not an int 0-6. `is_open`/`is_closed` columns are perfectly complementary in live data (2605/63, zero mismatches).

**Why:** schema evolves out from under SECURITY DEFINER/STABLE functions silently — nothing breaks at deploy time, only at call time (42P01), and only for callers who hit that code path. `to_regclass` alone confirms existence, not shape compatibility.

**How to apply:** whenever a function/view references a renamed table, always pull `information_schema.columns` and any unique/check constraints for the new table before writing the fix — don't assume a rename preserved keying granularity. The authoritative fix landed as `supabase/migrations/20260831130000_kan74_fix_find_slots_opening_hours.sql` (authored by `backend-owner-10` under KAN-74, independently — I authored the same fix in parallel under KAN-63 and deleted mine as a duplicate once found). Two backend-owner instances converging on an identical root cause independently is a decent signal the diagnosis was solid; also a reminder to check with peer agents on adjacent tickets *before* writing, not just before posting.
