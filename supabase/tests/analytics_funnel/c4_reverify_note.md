# KAN-767 — KAN-703 C4 re-verify: launch funnel RPC vs raw rows after the game_created fix

Run: 2026-11-02 ~09:10 UTC, by Memphis (ops read). Read-only: every statement below is a SELECT; no
migration, DDL, insert, update, sign-in or test data. Database: Supabase project `wtncuzcskpigqpmnxwws`.

## Window

- 7 UTC days, **2026-10-26 00:00:00 UTC** to **2026-11-02 00:00:00 UTC** (days 26 Oct .. 1 Nov inclusive),
  i.e. `rpc_admin_launch_funnel('2026-10-26', '2026-11-01')`. Same bounds for every raw query.
- Deploy of the composer fix: Alpha merge `82607493f60c62257529465dfbe21040388913ae`
  ("Integrate KAN-703: alpha-deir-el-bahari"), committed 2026-11-01 03:16:11 UTC. The Cloudflare build
  time for alpha.dabbler.pro was not read (alpha does not expose a build id), so "post-deploy" below
  means after the merge timestamp.
- **First post-deploy day covered: 2026-11-01** (from 03:16:11 UTC; the window's last day). 2026-11-02 is
  excluded because the window ends the day before the run.

## RPC SELECT run (verbatim body of public.rpc_admin_launch_funnel)

The deployed function is `SECURITY DEFINER` with `IF NOT public.is_admin() THEN RAISE 'admin only'`; the
read-only SQL role has no `auth.uid()`, so the function itself cannot be invoked here. Its SELECT body
(from `supabase/migrations/20261030120000_kan700_rpc_admin_launch_funnel.sql`, unchanged on Alpha
791d6376) was run verbatim with the parameters substituted:

```sql
-- Q1 (RPC body, p_from = 2026-10-26, p_to = 2026-11-01)
SELECT (ae.created_at AT TIME ZONE 'UTC')::date AS day,
       ae.event_name,
       count(*)::bigint AS events,
       count(DISTINCT ae.user_id)::bigint AS distinct_users
  FROM public.analytics_events ae
 WHERE ae.event_name IN ('signup', 'game_created', 'game_joined', 'check_in')
   AND ae.created_at >= ('2026-10-26'::date::timestamp AT TIME ZONE 'UTC')
   AND ae.created_at <  (('2026-11-01'::date + 1)::timestamp AT TIME ZONE 'UTC')
 GROUP BY 1, 2
 ORDER BY 1, 2;
```

Result (events / distinct_users):

| day | signup | game_created | game_joined | check_in |
|---|---|---|---|---|
| 2026-10-27 | 2 / 2 | — | — | — |
| 2026-10-28 | 2 / 2 | — | — | — |
| 2026-10-31 | — | — | 1 / 1 | — |
| 2026-11-01 | — | — | 1 / 1 | — |
| **total** | **4 / 4** | **0 / 0** | **2 / 2** | **0 / 0** |

## Per-step verdict

| step | RPC count (events / users) | raw count | match | verdict | note |
|---|---|---|---|---|---|
| signup | 4 / 4 | 10 new `auth.users` (27 Oct 3, 28 Oct 2, 1 Nov 5) | N | PASS-PARTIAL | 4 of the 5 users created on 27–28 Oct have a `signup` event (one on 27 Oct 00:01 UTC has none). The 5 users of 1 Nov were all created at 01:50:23 UTC within 73 ms, before the deploy and not through the app's sign-up screens; they are excluded as non-app rows. Post-deploy organic signups in the window: 0, so the emitter was not exercised live. |
| game_created | 0 / 0 | 7 `games` rows (31 Oct 2, 1 Nov 5); 2 of them after the deploy | N | PASS-PARTIAL | No `game_created` event exists in the window. 5 pre-deploy games cannot carry the fix. The 2 post-deploy games (1 Nov 08:00:37 and 20:00:37 UTC, 12 h apart to the second, `series_id` null) have roster joins at exactly 3h59m44s, 7h59m44s, 11h59m44s and 19h59m44s after creation: a scheduled writer, not a composer session. **No organic post-deploy game_created exists yet; none was created (brief).** Untested live. |
| game_joined | 2 / 2 | 17 non-host `game_roster` rows (31 Oct 4, 1 Nov 13); 16 `active`, 1 `left` | N | PASS-PARTIAL | Both events have a matching roster row (same game_id and user, within 5 min). The 15 surplus rows belong to the scripted games above (periodic timing) or predate the deploy; the app's join path emits only on result `joined` (KAN-703). Each emitted event is backed by a row (no over-count); under-count over non-app rows cannot be ruled out from data alone. |
| check_in | 0 / 0 | 0 `check_in_logs` rows, 0 `user_check_ins.last_check_in` in window | Y | PASS-PARTIAL | RPC and raw agree at zero. No check-in happened in the window, so the emitter (analytics_service.dart:95) was not exercised live. |

RPC arithmetic: for every step the RPC count equals a direct count over `analytics_events` with the same
filters (it is the same SELECT), and no step over-counts relative to raw rows. The open question from KAN-703
C4 (does the deployed composer emit `game_created`?) stays **untested**: zero organic post-deploy game creations
exist in the window. Overall: **PASS-PARTIAL** (untested steps: game_created, signup, check_in live emission;
game_joined partially, see note).

## Every query run (all SELECT; none wrote)

- Q1 — RPC body, quoted above.
- Q2 — `SELECT 'games', (created_at AT TIME ZONE 'UTC')::date, count(*), count(DISTINCT creator_profile_id) FROM public.games WHERE created_at >= '2026-10-26 00:00+00' AND created_at < '2026-11-02 00:00+00' GROUP BY 2 ORDER BY 2;` → 31 Oct 2/1, 1 Nov 5/5.
- Q3 — `SELECT table_name, column_name FROM information_schema.columns WHERE table_schema='public' AND table_name IN ('game_participants','user_check_ins','check_in_logs','analytics_events') ORDER BY 1, ordinal_position;` → no `game_participants` table; roster is `game_roster`.
- Q4 — `SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='game_roster' ORDER BY ordinal_position;` → game_id, profile_id, user_id, role, status, joined_at, left_at, id.
- Q5 — `SELECT (g.created_at AT TIME ZONE 'UTC'), (g.created_at >= '2026-11-01 03:16:11+00') AS after_deploy_merge, EXISTS (SELECT 1 FROM public.analytics_events ae WHERE ae.event_name='game_created' AND ae.user_id = g.creator_profile_id AND ae.created_at BETWEEN g.created_at - interval '10 minutes' AND g.created_at + interval '10 minutes') FROM public.games g WHERE g.created_at >= '2026-10-26 00:00+00' AND g.created_at < '2026-11-02 00:00+00' ORDER BY g.created_at;` → 7 rows, 2 after the merge, none with an event.
- Q6 — `SELECT 'check_in_logs', check_in_date, count(*), count(DISTINCT user_id) FROM public.check_in_logs WHERE check_in_timestamp >= '2026-10-26 00:00+00' AND check_in_timestamp < '2026-11-02 00:00+00' GROUP BY 2 UNION ALL SELECT 'user_check_ins(last_check_in)', (last_check_in AT TIME ZONE 'UTC')::date, count(*), count(DISTINCT user_id) FROM public.user_check_ins WHERE last_check_in >= '2026-10-26 00:00+00' AND last_check_in < '2026-11-02 00:00+00' GROUP BY 2 ORDER BY 1, 2;` → 0 rows.
- Q7 — `SELECT (ae.created_at AT TIME ZONE 'UTC'), ae.event_name, (ae.properties ? 'game_id'), ae.properties->>'join_method' FROM public.analytics_events ae WHERE ae.event_name IN ('game_created','game_joined','check_in') AND ae.created_at >= '2026-10-26 00:00+00' AND ae.created_at < '2026-11-02 00:00+00' ORDER BY ae.created_at;` → 2 game_joined (31 Oct 23:06, 1 Nov 13:44 UTC), both with game_id, join_method `open`.
- Q8 — `SELECT (g.created_at AT TIME ZONE 'UTC'), (g.series_id IS NOT NULL), (SELECT count(*) FROM public.game_roster r WHERE r.game_id = g.id) FROM public.games g WHERE g.created_at >= '2026-11-01 03:16:11+00' AND g.created_at < '2026-11-02 00:00+00' ORDER BY g.created_at;` → 08:00:37 (series null, 4 roster), 20:00:37 (series null, 2 roster).
- Q9 — `SELECT (r.joined_at AT TIME ZONE 'UTC')::date, count(*), count(*) FILTER (WHERE r.profile_id <> g.creator_profile_id), count(*) FILTER (WHERE r.profile_id <> g.creator_profile_id AND r.status = 'joined'), count(DISTINCT r.profile_id) FILTER (WHERE r.profile_id <> g.creator_profile_id) FROM public.game_roster r JOIN public.games g ON g.id = r.game_id WHERE r.joined_at >= '2026-10-26 00:00+00' AND r.joined_at < '2026-11-02 00:00+00' GROUP BY 1 ORDER BY 1;` → 31 Oct 6 rows / 4 non-host; 1 Nov 18 / 13.
- Q10 — `SELECT jobname, schedule, left(command, 120) FROM cron.job ORDER BY jobname;` → one job (notification flush); no DB cron creates games, so the periodic writer is outside the database.
- Q11 — `SELECT (g.created_at AT TIME ZONE 'UTC'), r.status, r.role, (r.profile_id = g.creator_profile_id), round(extract(epoch FROM (r.joined_at - g.created_at))) FROM public.game_roster r JOIN public.games g ON g.id = r.game_id WHERE g.created_at >= '2026-11-01 03:16:11+00' AND g.created_at < '2026-11-02 00:00+00' ORDER BY g.created_at, r.joined_at;` → host at 0 s, non-host joins at 14384, 43184, 71984 s and 28784 s.
- Q12 — `SELECT r.status, count(*) FROM public.game_roster r JOIN public.games g ON g.id = r.game_id WHERE r.joined_at >= '2026-10-26 00:00+00' AND r.joined_at < '2026-11-02 00:00+00' AND r.profile_id <> g.creator_profile_id GROUP BY 1 ORDER BY 1;` → active 16, left 1.
- Q13 — `SELECT (u.created_at AT TIME ZONE 'UTC')::date, count(*) FROM auth.users u WHERE u.created_at >= '2026-10-26 00:00+00' AND u.created_at < '2026-11-02 00:00+00' GROUP BY 1 ORDER BY 1;` → 27 Oct 3, 28 Oct 2, 1 Nov 5.
- Q14 — `SELECT (ae.created_at AT TIME ZONE 'UTC'), EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id::text = ae.properties->>'game_id' AND r.user_id = ae.user_id AND r.joined_at BETWEEN ae.created_at - interval '5 minutes' AND ae.created_at + interval '5 minutes') FROM public.analytics_events ae WHERE ae.event_name = 'game_joined' AND ae.created_at >= '2026-10-26 00:00+00' AND ae.created_at < '2026-11-02 00:00+00' ORDER BY ae.created_at;` → both true.
- Q15 — `SELECT (u.created_at AT TIME ZONE 'UTC'), EXISTS (SELECT 1 FROM public.analytics_events ae WHERE ae.event_name='signup' AND ae.user_id = u.id), EXISTS (SELECT 1 FROM public.games g WHERE g.creator_profile_id = u.id) FROM auth.users u WHERE u.created_at >= '2026-10-26 00:00+00' AND u.created_at < '2026-11-02 00:00+00' ORDER BY u.created_at;` → 4 of 10 with a signup event; the 5 of 1 Nov created 01:50:23.671–.744 UTC.

(A variant of Q15 that also selected `raw_app_meta_data->>'provider'` was refused by the SQL hook's auth-secrets rule and never ran.)

No user identifier, email or property value is recorded in this note; only timestamps and counts.
