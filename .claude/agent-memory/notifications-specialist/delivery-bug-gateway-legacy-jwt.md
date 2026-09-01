---
name: delivery-bug-gateway-legacy-jwt
description: Live KAN-81 reopen (2026-08-31) — push 100% failing at the Supabase gateway with UNAUTHORIZED_LEGACY_JWT, not a code bug
metadata:
  type: project
---

Confirmed via direct query of `net._http_response` (pg_net's async response table — only
retains a handful of recent rows) that every trigger-fired push right now fails with:

```
401 {"code":"UNAUTHORIZED_LEGACY_JWT","message":"Invalid JWT"}
```

This body is the Supabase platform/gateway's own rejection format — NOT something
`send-push-notification`'s code emits (its own 401 paths return `{"error":"Unauthorized"}`,
confirmed by pulling the deployed source via `get_edge_function`). The function has
`verify_jwt: true` at the platform config level, and the trigger's Authorization header
(`Bearer <vault:supabase_anon_key>`, a legacy HS256 JWT) is being rejected by the gateway
*before* the request ever reaches the function's own auth logic (x-trigger-secret /
getUser()). Byte-length+prefix of the vault secret matches the project's current
`get_publishable_keys` legacy anon key, so it is not a stale/un-rotated secret — the
gateway itself is now rejecting legacy-format JWTs for this project (Supabase-side
platform change, not a repo regression).

**Why it hit every surface identically:** push is 100% trigger-driven (client-side
`NotificationSender` helper deleted 2026-07-11, zero callers). One `net.http_post` call
path serves every kind/platform — there's no per-surface code to diverge, so the failure
is upstream of all clients, at the gateway.

**Fix (authored, not applied — cto owns deploy per G-002):** set `verify_jwt: false` on
`send-push-notification`. The function already implements its own trusted-lane
(`x-trigger-secret`) and per-user (`auth.getUser()`) auth specifically so it doesn't need
platform JWT gating — this is Supabase's documented pattern for webhook/trigger-invoked
functions. No code change needed, just the platform config flag. `broadcast-notification`
is unaffected (admin browser sessions carry freshly-signed JWTs, not the vault legacy key).

**Why:** distinguishes this from every earlier KAN-81 hypothesis (get_user_fcm_tokens drop,
missing tokens, KAN-99 crash, trigger not firing) — all ruled out with direct evidence this
pass. [[delivery-bug-trigger-401]] (the OLD prior-session finding) is now STALE/SUPERSEDED —
that 401 was a different failure mode (function-level getUser() rejecting an anon caller)
and the code has since been fixed with the x-trigger-secret dual-lane (confirmed present in
both the deployed trigger SQL and the deployed function source as of this pass). Do not
re-apply the old fix description; this is a distinct, later, platform-level break.

**How to apply:** before trusting push works again, confirm `verify_jwt` was actually
flipped to false on `send-push-notification` (check `list_edge_functions` /
`get_edge_function`) and that a fresh `net._http_response` row shows 200, not 401.
