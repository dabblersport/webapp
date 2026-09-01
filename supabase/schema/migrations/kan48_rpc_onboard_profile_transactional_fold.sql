-- KAN-48 / T-037 — fold persona-extension and sport_profiles creation into
-- rpc_onboard_profile so `onboard = true` can never be set ahead of the
-- rows it implies. Backend-owner, 2026-08-29.
--
-- Background (T-037): onboarding today makes three separate client calls.
-- Step 0 (rpc_onboard_profile) sets onboard = true immediately. Steps 1
-- (persona-extension insert) and 2 (sport_profiles insert) run afterwards,
-- outside that transaction, and their failures are swallowed by empty
-- catch (_) {} blocks in auth_service.dart. Production census, 2026-08-29,
-- onboard = true, n=154: 36 of 124 players have no `player` row, 9 of 19
-- organisers have no `organiser` row, 3 of 5 hosts have no `host` row, 6
-- players have no `sport_profiles` row.
--
-- This migration extends the EXISTING rpc_onboard_profile (CREATE OR
-- REPLACE, never DROP — T-031, applied migrations are immutable) rather
-- than writing a new function. Signature is UNCHANGED — same 10
-- parameters, same order, same defaults, still RETURNS uuid — per cto's
-- contract with flutter-feature-agent, who is collapsing the client path
-- to a single call against this same signature.
--
-- What stays, verified from pg_proc before editing and NOT regressed:
--   * SECURITY DEFINER, SET search_path TO 'public'.
--   * `auth.uid() = p_user_id` check — this closed a real hole
--     (fix_rpc_onboard_profile_missing_auth_check.sql). Still the first
--     statement in the function body, unchanged.
--   * `hoster` -> `host` normalisation, one line, kept for callers this
--     migration cannot see even though the client is being fixed to stop
--     sending it.
--
-- What's new:
--   1. Persona vocabulary is validated explicitly (player/organiser/host/
--      socialiser) and RAISEs on anything else, rather than silently
--      falling through — matching T-037 decision 2's "throw, don't
--      default" instruction for _getPersonaTableName.
--   2. Persona-extension row, inserted idempotently (every one of
--      player/organiser/host has a UNIQUE constraint that makes ON
--      CONFLICT ... DO NOTHING correct — verified against
--      information_schema.table_constraints: player_profiles_profile_id_key
--      (profile_id), organiser_profiles_profile_sport_key
--      (profile_id, sport), hoster_profile_id_key (profile_id) — the
--      `hoster`-named constraint on `host` is a leftover from before the
--      table was renamed, confirming T-037's finding independently).
--   3. sport_profiles row, players only, and only when p_preferred_sport
--      is actually supplied — this matches the existing client gate
--      (welcome_screen: `intention == 'player' && preferredSport not
--      empty`) rather than inventing a new requirement. Verified live:
--      of 126 players, only 72 have preferred_sport set at all; making
--      sport_profiles unconditionally required for every player would
--      turn 54 legitimate no-sport-yet onboards into failures. The
--      6-player gap T-037 measured is exactly the case where
--      preferred_sport IS NOT NULL but the row is still missing — that's
--      what this migration closes.
--   4. `onboard = true` moves to the LAST statement in the function, in
--      both the INSERT (new profile) and UPDATE (existing profile,
--      re-onboarding) branches. A PL/pgSQL function's writes are part of
--      the caller's transaction; an uncaught RAISE EXCEPTION anywhere
--      above aborts the whole call, so if the persona or sport-profile
--      insert fails, the profile row itself never lands (on first-time
--      INSERT) and `onboard` is never flipped (on either branch). No
--      explicit BEGIN/COMMIT is used or needed inside a single function
--      body — checked pg_trigger on public.profiles for anything that
--      could misfire from the changed statement shape: no BEFORE/AFTER
--      UPDATE OF onboard trigger exists, and the two AFTER INSERT
--      triggers (trg_user_created, trg_welcome_notify) still fire exactly
--      once, since the row is still created by exactly one INSERT — the
--      onboard flip is now a separate UPDATE, not a second INSERT.
--
-- A decision made in authoring this, flagged rather than assumed:
-- `organiser.sport` is `text NOT NULL` with no default (confirmed via
-- information_schema.columns). Live census: 1 of 19 organisers has no
-- preferred_sport. There is no safe synthetic value to invent for that
-- column without corrupting what it means, so this migration RAISEs
-- EXCEPTION when persona_type = 'organiser' and p_preferred_sport IS
-- NULL, surfacing the failure to the caller instead of silently defaulting
-- — same principle as T-037 decision 2. This is a judgment call inside
-- SQL authorship, not a new product decision; flagging it on the ticket
-- for cto to override if a different UX is wanted (e.g. requiring sport
-- selection before persona = organiser is selectable, which is a client
-- concern, not this function's).
--
-- Not touched: FLutter-side collapse to one call, hoster ban in
-- supabase_config.dart / auth_service.dart / onboarding_repository.dart /
-- IntentSelectionScreen (flutter-feature-agent's half), and the ~54
-- damaged production rows (KAN-93, blocked on this ticket landing first).

CREATE OR REPLACE FUNCTION public.rpc_onboard_profile(
  p_user_id uuid,
  p_display_name text,
  p_username text,
  p_age integer,
  p_gender text,
  p_persona_type text,
  p_preferred_sport uuid DEFAULT NULL::uuid,
  p_interests uuid[] DEFAULT NULL::uuid[],
  p_country text DEFAULT NULL::text,
  p_city text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_profile_id uuid;
  v_profile_type text;
  v_persona_type text;
  v_tier_code text;
  v_sport_key text;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: can only onboard your own profile';
  END IF;

  v_persona_type := CASE p_persona_type WHEN 'hoster' THEN 'host' ELSE p_persona_type END;

  IF v_persona_type NOT IN ('player', 'organiser', 'host', 'socialiser') THEN
    RAISE EXCEPTION 'Unrecognised persona_type: %', v_persona_type;
  END IF;

  v_profile_type := CASE v_persona_type
    WHEN 'player' THEN 'personal'
    WHEN 'organiser' THEN 'business'
    WHEN 'host' THEN 'venue'
    WHEN 'socialiser' THEN 'personal'
    ELSE 'personal'
  END;

  SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id LIMIT 1;

  IF v_profile_id IS NOT NULL THEN
    UPDATE public.profiles SET
      display_name = p_display_name,
      username = p_username,
      age = p_age,
      gender = lower(p_gender),
      persona_type = v_persona_type,
      preferred_sport = p_preferred_sport,
      primary_sport = p_preferred_sport,
      interests = p_interests,
      country = p_country,
      city = p_city,
      skill_level = 1
    WHERE id = v_profile_id;
  ELSE
    INSERT INTO public.profiles (
      user_id, display_name, username, age, gender,
      profile_type, persona_type, intention,
      preferred_sport, primary_sport, interests,
      country, city, skill_level, onboard, is_player, is_active
    ) VALUES (
      p_user_id, p_display_name, p_username, p_age, lower(p_gender),
      v_profile_type, v_persona_type, v_persona_type,
      p_preferred_sport, p_preferred_sport, p_interests,
      p_country, p_city, 1, false, (v_persona_type = 'player'), true
    ) RETURNING id INTO v_profile_id;
  END IF;

  -- Persona-extension row, keyed off the normalised persona type.
  IF v_persona_type = 'player' THEN
    INSERT INTO public.player (profile_id)
    VALUES (v_profile_id)
    ON CONFLICT (profile_id) DO NOTHING;

  ELSIF v_persona_type = 'organiser' THEN
    IF p_preferred_sport IS NULL THEN
      RAISE EXCEPTION 'organiser persona requires p_preferred_sport (organiser.sport is NOT NULL)';
    END IF;
    SELECT sport_key INTO v_sport_key FROM public.sports WHERE id = p_preferred_sport;
    IF v_sport_key IS NULL THEN
      RAISE EXCEPTION 'Sport % not found', p_preferred_sport;
    END IF;
    INSERT INTO public.organiser (profile_id, sport)
    VALUES (v_profile_id, v_sport_key)
    ON CONFLICT (profile_id, sport) DO NOTHING;

  ELSIF v_persona_type = 'host' THEN
    INSERT INTO public.host (profile_id)
    VALUES (v_profile_id)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;
  -- socialiser: no persona-extension table, by design.

  -- sport_profiles, players only, and only when a sport was chosen —
  -- matches rpc_create_sport_profile's own column semantics exactly.
  IF v_persona_type = 'player' AND p_preferred_sport IS NOT NULL THEN
    SELECT sport_key INTO v_sport_key FROM public.sports WHERE id = p_preferred_sport;
    IF v_sport_key IS NULL THEN
      RAISE EXCEPTION 'Sport % not found', p_preferred_sport;
    END IF;
    INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level)
    VALUES (v_profile_id, v_sport_key, p_preferred_sport, 1)
    ON CONFLICT (profile_id, sport) DO UPDATE SET skill_level = EXCLUDED.skill_level;
  END IF;

  SELECT code INTO v_tier_code FROM public.tiers WHERE is_default = true LIMIT 1;
  IF v_tier_code IS NOT NULL THEN
    INSERT INTO public.profile_tiers (profile_id, tier_code, is_active)
    VALUES (v_profile_id, v_tier_code, true)
    ON CONFLICT DO NOTHING;
  END IF;

  -- onboard = true, LAST. If anything above raised, this never runs and
  -- the whole call's writes (including the profile INSERT on a first-time
  -- onboard) are rolled back with it.
  UPDATE public.profiles SET onboard = true WHERE id = v_profile_id;

  RETURN v_profile_id;
END;
$function$;

-- Verification.
--
-- 1. Signature and hard constraints unchanged:
--    SELECT pg_get_functiondef(p.oid) FROM pg_proc p
--    JOIN pg_namespace n ON n.oid = p.pronamespace
--    WHERE n.nspname = 'public' AND p.proname = 'rpc_onboard_profile';
--    -- expect: same 10 params/order/defaults, RETURNS uuid, SECURITY
--    -- DEFINER, SET search_path TO 'public', auth.uid() check as the
--    -- first statement.
--
-- 2. Happy path, one call per persona, read-only afterwards:
--    (call rpc_onboard_profile as each persona type with a real sport
--    where required; confirm profiles.onboard = true AND the matching
--    persona-extension row exists AND, for player with a sport, the
--    sport_profiles row exists)
--
-- 3. Failure path — the actual point of this migration. Force a
--    mid-function failure (e.g. call with persona_type = 'organiser' and
--    p_preferred_sport = NULL, which now RAISEs deliberately) against a
--    **branch**, never production, and confirm:
--      SELECT count(*) FROM public.profiles WHERE user_id = <test uid>;
--      -- expect: 0 (no row left behind, even though the INSERT ran
--      -- before the RAISE)
--    NOT independently verified by the author on a live branch — see the
--    KAN-48 comment for what could and could not be exercised and why.
