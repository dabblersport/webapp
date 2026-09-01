---
name: field-repurposed-under-old-name
description: A migration correctly renames a leaked DB column, but the Dart model field consuming it keeps its old name and old semantic meaning downstream — repointing the value silently breaks every consumer that still trusts the name
metadata:
  type: feedback
---

When a ticket removes a leaked column (e.g. `creator_user_id`, an `auth.users` UUID) and
the replacement value is a different ID type (e.g. `creator_profile_id`, a `profiles.id`),
check every place the OLD field name is still used downstream — not just the JSON-parsing
site the ticket names.

**Found in KAN-87** (2026-08-31): `game_view_controller.dart` kept a field literally named
`creatorUserId` but populated it from `creator_profile_id`. The ticket's own "3 call sites"
inventory only listed the parsing site itself as low-risk ("null, nullable already" if the
column vanished) — it did not anticipate the executor **filling** the field with a
wrong-but-non-null value instead of leaving it null. Two live consumers broke silently:
`user_profile_screen.dart`'s self-redirect check (`currentUser.id != widget.userId`) and
`loadSportsProfiles(widget.userId)`'s fallback `.eq('user_id', userId)` query — both compare/
query against what is now a profile id, not an auth uid. No compile error, no exception,
just silently wrong or empty results.

**Why:** A field name is a promise about ID *type*, not just "some string." Renaming what a
migration exposes doesn't retire that promise unless every consumer is checked, and a ticket's
own call-site inventory can be incomplete — trace the field itself (`grep` its Dart field name,
not just the JSON key) through every screen that reads it, including navigation/query call
sites the security-fix author never anticipated.

**How to apply:** Whenever a ticket swaps which DB column feeds an existing Dart field, grep
for the *Dart field name* (not just the DB column name) across `lib/` and check every
downstream consumer's assumption about what type of ID it holds — especially navigation
(`context.push`) and query (`.eq(...)`) call sites, which fail silently (wrong screen, empty
result) rather than at compile time. See [[decisions-amend-silently]] for the sibling lesson
about re-reading amendments rather than trusting a ticket's own checklist.
