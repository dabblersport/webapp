---
name: verify-jwt-not-in-config-toml
description: supabase/config.toml has NO [functions.*] section, so verify_jwt lives only as dashboard state and any CLI redeploy silently resets it
metadata:
  type: project
---

`supabase/config.toml` in this repo has **no `[functions.*]` section at all** (verified
2026-08-31). Every edge function's `verify_jwt` therefore exists only as dashboard/platform
state, invisible to the repo and to any diff.

**Why it matters:** a routine `supabase functions deploy` re-applies the default
(`verify_jwt = true`) and silently reverts the fix, with nothing in the diff to point at. This
is the same failure shape as `CREATE OR REPLACE VIEW` resetting `security_invoker`
([[create-or-replace-view-resets-invoker]]) — a platform flag a normal redeploy resets.

**How to apply:** any ruling that changes `verify_jwt` must require the matching
`config.toml` block as part of the same change, never as a follow-up:

```toml
[functions.send-push-notification]
verify_jwt = false
```

"No code change needed" is wrong for a platform-flag fix in this repo. Recorded as `T-039`
Decision 2. Related: [[functions-gateway-rejects-static-keys]].

**Update 2026-08-31 (KAN-102):** the `[functions.send-push-notification] verify_jwt = false` entry is now authored into `supabase/config.toml` (working tree, uncommitted, undeployed) with an inline comment explaining why the dashboard toggle is insufficient. It was the file's first `[functions.*]` section.
