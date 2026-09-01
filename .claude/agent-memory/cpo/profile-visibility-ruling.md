---
name: profile-visibility-ruling
description: P-028 — get_profile_by_id returns 21 named columns (never lat/lng/last_seen) and the inactive-profile definer bypass narrows to the profile's owner
metadata:
  type: project
---

Ruled 2026-09-01 on KAN-100 (KAN-82 Part 2). Governing passage for profile-visibility questions
is `04 federation & governance white paper` Art. 11 **Right 2 — Privacy**: *"Privacy defaults are
protective; expanded visibility requires affirmative player action."* Same clause decided P-019 —
reach for it first on any "who may see what" question.

- **Cross-user profile columns = 21**, the same set on every code path. Excluded: `latitude`,
  `longitude`, `last_location_updated_at` (profile location granularity is **city**, never
  coordinates), `last_seen`, `news`, `hashtag_reputation_score`, `skill_level`, `is_player`,
  `onboard`, `profile_completion`, `is_original`, `search_tsv`.
- **`user_id` retained** despite being a raw `auth.users` UUID: live caller needs it, and
  `profiles_select_public` already leaks it to `anon` in bulk (T-041 item 3, separate ticket).
- **Inactive personas:** RLS already lets you read your *own* benched persona. The definer bypass
  therefore only ever bought stranger-access, which Art. 11 Right 2 forbids. Narrowed to owner-only.

**Why it matters beyond this RPC:** the reasoning generalises. Ask what the *bypass actually buys*
that RLS does not already grant — often the answer is "only the case that should be denied."

**How to apply:** reuse the 21-column list as the definition of a public profile on any future
profile-shaped endpoint. Note this ruling reverses behaviour the PO observed and accepted on
2026-08-30 (opening inactive account `roposox`); if he overrules, P-019(b)'s "hold two, display
one" corpus ambiguity must be settled first. See [[is-active-is-persona-selector]].
