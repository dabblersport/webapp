---
name: is-active-is-persona-selector
description: profiles.is_active is the multi-persona selector written by the user, NOT a ban/suspend flag — moderation uses is_deleted / is_hidden_admin / is_suspended
metadata:
  type: project
---

`profiles.is_active` selects **which of a user's personas is currently live**. It is written by the
user's own persona-switch flow, never by moderation. Every user holding two personas has exactly one
`is_active = false` profile at all times, by design.

- `lib/features/profile/domain/services/persona_service.dart` — `switchActiveProfile()` sets ALL the
  user's profiles false, then the target true. `deactivateProfile()` does the same for conversion.
- `lib/features/profile/domain/models/persona_rules.dart:104` — "up to 2 profiles… deactivate an
  existing profile."
- Moderation flags are separate and independent: `is_deleted`, `is_hidden_admin` (see
  `supabase/schema/migrations/filter_blocked_users_from_get_feed.sql:18`), `is_suspended`,
  and the admin `ModAction.ban` / `shadowban` set.
- RLS on `profiles` admits `(p.user_id = auth.uid() OR p.is_active = true)` — your own inactive
  persona stays visible to you, hidden from others. A *visibility* control, not a status flag.

**Why:** `cto-6` nearly shipped a `v_comments` `security_invoker` flip whose inner join to `profiles`
would have hidden 18 legitimate comments — i.e. switching persona would retroactively erase your
comment history. Ruled 2026-08-28 on KAN-38: `LEFT JOIN` required.

**How to apply:** any join or filter on `profiles.is_active` in a *content* query is presumptively a
bug — authored content must not be retracted when its author switches persona. Only join on it when
the question genuinely is "which persona is live right now". The column name is misleading; verify
before anyone reasons from it. See [[stay-in-evidence-domain]].
