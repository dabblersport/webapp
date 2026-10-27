# KAN-649 rollback runbook (Personas S6)

Principle: roll back exposure first, data never. Rollback never shrinks a CHECK under live rows, never deletes users or identities, and never converts anyone to player. Each script below is an APPLY for Operations, run under the existing DB controls. The scripts live in `supabase/tests/kan64x_*/rollback.sql` on `alpha-646-ramesseum`.

## Order

1. **Stop exposure (app/API).** Pull or flag off the S4/S5 app builds (KAN-647, KAN-648, KAN-650) and stop calling `rpc_onboard_unified_profile`. Nothing in the database changes at this step. Confirm no new contributor/partner rows appear for a few minutes (aggregate counts only).
2. **KAN-646** — `supabase/tests/kan646_personas_s3/rollback.sql`.
   - Restores `choose_actor`, `actor_is_player`, `actor_is_organiser`, `can_create_meetup`, `rpc_create_game_legacy_v2` and `rpc_create_sport_profile` from their live bodies by swapping the KAN-646 fragment back to the original. No DROP.
   - Raises `kan646_rollback_drift` if a live body does not contain the KAN-646 fragment exactly once, and `kan646_rollback_acl_changed` if an ACL moved. On either error stop and report; do not edit the script.
   - Leaves `actor_is_host(uuid)` inert: EXECUTE revoked from `authenticated` and `service_role` instead of dropping it.
3. **KAN-645** — `supabase/tests/kan645_personas_s2/rollback.sql`. Drops only `rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)`. Profiles, extension rows and stats it created stay. Prints aggregate contributor/partner counts first.
4. **KAN-644** — `supabase/tests/kan644_personas_s1/rollback.sql`. Only possible while no contributor or partner row and no `onboarding_intention` value exists. With any present it raises `KAN-644 rollback refused: contributor=%, partner=%, onboarding_intention set=%` and changes nothing. That refusal is the expected outcome once real accounts have onboarded.

## When step 4 refuses

Leave KAN-644 in place. It is additive and harmless with exposure off: the wider persona CHECK, the nullable `onboarding_intention` column and the guards only constrain unified rows. Do not narrow the CHECK, drop the column, delete the rows, delete identities or auto-convert anyone to player. Report the aggregate counts on KAN-649 and decide forward (fix or keep), with the CTO.

## After any rollback step

Re-run `catalog_capture.sql` and compare against the baseline in `MANIFEST.md` section 4. Legacy rows must be unchanged (count and md5, as probe P6). Post the result on KAN-649.

## What is not rolled back

App binaries already installed on devices, and users who onboarded as contributor/partner. After step 2 those users lose the KAN-646 compatibility paths, so announce before step 2 if any exist.
