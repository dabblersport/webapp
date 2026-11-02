# KAN-646 — Personas S3 probes

These probes check server capability and actor compatibility for the Contributor and Partner personas.

## Files

| File | What it is |
|---|---|
| `../../migrations/20261026120000_kan646_personas_s3_capabilities.sql` | The migration. It has **not been applied**; Memphis (ops) applies it under G-002. |
| `probes.sql` | The probe set. It is one `BEGIN; … ROLLBACK;` with no COMMIT, no DROP, no `auth.*` write and named column lists only. |
| `rollback.sql` | Code-only inverse of the migration. It contains no DROP. `actor_is_host(uuid)` is made inert by revoking EXECUTE, not dropped. |
| `../../../docs/personas/kan646_operation_matrix.md` | The operation matrix. Probe ids map to its rows. |

## Contract

- **Capability truth table:**
  - player = the legacy predicate, OR a contributor that has a `public.player` row;
  - organiser = the legacy predicate, OR a contributor that has a `public.organiser` row;
  - host = the legacy predicate, OR a partner that has a `public.host` row.
- **`choose_actor(text)`:**
  - The legacy exact match is tried first and is unchanged.
  - The fallback returns the same `profiles.id`, and only for a profile the caller owns that is active and has the matching extension row.
  - The default remains `'player'`.
- Persona authorization never reads `profile_type`, `intention` or JWT `user_metadata`. It reads only `persona_type`, the extension row and ownership through `effective_actor_uid()` / `auth.uid()`.
- **Signatures and grants are unchanged.** R1–R6 assert the ACL literals as they were read from the live catalogue before the migration.
- **The new function `actor_is_host(uuid)`:**
  - Granted EXECUTE: `authenticated` and `service_role`.
  - Not granted: `PUBLIC` and `anon`.

## Run order (ops lane, after the migration is applied)

1. Apply the migration (needs-ops).
2. Run `probes.sql` once, as the owner role, in the ops lane.
   - It ends in `ROLLBACK`, so it leaves nothing behind.
   - It raises at the end if any check failed. The `_r` SELECT just before that raise lists every check with pass or fail.
3. If the migration has to be reverted, run `rollback.sql`.
   - It raises `kan646_rollback_drift` if a live body is not the KAN-646 body.

The probes need **only S1** (`20261026100000_kan644_personas_s1_schema_guards.sql`):

- Fixtures are built in-transaction:
  1. the profile is created with `onboard = false`;
  2. the extension rows are added;
  3. the `sport_profiles` row is added;
  4. the Following/interests sport is set;
  5. only then is `onboard = true` set.
- Fixture users come from the pooled fixture-user pattern.
- S1's deferred constraint triggers fire at ROLLBACK time, never at commit time. S3 and S4 set them IMMEDIATE to observe them, then set them back to DEFERRED.

## What has been executed

**Nothing has been run against a database.**

- **Live access was read-only catalogue reads** (`pg_get_functiondef`, `pg_proc.proacl`, `information_schema`). The ACL and fragment literals were taken from those reads.
- **The probes have not been run.** Until they are, every expectation in them is a specification, not evidence.
- **The SQL hook verdicts are recorded in the KAN-646 hand-back.** They come from running `agent.scripts.sql_hook.decide()` offline.

## Unverified / known gaps

- **AC7:** before KAN-649, re-run one probe set (G and J at minimum) against the real S2 onboarding RPC instead of the in-transaction fixtures.
- **Probes not yet observed failing.** No probe has been seen failing against the pre-migration catalogue. On the first ops run, run `probes.sql` before applying the migration as well: the T, A, G, M and S rows for contributors and partners should fail there, and the L and R rows should pass.
- **Hook case-sensitivity:** the dynamic-SQL rule in `sql_hook` matches lowercase `execute` only. The migration and rollback use uppercase `EXECUTE`. The brief's instruction "lowercase `execute`" reads inverted relative to the hook's behaviour; this is reported, not resolved here.
- **Blockers:** B1 (squads) and B3 (partner social block) are named in the matrix and are deliberately not fixed.
