---
name: functions-gateway-rejects-static-keys
description: The Supabase Edge Functions gateway on this project rejects EVERY static API key (legacy anon AND sb_publishable_) with 401 UNAUTHORIZED_LEGACY_JWT; only current-signing-key session JWTs pass
metadata:
  type: project
---

The `/functions/v1/*` gateway on `wtncuzcskpigqpmnxwws` rejects **every static API key** when
`verify_jwt: true` — not just the legacy anon key.

**Why:** verified live 2026-08-31 (`T-039`, KAN-81 comment 10291). Measured with curl:

```
Bearer <legacy anon eyJ...>                → 401 UNAUTHORIZED_LEGACY_JWT
Bearer sb_publishable_Yu3mrg94sf_...       → 401 UNAUTHORIZED_LEGACY_JWT
apikey: sb_publishable_ + Bearer (either)  → 401 UNAUTHORIZED_LEGACY_JWT
Bearer notajwt                             → 401 UNAUTHORIZED_INVALID_JWT_FORMAT
control: detect-country (verify_jwt=false) → 200
```

The **different code on garbage** is the proof: the gateway parses our real keys fine and
refuses them by policy. Only a JWT signed by the project's *current* signing key passes —
i.e. a real user session. This broke 100% of push notifications, because
`trg_push_on_notification_insert` sends `Bearer <vault supabase_anon_key>` purely to satisfy
this gate.

**Scope — the rejection is gateway-specific, and this is the part that matters.** The legacy
anon key is NOT dead elsewhere:

* GoTrue `/auth/v1/user` with it → `403 bad_jwt "missing sub claim"` (a verdict on the bearer,
  not a rejection of the key)
* PostgREST `/rest/v1/...` with it → `200` with rows

So an edge function's internal `auth.getUser()` via an anon-key client still works after
`verify_jwt` is turned off. Check this before assuming a key is globally dead.

**How to apply:** any server-to-server caller of an edge function (DB trigger, pg_net, cron)
CANNOT satisfy `verify_jwt: true` here — there is no key it can hold. Such functions must be
`verify_jwt: false` and carry their own auth. Do not propose "rotate to a publishable key" as
a fix; it is measured and dead. Functions driven by real browser sessions
(`broadcast-notification`) are unaffected and stay gated.

See [[verify-jwt-not-in-config-toml]], [[create-or-replace-view-resets-invoker]].
