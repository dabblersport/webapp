---
name: seed-accounts-known-password
description: KAN-78 REMEDIATED 2026-08-29 (55 passwords nulled by cto under G-009); kept for the mechanism-vs-population lesson that found it, and the mis-scoped verification query it shipped with
metadata:
  type: project
---

**REMEDIATED 2026-08-29.** `cto` applied `kan78_null_seed_account_passwords` to production
under G-009 (which narrows G-002 condition 3 to permit cto-applied, count-guarded security
remediation). Verified post-apply: 0 seed accounts carry a password, 55 seed accounts still
exist and none soft-deleted, 107 non-seed accounts with a password unchanged, 242 accounts
total. The finding below is history; the lessons are not.

55 production `auth.users` rows created 2026-04-29..2026-05-04 by `create_seed_user`
carried a bcrypt hash of a single known literal. **KAN-78.** 52 of the 55 emails are
`@gmail.com` built from persona display names that are publicly browsable in-app, so the
email is guessable; none has ever signed in (`last_sign_in_at IS NULL` for all 55), so
nulling the passwords costs nothing.

The verifying command — cryptographic match, not source reading:

```sql
SELECT count(*) FROM auth.users u
WHERE u.raw_user_meta_data->>'is_seed' = 'true'
  AND u.encrypted_password = crypt('<the literal>', u.encrypted_password);
-- 55  (2026-08-29)
```

**The timeline is the proof, and it is in the migration ledger:**

```
20260429103419  create_seed_user_rpc          <- seed rows written 04-29..05-04
20260624182143  enforce_passwordless_signup   <- trigger, eight weeks later
```

The `enforce_passwordless_signup` note says it outright — the trigger "fires only on
INSERT, so existing users and the Settings set-password flow (an UPDATE) are
unaffected." Written as reassurance; for these rows it is the vulnerability. And the
password grant is live, not vestigial: the Apple reviewer demo account signs in with a
password set via Settings.

**Why this is the memory worth keeping.** A peer cto instance checked
`trg_strip_signup_password` (BEFORE INSERT, unconditional `encrypted_password := null`),
found it enabled, and concluded "no known-credential takeover". The trigger is real and
the reading of it was correct — but it was installed *after* these rows were written, and
a BEFORE INSERT trigger never touches rows already on disk. **Two separate instances made
the same inference**, and team-lead relayed it as settled fact; it took querying the rows
to break it. Corrected in [[seed-helper-anon-callable]], on KAN-80 and on KAN-78.

**How to apply:** when a guard's protection depends on *when* it was installed — a
trigger, a constraint, a default, a policy — never reason from the guard's existence to
the data's safety. Count the rows that predate it. Mechanism-verified is not
observation-verified; see [[severity-propagation-protocol]] and
[[verification-lessons]]. The same instinct applies to `NOT VALID` constraints and to
any policy added to a table that already had rows.

**Second-order lesson from the same day, my own miss.** I flagged the generated
baseline dump as carrying the literal and stopped — judging an untracked dump low risk.
cto-8 then found the same string in an untracked *migration*, which is far worse: a dump
is regenerated after the drop, a migration is meant to be committed, and a credential in
git history is permanent. I had checked one instance and generalised to the population —
the exact error I had spent the morning arguing against. **When a secret is found in one
file, enumerate every file, tracked and untracked, before declaring the scope.** Note
`git status` can show a whole directory as a single `??` entry, which hides the files
inside it from a careless read.

**Third lesson, from applying it: a verification query must carry the predicate its
expected number was measured under.** KAN-78's own verification block, check #3, reads
*"non-seed accounts are untouched: still 162"* — but the query given is unfiltered,
`SELECT count(*) FROM auth.users WHERE encrypted_password IS NOT NULL`. 162 was the
*total* pre-apply, seeds included. The real non-seed figure is 107, and the total
correctly drops 162 → 107 on apply. Run as written, a correct apply reads as a failure
and would invite a rollback. Whoever wrote the number knew the predicate; the query lost
it. Same family as the [[rpc-404-false-pass-trap]] — a check whose shape lets a wrong
answer look right.

Related: [[definer-rpc-exposure]] (public definer functions are anon PostgREST
endpoints), [[passwordless-auth]] (why the trigger exists at all),
[[seed-helper-anon-callable]] (KAN-79, the RPC that planted these).
