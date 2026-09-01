---
name: create-or-replace-view-resets-invoker
description: CREATE OR REPLACE VIEW silently resets security_invoker to off; grants survive but the reloption does not, silently reopening any leak a flip closed
metadata:
  type: project
---

**`CREATE OR REPLACE VIEW` silently resets `security_invoker` to off.** Grants
survive the replace. The reloption does not. No error, no warning.

Verified live 2026-08-29, read-only in a rolled-back transaction against the
already-flipped `v_circle_feed`: `reloptions` came back empty immediately after the
replace.

```sql
BEGIN;
CREATE OR REPLACE VIEW public.v_circle_feed AS SELECT ...;  -- no ALTER
SELECT coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
                 WHERE option_name='security_invoker'), 'RESET_TO_OFF')
FROM pg_class WHERE relname='v_circle_feed';   -- measured: RESET_TO_OFF
ROLLBACK;
```

**Why:** caught by backend-owner in kan56b before shipping. Without the re-`ALTER`, a
fix to a *display* bug would have reopened the KAN-56 anon leak — and every
row-count-based verification would still have passed, because a definer view returns
*more* rows, not fewer.

**How to apply:** any `CREATE OR REPLACE VIEW` on a flipped view must re-`ALTER VIEW
... SET (security_invoker = on)` in the same transaction, and the migration must
assert the flag itself, not just row counts. Written into `docs/CONVENTIONS.md` §6c —
prefer citing that over this note. See [[invoker-flip-join-trap]], [[g002-bypass-2026-08-29]].

Related, same migration: a new `SECURITY DEFINER` helper in `public` is exposed by
PostgREST as an RPC with EXECUTE to `public`. `circle_member_count(uuid)` is callable
by anon directly, bypassing the invoker view that was supposed to gate it. When
approving a definer helper, always ask who can call it *outside* the view.
