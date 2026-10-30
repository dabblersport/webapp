# KAN-685 evidence (raw execute_sql output, project wtncuzcskpigqpmnxwws, 2026-10-30)

Profile 5eeb4305-9277-458e-a56f-a5ed77e3f208, user a3ba3271-3556-4b4e-b15d-bc0851f8a64b. Migration applied 2026-10-30 08:53:21Z.

## A. BEFORE the apply (run before the migration)

### A1. Pre-write probe on the profile (read-only)
```
[{"id":"5eeb4305-9277-458e-a56f-a5ed77e3f208","user_id":"a3ba3271-3556-4b4e-b15d-bc0851f8a64b","persona_type":"player","onboarding_intention":null,"onboard":true,"updated_at":"2026-10-22 20:06:43.755255+00","primary_sport":"4fd36109-12c2-4b17-a8a2-281be2b8649c","interests":["4fd36109-12c2-4b17-a8a2-281be2b8649c","2502490a-0339-436c-8b5e-5ac1514606c9"],"c_primary":true,"c_interest":true,"sp_rows":1,"sp_primary_rows":1,"sp_not_in_interests":0}]
```

### A2. Snapshot taken before the apply, read back now (thebes_backup.public__profiles__20261030085232__kan685)
```
[{"id":"5eeb4305-9277-458e-a56f-a5ed77e3f208","user_id":"a3ba3271-3556-4b4e-b15d-bc0851f8a64b","persona_type":"player","onboarding_intention":null,"onboard":true,"primary_sport":"4fd36109-12c2-4b17-a8a2-281be2b8649c","preferred_sport":"4fd36109-12c2-4b17-a8a2-281be2b8649c","interests":["4fd36109-12c2-4b17-a8a2-281be2b8649c","2502490a-0339-436c-8b5e-5ac1514606c9"],"updated_at":"2026-10-22 20:06:43.755255+00"}]
```

### A3. Triggers on public.profiles before the apply (pg_trigger; 20 rows, all enabled "O" except trg_user_created "D")
Those that fire on an UPDATE of onboard / persona_type / onboarding_intention:
- trg_profiles_language_updated_at BEFORE UPDATE -> sets NEW.language_updated_at only
- trg_profiles_search_tsv BEFORE INSERT OR UPDATE -> sets NEW.search_tsv only
- trg_profiles_updated BEFORE UPDATE -> touch_updated_at: NEW.updated_at = now()
- update_profiles_last_seen BEFORE UPDATE -> NEW.last_seen = NOW()
- trg_contributor_sports_profiles AFTER INSERT OR UPDATE, DEFERRABLE INITIALLY DEFERRED -> trgfn_contributor_sports_check: reads only, raises contributor_sports_incomplete
- trg_unified_persona_guard_upd BEFORE UPDATE OF persona_type, onboarding_intention, user_id -> trgfn_unified_persona_guard: raises persona_conversion_blocked when OLD.onboard IS TRUE, caller anon/authenticated, or the user has another profile
The others fire on INSERT or on other columns (display_name, username, age/gender, skill_level, verified, profile_type).
Function bodies were read in full (pg_get_functiondef); none writes to another row or table. No side effect, so the stop condition did not apply.
Extension triggers: trg_player/organiser/host_profile_persona_guard BEFORE INSERT OR UPDATE (v2 functions; organiser accepts persona_type organiser or contributor).

### A4. Extension and sport rows before the apply
sport_profiles: 1 row (sport football, sport_id 4fd36109-12c2-4b17-a8a2-281be2b8649c), from A1 sp_rows=1.
player: 1 row, id 3aa7aec6-5cd8-4a63-bd5a-a931c1a1cad5 (its updated_at is 2026-06-24, so the migration never touched it, see B2).
organiser: 0 rows. host: 0 rows (the persona probe before the apply showed none; B2 shows the one organiser row created at 08:53:21Z).

### A5. Auth user row
NOT READ. The SQL hook refuses any query that names auth.users (reason auth-secrets, a never-list item). The profile-to-user link is the profiles.user_id value in A1/A2.

## B. AFTER the apply, re-run read-only for this report

### B1. Probe: persona counts (probes.sql query 3)
```
[{"persona_type":"contributor","onboarding_intention":"connect_play","onboard":true,"count":2},{"persona_type":"contributor","onboarding_intention":"play_organise","onboard":true,"count":2},{"persona_type":"host","onboarding_intention":null,"onboard":true,"count":5},{"persona_type":"organiser","onboarding_intention":null,"onboard":true,"count":19},{"persona_type":"player","onboarding_intention":null,"onboard":false,"count":2},{"persona_type":"player","onboarding_intention":null,"onboard":true,"count":142},{"persona_type":"socialiser","onboarding_intention":null,"onboard":true,"count":10}]
```
contributor 2+2=4, player 142+2=144, host 5, organiser 19, socialiser 10.

### B2. Probe: the profile and every extension / sport row
```
[{"tbl":"sport_profiles","row":{"sport":"football","sport_id":"4fd36109-12c2-4b17-a8a2-281be2b8649c","profile_id":"5eeb4305-9277-458e-a56f-a5ed77e3f208","created_at":"2026-06-24T19:02:09.120758+00:00", ...unchanged stats...}},
 {"tbl":"player","row":{"id":"3aa7aec6-5cd8-4a63-bd5a-a931c1a1cad5","profile_id":"5eeb4305-9277-458e-a56f-a5ed77e3f208","created_at":"2026-06-24T19:02:08.742823+00:00","updated_at":"2026-06-24T19:02:08.742823+00:00","player_level":1, ...}},
 {"tbl":"organiser","row":{"id":"f8096904-5d36-43ca-bd1e-2c8f624e2326","sport":"football","is_active":true,"created_at":"2026-10-30T08:53:21.118126+00:00","profile_id":"5eeb4305-9277-458e-a56f-a5ed77e3f208","updated_at":"2026-10-30T08:53:21.118126+00:00","is_verified":false,"commission_type":"percent","organiser_level":1,"commission_value":0}},
 {"tbl":"profiles_now","row":{"id":"5eeb4305-9277-458e-a56f-a5ed77e3f208","onboard":true,"user_id":"a3ba3271-3556-4b4e-b15d-bc0851f8a64b","interests":["4fd36109-12c2-4b17-a8a2-281be2b8649c","2502490a-0339-436c-8b5e-5ac1514606c9"],"updated_at":"2026-10-30T08:53:21.118126+00:00","persona_type":"contributor","primary_sport":"4fd36109-12c2-4b17-a8a2-281be2b8649c","onboarding_intention":"play_organise"}}]
```
No host row. The stats columns of the sport_profiles row are elided here only for length; they were returned and are not touched by the migration.

### B3. Probe: other profiles updated since the apply (id <> target, updated_at >= 2026-10-30 08:53:00Z)
```
[{"other_profiles_updated_since_apply":0}]
```
