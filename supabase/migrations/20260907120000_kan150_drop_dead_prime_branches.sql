-- KAN-150 / P-039: remove the dead 'prime' branches from
-- calculate_notification_score and should_bypass_quiet_hours.
--
-- cpo's P-039 retires the `prime` subscription key with no replacement -- 12a
-- commits no third player tier and no notification-priority product at all, so
-- there is nothing to rehome this behaviour to. A permanently-false branch is
-- strictly worse than no branch: it reads as a live tier to the next person in
-- the file, and the comment `-- Only Prime can bypass` will outlive everyone
-- who knows prime was retired.
--
-- ============================================================================
-- AUTHORITY AND SEQUENCING
-- ============================================================================
-- Definition-only: two CREATE OR REPLACE statements, no data mutation. Under
-- G-028 that makes the apply backend-4's, after cto's confirmation is posted on
-- KAN-150. (The ticket text still says "stays inside cto's G-002 condition-3
-- authority" -- pre-G-028 wording; po's to correct, not mine.)
--
-- BUT THE APPLY IS ORDERED AND IS NOT AVAILABLE YET. It chains behind KAN-155's
-- apply, which is a CEO action under 019 (82 live user_subscriptions rows) and
-- is currently undated. team-lead-4's instruction is explicit: do not apply this
-- one. Authoring is free and confirmed free by cto; only the apply waits.
--
-- >>> RE-MEASURE BEFORE APPLYING. NON-NEGOTIABLE. <<<
--   Authoring and apply are separated here by an indefinite CEO-held wait --
--   longer than the usual gap. Before applying, re-read BOTH bodies via
--   pg_get_functiondef on the live catalogue and re-author if either has
--   drifted. A whole-body CREATE OR REPLACE authored against a body that has
--   since moved SILENTLY REVERTS whatever landed in between. That is the
--   T-058 D1 / T-052-amendment trap, and the long gap makes it likelier here
--   than anywhere else. The bodies below are current as of 2026-09-07.
--
-- ============================================================================
-- RESOLVED BY NAME AGAINST THE LIVE CATALOGUE (AC3), never from the baseline
-- dump. The dump's line numbers are known to drift and this ticket's own
-- history proves it: `:4006` was relayed as a third 'prime' site and contains
-- no 'prime' literal at all. Dump line numbers are not used as identifiers
-- anywhere in this file (AC7 discipline, carried from KAN-155).
-- ============================================================================
--
-- I did not stop at the two functions the ticket names. I swept the whole live
-- catalogue for the literal across every surface it could hide in -- functions
-- (prosrc), views and matviews, CHECK constraints, column defaults and RLS
-- policies -- plus edge functions, dabbler-admin, dabbler-web, and client Dart
-- traced through supabase_config.dart (which carries no plan constant at all,
-- so a literal grep could not have missed an indirect reference).
--
--   'prime' literal, live:  calculate_notification_score, should_bypass_quiet_hours
--                           -- EXACTLY THE TWO THIS TICKET NAMES. Nothing else.
--   'kickoff' literal, live: can_send_notification_now ONLY -- that is KAN-155's
--                           function, not this ticket's. NEITHER function below
--                           carries a kickoff fallback, so this ticket is
--                           genuinely disjoint from KAN-155's edit (AC2).
--
-- One false positive, read rather than reported: posts_mapping_check() matched
-- 'kickoff' because it enumerates the COLUMN `kickoff_at` on posts (a match
-- start time) beside start_at/start_time/game_time. Unrelated to plans.
--
-- Measured attributes, to be restated exactly and NOT inferred (AC4, T-044 /
-- CONVENTIONS.md 6c). NOTE THE ASYMMETRY -- it is easy to flatten in a rewrite:
--   calculate_notification_score  prosecdef=false, provolatile='v' (VOLATILE)
--                                 search_path = public, pg_temp
--     pg_get_functiondef emits NO volatility keyword for VOLATILE because it is
--     the default. Adding STABLE here to "match the other one" would be a
--     silent behavioural change, not tidying.
--   should_bypass_quiet_hours     prosecdef=false, provolatile='s' (STABLE)
--                                 search_path = public, pg_temp
--     Here STABLE IS emitted and must be kept.
--   Neither is SECURITY DEFINER and neither becomes one.
--
-- ============================================================================
-- AC5 -- BEHAVIOUR PRESERVATION. Stated honestly, including where a runtime
-- probe CANNOT establish it.
-- ============================================================================
-- Measured live 2026-09-07:
--   SELECT count(*) FROM public.user_subscriptions WHERE plan_key='prime'; -> 0
--   (82 active subscriptions, all on kickoff.)
-- So `v_is_prime` is already always false and the bypass already always returns
-- false, for every real caller, today. After KAN-155 the prime row will not
-- exist at all. The diff changes no output for any user, before or after.
--
-- should_bypass_quiet_hours -- probe IS meaningful, and it passes.
--   The branch is genuinely REACHED: the function selects plan_key (getting
--   'kickoff', or NULL for a user with no subscription), evaluates
--   `v_plan = 'prime'`, and falls through. Baseline captured:
--     (user with active sub,   'high')   -> false
--     (user with active sub,   'normal') -> false
--     (user with no sub,       'high')   -> false
--     (user with no sub,       'urgent') -> false
--   After this migration all four must still be false. They will be: the
--   function becomes an unconditional `RETURN false`.
--
-- calculate_notification_score -- THE PROBE CANNOT ESTABLISH ANYTHING, and
--   saying so is the point rather than reporting a green result.
--   public.notification_scores holds ZERO ROWS (measured: 0 total, 0 enabled).
--   The function therefore hits `IF NOT FOUND THEN RETURN 1;` and returns 1 for
--   every input, NEVER REACHING the Prime boost or any other weighting. Baseline
--   confirms it: score = 1 for a subscribed user and for an unsubscribed user
--   alike. A before/after probe here would show "identical" and would prove
--   NOTHING -- it never executes the code under test. This is the T-055 trap
--   (a probe that cannot fail is not evidence), in its early-return form.
--
--   Behaviour preservation is instead established by construction, which is
--   stronger than the probe would have been even if it worked:
--     (a) the branch is guarded by v_is_prime, which is always false (0 prime
--         rows now; no prime key at all after KAN-155);
--     (b) the statement being removed with it is a plain SELECT ... INTO with
--         no side effects -- it writes nothing and raises nothing (a
--         non-STRICT SELECT INTO tolerates zero rows and multiple rows alike);
--     (c) therefore removing an always-false branch plus a side-effect-free
--         read cannot change any output.
--
-- ============================================================================
-- TWO OBSERVATIONS -- OUT OF SCOPE, DELIBERATELY NOT ACTED ON. Reported, not fixed.
-- ============================================================================
-- 1. public.notification_scores is EMPTY, so calculate_notification_score is a
--    constant-1 function in production today and its entire weighting system
--    (base/actor/relationship/recency) is inert. That is a much larger question
--    than this ticket and belongs to whoever owns notification ranking. NOT
--    touched here.
-- 2. notification_scores.plan_boost_weight loses its only reader when the branch
--    below is removed. The column is NOT dropped: T-020 says dead data is not
--    dropped like dead code, and dropping a column is a schema change this
--    ticket does not authorise (AC2). Flagged for whoever owns that table.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1/2  calculate_notification_score -- remove the `-- Prime boost` lookup, the
--      `IF v_is_prime` branch, and the v_is_prime declaration whose only
--      consumer was that branch (AC1).
--
--      Body taken verbatim from pg_get_functiondef on the live catalogue.
--      VOLATILE preserved by emitting no volatility keyword -- see note above.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_notification_score(p_to_user uuid, p_kind_key text, p_actor_user uuid, p_entity_id uuid, p_total_count integer)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_rule RECORD;
    v_score numeric := 0;
    v_relationship numeric := 0;
BEGIN

    SELECT *
    INTO v_rule
    FROM public.notification_scores
    WHERE kind_key = p_kind_key
      AND is_enabled = true;

    IF NOT FOUND THEN
        RETURN 1;
    END IF;

    -- Base
    v_score := v_score + v_rule.base_weight;

    -- Actor count boost (scaled)
    v_score := v_score + (p_total_count * v_rule.actor_weight);

    -- Relationship boost (follower example)
    IF EXISTS (
        SELECT 1
        FROM public.profile_follows pf
        JOIN public.profiles p ON p.user_id = p_to_user
        WHERE pf.following_profile_id = p.id
    ) THEN
        v_relationship := 1;
    END IF;

    v_score := v_score + (v_relationship * v_rule.relationship_weight);

    -- KAN-150: the `-- Prime boost` lookup and its `IF v_is_prime` branch were
    -- removed here. The `prime` plan key is retired (P-039) with no
    -- replacement, so the branch was permanently false. v_rule is untouched and
    -- still drives every other weight; only v_is_prime and its own SELECT went.

    -- Recency boost
    v_score := v_score + v_rule.recency_weight;

    RETURN v_score;

END;
$function$;

-- ---------------------------------------------------------------------------
-- 2/2  should_bypass_quiet_hours -- remove the `-- Only Prime can bypass`
--      branch. v_plan's ONLY consumer was that branch, so v_plan and the SELECT
--      that populated it go with it, per AC1's "any other variable whose only
--      consumer is the removed branch".
--
--      >>> FLAGGED FOR cto, NOT DECIDED BY ME. <<<
--      This reduces the function to an unconditional `RETURN false`. That is
--      what AC1 literally requires, and leaving the SELECT in place would keep
--      a purposeless read of user_subscriptions on every notification while
--      leaving an assigned-but-never-read variable behind. But a
--      constant-returning function is a design smell, and the honest question
--      -- whether should_bypass_quiet_hours should exist at all now that
--      nothing can bypass quiet hours -- is NOT this ticket's to answer. AC2
--      fences scope to these two branches, and dropping the function would
--      exceed it. Left in place, returning false, for cto to rule on separately.
--
--      STABLE preserved (provolatile='s' live). Not SECURITY DEFINER.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.should_bypass_quiet_hours(p_user_id uuid, p_priority notify_priority)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN

    -- KAN-150: the `-- Only Prime can bypass` branch was removed here. The
    -- `prime` plan key is retired (P-039) with no replacement and 12a commits
    -- no notification-priority product, so nothing bypasses quiet hours. The
    -- v_plan lookup went with the branch -- it had no other consumer.
    RETURN false;

END;
$function$;

COMMIT;

-- ============================================================================
-- VERIFICATION -- run by whoever applies this, immediately after, and posted to
-- KAN-150. That posting closes G-002 condition 4.
-- ============================================================================
-- AC1  Neither body contains a 'prime' literal, and v_is_prime is gone:
--        SELECT p.oid::regprocedure, p.prosrc ILIKE '%prime%' AS has_prime
--          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--         WHERE n.nspname = 'public'
--           AND p.proname IN ('calculate_notification_score','should_bypass_quiet_hours');
--        -> both has_prime = false
--
-- AC2  Scope held. can_send_notification_now is UNCHANGED by this migration --
--      assert its body separately, since KAN-155 owns it:
--        SELECT prosrc ILIKE '%kickoff%' FROM pg_proc
--         WHERE oid = 'public.can_send_notification_now(uuid,notify_priority)'::regprocedure;
--        -> whatever KAN-155 left it as; this migration must not have moved it.
--      No other function, view, constraint, default or policy touched.
--
-- AC4  Attributes preserved EXACTLY -- assert them, do not assume:
--        SELECT p.oid::regprocedure, p.prosecdef, p.provolatile,
--               array_to_string(p.proconfig, ', ')
--          FROM pg_proc p WHERE p.proname IN
--               ('calculate_notification_score','should_bypass_quiet_hours');
--        -> calculate_notification_score : prosecdef=false, provolatile='v',
--                                          search_path=public, pg_temp
--        -> should_bypass_quiet_hours    : prosecdef=false, provolatile='s',
--                                          search_path=public, pg_temp
--        provolatile is the one most likely to be silently wrong. Check it.
--
-- AC5  Re-run the four should_bypass_quiet_hours probes; all four must still
--      return false, matching the 2026-09-07 baseline recorded above:
--        (sub user,'high') (sub user,'normal') (no-sub user,'high')
--        (no-sub user,'urgent')  -> false, false, false, false
--      For calculate_notification_score, state the T-055 limitation rather than
--      reporting a green probe: while notification_scores is empty the function
--      returns 1 by early return and the probe cannot reach the changed code.
--      If notification_scores has gained rows by apply time, the probe becomes
--      meaningful -- run it then and compare against a fresh baseline taken
--      BEFORE applying.
