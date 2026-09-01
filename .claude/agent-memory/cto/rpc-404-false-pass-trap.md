---
name: rpc-404-false-pass-trap
description: An anon POST /rest/v1/rpc/<fn> with an empty {} body returns 404 PGRST202 whether or not the function exists — it only proves no zero-arg overload. Always send the real parameter names.
metadata:
  type: feedback
---

When verifying that a definer RPC is gone or closed to anon, **send the real
parameter names in the POST body.** An empty `{}` body returns
`404 PGRST202 "...without parameters or with a single unnamed json/jsonb
parameter..."` — which is equally true before and after the fix. It looks like
a pass and proves nothing.

Hit live on 2026-08-29 applying KAN-79/81/82. With `{}` all three returned 404,
including `get_profile_by_id`, which had **not** been dropped and was still
fully present. Re-run with `{"p_profile_id":"<real uuid>"}` gave the real
answer: `HTTP 401 / 42501 permission denied for function get_profile_by_id`.

**Why:** PostgREST resolves the overload by the argument names in the body
before it ever checks privileges. A signature miss and an absent function are
the same 404.

**How to apply:** the 404 is only evidence of absence if its `details` string
echoes back the **real** parameter names it searched for. For an authorization
fix (not a drop), expect `42501`, not 404 — and pass an input that would have
*succeeded* before the fix (for KAN-82: a real `is_active=false` profile id),
so a denial proves the exposure closed rather than a call that missed.

Related: [[jwt-profile-id-claim-trap]], [[verification-lessons]].
