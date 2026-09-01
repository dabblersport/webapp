---
name: jwt-claim-predicate-narrower-than-lookup
description: A policy predicate using current_setting('request.jwt.claim.profile_id') is strictly narrower than the equivalent `IN (SELECT id FROM profiles WHERE user_id = auth.uid())` lookup, because the claim depends on custom_access_token_hook finding an is_active=true profile. A test that manually injects the claim can't catch this.
metadata:
  type: feedback
---

**Two predicates that look equivalent aren't:** `owner_profile_id = current_setting('request.jwt.claim.profile_id')::uuid`
(claim-based) vs. `owner_profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())`
(lookup-based). The claim is populated by `custom_access_token_hook`, which does
`SELECT id FROM profiles WHERE user_id = ... AND is_active = true LIMIT 1` — so a user whose
matched profile isn't currently the active one (Dabbler's multi-persona switch, see
[[invoker-flip-join-trap]] on `profiles.is_active`) gets no claim at all, and the claim only
refreshes on token reissue. The lookup form has no such gap.

**Why it matters:** on KAN-56 (2026-08-29), I wrote `post_circles_select_visible`'s owner branch
using the claim form, describing it as mirroring `circles_select`'s predicate — it didn't;
`circles_select` uses the lookup form (`owner_profile_id IN (SELECT id FROM profiles WHERE
user_id = auth.uid())`), and what I'd actually copied was `circles_owner_manage`'s form. cto
caught it in G-002 review. A private-circle owner with an inactive profile would have silently
seen zero rows through a policy that looked correct.

**The worse part, worth internalizing:** my own verification for this policy manually injected
`request.jwt.claim.profile_id` via `set_config`, so the test could not have caught the bug — it
supplied the exact claim whose absence was the failure mode. This is the same shape as a
service-role test passing while production fails: the test setup assumes away the condition that
breaks real callers.

**How to apply:** when a policy predicate needs "the caller's own profile_id" and there's a choice
between reading it from a JWT claim vs. looking it up from `auth.uid()` via `profiles`, default to
the lookup form unless there's a specific reason to trust the claim — check what the token hook
actually populates and under what conditions first. When verifying with a simulated session
(`SET LOCAL ROLE authenticated; PERFORM set_config('request.jwt.claims', ...)`), supply only `sub`
— never manually set any other claim the policy depends on to prove out — because doing so removes
exactly the layer whose absence is the realistic failure mode. If a test can only pass by injecting
a claim a real session might not carry, that's a sign the policy or the test is wrong, not a
justified test fixture. Schema-wide, count which form is dominant before choosing (17 policies used
the lookup form vs. 3 using the claim form in this schema as of 2026-08-29) — the lookup form is the
established convention.

Related: [[rls-policy-count-is-not-permission]], [[invoker-flip-join-trap]] (cto's memory).
