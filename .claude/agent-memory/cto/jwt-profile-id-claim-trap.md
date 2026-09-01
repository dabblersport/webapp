---
name: jwt-profile-id-claim-trap
description: Policies using current_setting('request.jwt.claim.profile_id') use a legacy per-claim GUC that is not populated in real PostgREST sessions; verification blocks that set it by hand manufacture a pass
metadata:
  type: project
---

Several policies in this schema resolve the caller's profile via
`NULLIF(current_setting('request.jwt.claim.profile_id', true), '')::uuid` —
`circles_owner_manage`, `post_circles_author_manage`, `circle_members_join_policy`,
`circle_members_select_policy`. This is the **legacy per-claim GUC**, not the same
thing as the JWT claim.

`public.custom_access_token_hook(event jsonb)` does inject `profile_id` into the
token's claims, but it lands inside the `request.jwt.claims` JSON that PostgREST
sets. The singular `request.jwt.claim.<name>` GUCs are a separate, older mechanism.

**Why:** measured live 2026-08-29 during KAN-56 review. As a real non-owner circle
member with only `request.jwt.claims` set (the way PostgREST sets it),
`circle_members` returned 1 visible row where 2 exist — the claim-based
`circle_members_select_policy` contributed nothing; only the `auth.uid()`-based
`circle_members_select` matched.

**How to apply:** prefer the form `circles_select` uses —
`owner_profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())` — which
is correct either way. When reviewing a verification block, treat
`set_config('request.jwt.claim.profile_id', ...)` as a red flag: it makes the test
pass while production fails. Set only `request.jwt.claims`. See
[[verification-lessons]] and [[invoker-flip-join-trap]].
