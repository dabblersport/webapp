-- KAN-155 / P-039, P-040, P-041, P-042: retire kickoff/pro/prime, replace with
-- eight persona-qualified plan keys.
--
-- ============================================================================
-- AUTHORITY -- READ THIS BEFORE RUNNING ANYTHING
-- ============================================================================
-- THIS MIGRATION IS NOT APPLIED BY ANY AGENT. IT IS THE CEO'S TO APPLY.
--
-- G-028 (DECISIONS.md:8664, 2026-09-07) moved the hands for SCHEMA migrations
-- from cto to the owning backend-N. It does NOT reach this one. Its own text,
-- verbatim:
--
--   "019's reservation of user-data mutation to the CEO is untouched -- this
--    decision is about structure changes and cto's working mode."
--
--   Under "Left open, deliberately": "KAN-155 (82 live user_subscriptions
--    rows) sits on exactly this gap and stays with the CEO personally."
--
-- This migration UPDATEs 82 live user_subscriptions rows and DELETEs three live
-- parent rows. That is user-data mutation, reserved to the CEO by 019.
-- G-009's security-remediation carve-out does not reach it either -- this is a
-- monetisation change, not remediation.
--
-- Authored by backend-4 (Min). Per AC10, cto posts the plain-English brief,
-- this SQL, and a numbered verification block on KAN-155 so that the CEO's
-- apply is as small and reviewable as possible. cto's brief is not a condition
-- the CEO must satisfy -- no agent decision constrains the seat the authority
-- belongs to.
--
-- Splitting this migration to move the DDL half under agent authority is
-- expressly ruled out by cto: it buys nothing, since the CEO is in the loop
-- either way, and splitting specifically to cross an authority boundary is the
-- precedent G-002 exists to prevent.
--
-- ============================================================================
-- PRECONDITIONS -- measured live on wtncuzcskpigqpmnxwws, 2026-09-07, by
-- backend-4, immediately before authoring. Every number below is a live read,
-- not a relay. Constraint and function names are cited BY NAME, never by
-- baseline-dump line number (AC7) -- dump line numbers drift.
-- ============================================================================
--   subscription_plans is (key text NOT NULL, label text NOT NULL,
--     description text, created_at timestamptz DEFAULT now())
--   Live rows: kickoff/"Kickoff", pro/"Pro", prime/"Prime", all description NULL.
--
--   The three FKs on subscription_plans(key) -- ALL ON UPDATE NO ACTION:
--     user_subscriptions_plan_key_fkey        ON UPDATE NO ACTION  ON DELETE NO ACTION
--     subscription_features_plan_key_fkey     ON UPDATE NO ACTION  ON DELETE CASCADE
--     notification_hourly_caps_plan_key_fkey  ON UPDATE NO ACTION  ON DELETE CASCADE
--   (measured as confupdtype='a' on all three; confdeltype 'a','c','c')
--
--   Live child counts:
--     user_subscriptions       kickoff=82, pro=0, prime=0   (82 total)
--     subscription_features    kickoff=9, pro=9, prime=9    (27 total)
--     notification_hourly_caps kickoff=3, pro=3, prime=3    ( 9 total)
--
--   kickoff's VALUES -- the values every new key takes (P-041):
--     subscription_features: advanced_filtering=true, ai_priority=true,
--       circle_alerts=true, engagement_alerts=true, instant_push=true,
--       smart_batching=true, view_tracking=true,
--       quiet_override_all=FALSE, quiet_override_high=FALSE
--     notification_hourly_caps: low=5, normal=10, high=20
--
--   pro's VALUES -- MUST NOT be copied. The difference is the whole risk:
--     quiet_override_high=TRUE, caps low=10, normal=25, high=50
--   prime's: quiet_override_all=TRUE, quiet_override_high=TRUE, caps 50/100/1000
--
--   Composite constraints, BY NAME:
--     subscription_features_plan_key_feature_key_key  UNIQUE (plan_key, feature_key)
--     notification_hourly_caps_pkey                   PRIMARY KEY (plan_key, priority)
--   These guarantee UNIQUENESS ONLY. Neither touches is_enabled or
--   max_per_hour. They cannot and do not prove the values are right -- see the
--   VALUES DEFENCE section below.
--
--   notify_priority enum: low, normal, high, urgent. Only three caps rows exist
--   per key (low/normal/high); 'urgent' has no cap row on ANY key today, so
--   can_send_notification_now returns true for urgent. Pre-existing, unchanged
--   by this migration, and NOT in this ticket's scope -- noted so a reviewer
--   counting rows does not read 3-not-4 as a defect introduced here.
--
--   can_send_notification_now(uuid, notify_priority):
--     prosecdef = FALSE, proconfig = {search_path=public, pg_temp}, STABLE,
--     LANGUAGE plpgsql. Body read via pg_get_functiondef on the live catalogue
--     (AC4), not from the baseline dump.
--
-- ============================================================================
-- WHY THIS IS NOT AN UPDATE (cto, ruled)
-- ============================================================================
--   1. `pro` does not rename, it SPLITS -- one row becomes two (player_pro and
--      organiser_pro) at two different prices. A split is not expressible as an
--      UPDATE of a primary key under ANY FK configuration: one row cannot
--      become two. Once pro needs insert-and-repoint, kickoff uses the same
--      shape -- one uniform operation, one reviewable diff.
--   2. All three FKs are ON UPDATE NO ACTION, so
--      `UPDATE subscription_plans SET key='player_free' WHERE key='kickoff'`
--      fails outright: children still reference kickoff and nothing repoints them.
--
--   ON UPDATE CASCADE IS REJECTED AND MUST NOT BE PROPOSED AS A SIMPLIFICATION
--   (AC8). It would solve this one migration and leave a permanent facility for
--   silently renaming a business key across three tables with no diff at the
--   child tables at all -- the same hazard class as T-064's definer wrapper. If
--   some future rename needs it, that migration adds it, uses it, and drops it.
--   It does not live in the schema.
--
-- ============================================================================
-- THE ORDER IS THE SAFETY PROPERTY
-- ============================================================================
--   1. INSERT the eight new plan rows FIRST -- nothing references them yet, so
--      this cannot fail on integrity.
--   2. REPOINT children explicitly, one statement per child table.
--      player_free's 12 child rows (9+3) ARRIVE HERE, BY REPOINT -- they are
--      NOT seeded in step 3. The arithmetic is 84 inserted + 12 repointed = 96,
--      NOT 96 inserts. An author reading "96 new" as 96 INSERTs would either
--      double-seed player_free or repoint-then-insert it.
--   3. SEED child rows for the SEVEN remaining new keys (84 rows).
--   4. DELETE the three old rows LAST.
--
--   DELETE BEHAVIOUR -- both halves stated explicitly rather than left implicit
--   (AC5):
--     * Deleting `prime` and `pro` CASCADES to subscription_features and
--       notification_hourly_caps, silently removing 9 + 3 rows per key (24 rows
--       total). THIS IS INTENDED. Stated here so the next reader does not
--       discover it from a row count.
--     * user_subscriptions is ON DELETE NO ACTION, so deleting `kickoff` before
--       its 82 rows are repointed FAILS LOUDLY. That is a safety net, not a
--       bug. The delete stays last and is allowed to protect the migration.
--       Do not route around it. Do not "fix" it with a cascade.
--
-- ============================================================================
-- VALUES DEFENCE -- why step 3 seeds by SELECT rather than by typing 84 rows
-- ============================================================================
-- The named failure mode: a seed carrying pro's values instead of kickoff's
-- inserts CLEANLY -- keys unique and correct, non-key columns wrong -- and
-- user_has_feature then silently DENIES a paying subscriber something Player
-- Free has. The composite constraints do not catch it; they never touch
-- is_enabled or max_per_hour.
--
-- So the seed does not retype the values at all. It SELECTs them from the rows
-- that were just repointed to player_free -- i.e. from kickoff's own rows. A
-- copy-paste of pro's values is not merely discouraged here, it is structurally
-- unrepresentable: pro is not in the source of the SELECT. This is the
-- strongest available answer to child-row item 8.
--
-- Both halves of user_has_feature / can_send_notification_now fail OPEN in
-- opposite and equally bad directions, which is why complete sets matter:
--   user_has_feature is an EXISTS join requiring sf.is_enabled = true, so a
--     MISSING or DISABLED row DENIES.
--   can_send_notification_now does `IF v_cap IS NULL THEN RETURN true`, so a
--     MISSING caps row GRANTS UNLIMITED notifications.
--
-- No seed INSERT carries an ON CONFLICT clause (AC9). The composite constraints
-- mean a repoint/seed overlap fails loudly rather than duplicating silently;
-- ON CONFLICT DO NOTHING would convert that correct loud failure into a silent
-- no-op. This is deliberately the INVERSE of T-049 Decision 2's idempotency
-- ruling: that governs a replayed webhook where a duplicate is tolerable; this
-- is a one-shot structural migration where a duplicate is a bug that should
-- stop the transaction.
--
-- ============================================================================
-- SOCIALISER -- CLOSED (P-042). No plan row, permanently, not a deferral.
-- A Socialiser holds player_free. No row, ever, no follow-up INSERT ticket.
-- Four other candidates are also deliberately NOT seeded, each for its own
-- documented reason (P-039): corporate_enterprise (custom price is a sales
-- motion, not a catalogue row), Verified Organiser Certification (not a
-- subscription tier), venue_unclaimed (no user exists to hold it), socialiser.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- STEP 0 -- assert the world is what was measured. If any of this is false the
-- migration must stop before it changes anything.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_plans        int;
  v_us_kickoff   int;
  v_sf_kickoff   int;
  v_caps_kickoff int;
  v_us_other     int;
BEGIN
  SELECT count(*) INTO v_plans FROM public.subscription_plans
    WHERE key IN ('kickoff','pro','prime');
  IF v_plans <> 3 THEN
    RAISE EXCEPTION 'KAN-155 precondition: expected 3 legacy plan rows, found %', v_plans;
  END IF;

  IF EXISTS (SELECT 1 FROM public.subscription_plans
             WHERE key IN ('player_free','player_pro','organiser_pro','organiser_free',
                           'venue_basic','venue_pro','corporate_starter','corporate_growth')) THEN
    RAISE EXCEPTION 'KAN-155 precondition: a new plan key already exists -- migration already ran?';
  END IF;

  SELECT count(*) INTO v_us_kickoff FROM public.user_subscriptions WHERE plan_key='kickoff';
  SELECT count(*) INTO v_us_other   FROM public.user_subscriptions WHERE plan_key IN ('pro','prime');
  SELECT count(*) INTO v_sf_kickoff FROM public.subscription_features WHERE plan_key='kickoff';
  SELECT count(*) INTO v_caps_kickoff FROM public.notification_hourly_caps WHERE plan_key='kickoff';

  -- 82/9/3 measured 2026-09-07. If user_subscriptions has moved, that is real
  -- traffic and the number must be re-measured and this migration re-reviewed
  -- before applying -- it is NOT to be edited to match on the day.
  IF v_us_kickoff <> 82 THEN
    RAISE EXCEPTION 'KAN-155 precondition: user_subscriptions on kickoff = %, expected 82 (re-measure and re-review before applying)', v_us_kickoff;
  END IF;
  IF v_us_other <> 0 THEN
    RAISE EXCEPTION 'KAN-155 precondition: % user_subscriptions rows on pro/prime, expected 0 -- retiring those keys would strand a subscriber', v_us_other;
  END IF;
  IF v_sf_kickoff <> 9 OR v_caps_kickoff <> 3 THEN
    RAISE EXCEPTION 'KAN-155 precondition: kickoff child rows = %/% , expected 9/3', v_sf_kickoff, v_caps_kickoff;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- STEP 1 -- INSERT the eight new plan rows FIRST. Nothing references them yet.
-- `label` is 12a's exact product name per key (AC1), via P-039's mapping table.
-- Note two names that do NOT mirror their key, and are correct as written:
--   organiser_free -> "Free Organiser"      (12a §C.1 -- not "Organiser Free")
--   venue_pro      -> "Verified Venue Pro"  (12a §D.3 -- not "Venue Pro")
-- ---------------------------------------------------------------------------
INSERT INTO public.subscription_plans (key, label) VALUES
  ('player_free',       'Player Free'),         -- 12a §B.1
  ('player_pro',        'Player Pro'),          -- 12a §B.2
  ('organiser_free',    'Free Organiser'),      -- 12a §C.1
  ('organiser_pro',     'Organiser Pro'),       -- 12a §C.2
  ('venue_basic',       'Venue Basic'),         -- 12a §D.2
  ('venue_pro',         'Verified Venue Pro'),  -- 12a §D.3
  ('corporate_starter', 'Corporate Starter'),   -- 12a §E.1
  ('corporate_growth',  'Corporate Growth');    -- 12a §E.1

-- ---------------------------------------------------------------------------
-- STEP 2 -- REPOINT kickoff's children to player_free, one statement per child
-- table. Same product, new name. These 12 child rows (9+3) are player_free's
-- complete set; step 3 does NOT seed player_free.
-- ---------------------------------------------------------------------------
UPDATE public.user_subscriptions       SET plan_key='player_free' WHERE plan_key='kickoff';
UPDATE public.subscription_features    SET plan_key='player_free' WHERE plan_key='kickoff';
UPDATE public.notification_hourly_caps SET plan_key='player_free' WHERE plan_key='kickoff';

DO $$
DECLARE v_us int; v_sf int; v_caps int; v_left int;
BEGIN
  SELECT count(*) INTO v_us   FROM public.user_subscriptions       WHERE plan_key='player_free';
  SELECT count(*) INTO v_sf   FROM public.subscription_features    WHERE plan_key='player_free';
  SELECT count(*) INTO v_caps FROM public.notification_hourly_caps WHERE plan_key='player_free';
  IF v_us <> 82 OR v_sf <> 9 OR v_caps <> 3 THEN
    RAISE EXCEPTION 'KAN-155 step 2: repointed %/%/% to player_free, expected 82/9/3', v_us, v_sf, v_caps;
  END IF;

  SELECT count(*) INTO v_left FROM (
    SELECT 1 FROM public.user_subscriptions WHERE plan_key='kickoff'
    UNION ALL SELECT 1 FROM public.subscription_features WHERE plan_key='kickoff'
    UNION ALL SELECT 1 FROM public.notification_hourly_caps WHERE plan_key='kickoff'
  ) t;
  IF v_left <> 0 THEN
    RAISE EXCEPTION 'KAN-155 step 2: % child rows still on kickoff', v_left;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- STEP 3 -- SEED the SEVEN remaining new keys: 7 x (9 + 3) = 84 rows.
-- player_free is deliberately ABSENT from both key lists -- its rows arrived by
-- repoint in step 2. Including it here would violate the composite constraints
-- and abort, which is the loud failure those constraints exist to give.
--
-- Values are SELECTed from player_free (i.e. kickoff's own rows), never
-- retyped. pro is not in the source of either SELECT, so pro's values cannot
-- leak in by copy-paste. No ON CONFLICT clause (AC9).
-- ---------------------------------------------------------------------------
INSERT INTO public.subscription_features (plan_key, feature_key, is_enabled)
SELECT k.key, sf.feature_key, sf.is_enabled
FROM (VALUES ('player_pro'),('organiser_free'),('organiser_pro'),('venue_basic'),
             ('venue_pro'),('corporate_starter'),('corporate_growth')) AS k(key)
CROSS JOIN public.subscription_features sf
WHERE sf.plan_key = 'player_free';

INSERT INTO public.notification_hourly_caps (plan_key, priority, max_per_hour)
SELECT k.key, c.priority, c.max_per_hour
FROM (VALUES ('player_pro'),('organiser_free'),('organiser_pro'),('venue_basic'),
             ('venue_pro'),('corporate_starter'),('corporate_growth')) AS k(key)
CROSS JOIN public.notification_hourly_caps c
WHERE c.plan_key = 'player_free';

-- ---------------------------------------------------------------------------
-- STEP 4 -- DELETE the three legacy rows LAST.
-- prime and pro CASCADE to subscription_features and notification_hourly_caps,
-- removing 9 + 3 rows each (24 rows total). THIS IS INTENDED (AC5).
-- kickoff has no children left -- step 2 repointed all of them. Its
-- ON DELETE NO ACTION FK from user_subscriptions is the safety net: had the
-- repoint not run, this statement would fail loudly rather than orphan 82 rows.
-- ---------------------------------------------------------------------------
DELETE FROM public.subscription_plans WHERE key IN ('kickoff','pro','prime');

-- ---------------------------------------------------------------------------
-- STEP 5 -- the non-deferrable fix. THIS MIGRATION CREATES THIS REGRESSION, so
-- the fix lands here and not in KAN-150.
--
-- can_send_notification_now hardcodes its no-active-subscription fallback to
-- 'kickoff'. After step 4 that key does not exist, so the caps lookup misses,
-- v_cap IS NULL, and the function returns true: UNLIMITED NOTIFICATIONS FOR
-- EVERY USER WITH NO ACTIVE SUBSCRIPTION, which is most users. Nothing is wrong
-- today; this migration introduces it if the literal is not changed alongside.
--
-- Body taken VERBATIM from pg_get_functiondef on the live catalogue (AC4), not
-- from the baseline dump, per the standing live-catalogue-authorship rule
-- (T-058). A CREATE OR REPLACE is a whole-body replacement, not a patch: the
-- ONLY difference from the live body is 'kickoff' -> 'player_free'. Preserved
-- verbatim and deliberately: STABLE, LANGUAGE plpgsql,
-- SET search_path TO 'public', 'pg_temp', and the ABSENCE of SECURITY DEFINER
-- (prosecdef = false live, and it must stay false).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.can_send_notification_now(p_user_id uuid, p_priority notify_priority)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_plan text;
    v_cap integer;
    v_sent_count integer;
BEGIN

    -- Get active plan
    SELECT plan_key
    INTO v_plan
    FROM public.user_subscriptions
    WHERE user_id = p_user_id
      AND is_active = true
    LIMIT 1;

    IF v_plan IS NULL THEN
        v_plan := 'player_free';   -- KAN-155: was 'kickoff', retired by this migration
    END IF;

    -- Get cap
    SELECT max_per_hour
    INTO v_cap
    FROM public.notification_hourly_caps
    WHERE plan_key = v_plan
      AND priority = p_priority;

    IF v_cap IS NULL THEN
        RETURN true; -- no cap rule = allow
    END IF;

    -- Count last hour notifications
    SELECT count(*)
    INTO v_sent_count
    FROM public.notifications
    WHERE to_user_id = p_user_id
      AND priority = p_priority
      AND created_at >= now() - interval '1 hour';

    RETURN v_sent_count < v_cap;

END;
$function$;

-- ---------------------------------------------------------------------------
-- STEP 6 -- assert the end state INSIDE the transaction, so a wrong result
-- rolls the whole thing back rather than being discovered afterwards.
--
-- AC3 is asserted as a COUNTING query AND a VALUES check. The values half is
-- load-bearing and is NOT reducible to the counting half: the composite
-- constraints guarantee uniqueness only and never touch is_enabled or
-- max_per_hour. Uniqueness is not correctness.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_plan_count int;
  v_bad_key    text;
  v_sf_total   int;
  v_caps_total int;
  v_bad_vals   int;
  v_legacy     int;
BEGIN
  SELECT count(*) INTO v_plan_count FROM public.subscription_plans;
  IF v_plan_count <> 8 THEN
    RAISE EXCEPTION 'KAN-155 verify: subscription_plans has % rows, expected 8', v_plan_count;
  END IF;

  SELECT count(*) INTO v_legacy FROM public.subscription_plans
    WHERE key IN ('kickoff','pro','prime');
  IF v_legacy <> 0 THEN
    RAISE EXCEPTION 'KAN-155 verify: % legacy plan row(s) survive', v_legacy;
  END IF;

  -- AC3 counting half, phrased per key rather than by naming the eight keys,
  -- so it survives the key set changing.
  SELECT p.key INTO v_bad_key
  FROM public.subscription_plans p
  LEFT JOIN (SELECT plan_key, count(*) n FROM public.subscription_features GROUP BY plan_key) f
         ON f.plan_key = p.key
  LEFT JOIN (SELECT plan_key, count(*) n FROM public.notification_hourly_caps GROUP BY plan_key) c
         ON c.plan_key = p.key
  WHERE COALESCE(f.n,0) <> 9 OR COALESCE(c.n,0) <> 3
  LIMIT 1;
  IF v_bad_key IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-155 verify: plan % does not have exactly 9 features + 3 caps', v_bad_key;
  END IF;

  SELECT count(*) INTO v_sf_total   FROM public.subscription_features;
  SELECT count(*) INTO v_caps_total FROM public.notification_hourly_caps;
  IF v_sf_total <> 72 OR v_caps_total <> 24 THEN
    RAISE EXCEPTION 'KAN-155 verify: child totals %/%, expected 72/24 (96 combined)', v_sf_total, v_caps_total;
  END IF;

  -- AC3 VALUES half. Every key must carry Player Free's values exactly.
  -- quiet_override_high = false on EVERY key: 11b Feature 431 ("Quiet hours
  -- setting -- Standard vs Granular control") looks like it justifies true on
  -- Player Pro and DOES NOT. 431 is the USER configuring their own quiet hours;
  -- quiet_override_high is the SYSTEM delivering through them regardless. The
  -- two are opposed. Mapping 431 onto it would let a paid tier interrupt a user
  -- BECAUSE they paid -- inverting 12a §A.1 and cutting against the
  -- prayer-time/Ramadan commitments (features 432/433, both Basic, Phase 1A).
  SELECT count(*) INTO v_bad_vals FROM public.subscription_features
  WHERE (feature_key IN ('advanced_filtering','ai_priority','circle_alerts','engagement_alerts',
                         'instant_push','smart_batching','view_tracking') AND is_enabled IS DISTINCT FROM true)
     OR (feature_key IN ('quiet_override_all','quiet_override_high') AND is_enabled IS DISTINCT FROM false);
  IF v_bad_vals <> 0 THEN
    RAISE EXCEPTION 'KAN-155 verify: % subscription_features row(s) carry non-Player-Free values', v_bad_vals;
  END IF;

  SELECT count(*) INTO v_bad_vals FROM public.notification_hourly_caps
  WHERE NOT ((priority='low' AND max_per_hour=5)
          OR (priority='normal' AND max_per_hour=10)
          OR (priority='high' AND max_per_hour=20));
  IF v_bad_vals <> 0 THEN
    RAISE EXCEPTION 'KAN-155 verify: % notification_hourly_caps row(s) are not 5/10/20', v_bad_vals;
  END IF;

  -- The 82 subscriptions moved, none stranded.
  SELECT count(*) INTO v_bad_vals FROM public.user_subscriptions WHERE plan_key <> 'player_free';
  IF v_bad_vals <> 0 THEN
    RAISE EXCEPTION 'KAN-155 verify: % user_subscriptions not on player_free', v_bad_vals;
  END IF;

  -- The regression guard: the fallback key must resolve to real caps rows.
  IF NOT EXISTS (SELECT 1 FROM public.notification_hourly_caps WHERE plan_key='player_free') THEN
    RAISE EXCEPTION 'KAN-155 verify: player_free has no caps rows -- fallback would grant unlimited notifications';
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- POST-APPLY VERIFICATION -- for the record on KAN-155. Step 6 already asserts
-- all of this inside the transaction, so a failure rolls back rather than
-- landing; these are the same facts re-read afterwards for the ticket.
-- ============================================================================
-- AC1  SELECT key, label FROM public.subscription_plans ORDER BY key;
--      -> 8 rows, 12a's exact product names, no kickoff/pro/prime.
--
-- AC2  82 user_subscriptions + 9 subscription_features + 3 notification_hourly_caps
--      moved kickoff -> player_free.
--
-- AC3  SELECT p.key, count(f.*) AS feats, count(c.*) AS caps ... GROUP BY p.key;
--      -> every key exactly 9 and 3. Totals 72 + 24 = 96
--         (= 84 inserted across 7 keys + 12 repointed to player_free).
--      VALUES: seven flags true, quiet_override_all false,
--         quiet_override_high FALSE ON EVERY KEY, caps 5/10/20.
--
-- AC4  SELECT prosecdef, proconfig, pg_get_functiondef(oid) FROM pg_proc
--        WHERE oid = 'public.can_send_notification_now(uuid,notify_priority)'::regprocedure;
--      -> prosecdef STILL false, proconfig still {search_path=public, pg_temp},
--         body contains 'player_free' and no longer contains 'kickoff'.
--
-- AC5  kickoff/pro/prime gone; pro's and prime's 24 child rows cascaded away.
--
-- AC6  SELECT count(*) FROM public.subscription_plans WHERE key='socialiser'; -> 0
--
-- AC7  This file cites constraints and functions by name throughout; no
--      baseline-dump line numbers are used as identifiers.
--
-- AC8  SELECT conname, confupdtype FROM pg_constraint
--        WHERE confrelid='public.subscription_plans'::regclass AND contype='f';
--      -> all three still confupdtype='a' (NO ACTION). No ON UPDATE CASCADE added.
--
-- AC9  No ON CONFLICT clause appears anywhere above. Verified by reading the file.
