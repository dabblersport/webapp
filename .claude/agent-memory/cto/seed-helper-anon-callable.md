---
name: seed-helper-anon-callable
description: create_seed_user was anon-callable in production creating pre-confirmed accounts; the trigger neutralises the password for NEW rows only — 55 pre-trigger rows still carry it (KAN-78)
metadata:
  type: project
---

`public.create_seed_user` (4 overloads) was live in production **callable by anon**,
inserting into `auth.users` with `email_confirmed_at = now()` plus a `profiles` row,
returning both ids. Tracked as KAN-79 (KAN-80 is a duplicate, closed).

**The severity correction is the part to remember.** The body contains
`crypt('[REDACTED — see KAN-78]', gen_salt('bf'))`, and the census reported it as "loginable
accounts with a known password". It is not: `auth.users` carries an enabled BEFORE
INSERT trigger `trg_strip_signup_password` that unconditionally sets
`new.encrypted_password := null` (verified `tgenabled='O'`, 2026-08-29). The password
never lands **for rows inserted after the trigger existed**.

**CORRECTION, same day, by a later cto instance — the "no known-credential takeover"
conclusion was wrong.** The trigger was added *after* the seed rows were written and
does not retroactively touch them. Verified cryptographically against the live rows:
`SELECT count(*) FROM auth.users u WHERE u.raw_user_meta_data->>'is_seed'='true' AND
u.encrypted_password = crypt('<the literal>', u.encrypted_password);` returns **55**.
52 of those emails are `@gmail.com` derived from publicly browsable persona names, so
they are guessable. That is a live known-credential path to a full `authenticated`
session. Tracked separately as **KAN-78**; dropping the function does not fix it.

What is real: unauthenticated mass creation of pre-confirmed accounts and profiles with
attacker-chosen usernames, bypassing rate limiting, captcha, email verification and
onboarding. HIGH.

**Why:** a scary-looking literal in a function body is not the behaviour — triggers,
RLS and grants can all neutralise or amplify it. Read the whole path before assigning
severity, and correct a peer's severity in writing rather than inheriting it; a fix
aimed at the wrong threat is the usual result.

**And the sharper version of that lesson, learned by getting it wrong here:** a
mechanism check is not an observation check. Reading a trigger tells you what happens
to rows written *from now on*. It tells you nothing about rows already on disk. When a
guard's protection depends on *when* it was installed, always count the rows that
predate it — do not reason from the guard's existence to the data's safety.

**How to apply:** the ruling is **DROP**, not REVOKE — nothing calls it, the seeding
finished 2026-05-04, and a retained definer function that writes to `auth.users` is a
latent re-exposure (cf. [[create-or-replace-view-resets-invoker]]). Note the ACL trap:
the grant is inherited from `PUBLIC` (`=X/postgres`), there is no `anon=X` entry, so
`REVOKE ... FROM anon` alone is a no-op that looks like a fix. Contrast
[[definer-rpc-exposure]]'s `circle_member_count`, where a view depends on the function. See
[[passwordless-auth]] for the trigger's own rationale.
