-- KAN-100 (KAN-82 Part 2): public.get_profile_by_id still does
-- row_to_json(p.*), returning every column of profiles (present and future)
-- to any authenticated caller who knows a profile id, and the SECURITY
-- DEFINER RLS-bypass lets a stranger open a persona its owner has switched
-- away from (is_active = false).
--
-- CPO ruling P-028 (docs/DECISIONS.md), KAN-100 comment, 2026-09-01:
--
-- 1. Explicit 21-column allowlist, replacing row_to_json(p.*):
--    id, user_id, username, display_name, avatar_url, bio, age, city,
--    country, gender, language, verified, is_active, profile_type,
--    persona_type, intention, preferred_sport, primary_sport, interests,
--    created_at, updated_at.
--    Deliberately excludes: latitude/longitude/last_location_updated_at
--    (precise coordinates -- shipped granularity on a profile is city, never
--    exact geo), last_seen (presence), news (notification pref, self-only),
--    hashtag_reputation_score/skill_level/is_player (legacy scoring),
--    onboard/profile_completion/is_original/search_tsv (internal state).
--    user_id is retained -- live caller
--    (supabase_profile_datasource.dart:42, _enrichWithAuthData) depends on
--    it, and it is already handed to anon in bulk via profiles_select_public
--    per T-041 item 3; that is a separate finding, not this ticket's to fix.
--
-- 2. Same 21 columns for any authenticated caller when is_active = true --
--    not a reduced set. This RPC loads the same profile screen as the
--    normal path, just reached by profile id; a reduced set would make the
--    screen render differently depending on which path loaded it.
--
-- 3. When is_active = false, the SECURITY DEFINER bypass narrows to the
--    profile's own owner (p.user_id = auth.uid()). RLS on profiles already
--    admits (user_id = auth.uid() OR is_active = true) with no bypass, so
--    the escalation was only ever buying a stranger's read of a benched
--    persona -- which P-019 already ruled is not the public-facing
--    identity. A stranger now gets the same null a nonexistent id gets.
--    SECURITY DEFINER is kept: the owner-reads-own-benched-persona case
--    still needs it under the current RLS policy set.
--
-- CAUTION: CREATE OR REPLACE FUNCTION resets a function's ACL (this project
-- has been bitten by this class of silent reopening before -- see
-- security_invoker being reset on CREATE OR REPLACE VIEW, and KAN-82's own
-- note on this same function). REVOKE/GRANT is re-applied AFTER the body
-- change, in this same migration, matching the ACL already live
-- (authenticated + service_role EXECUTE, no PUBLIC/anon) rather than
-- assumed to survive.
--
-- G-002: authored by backend-owner, NOT applied here. cto applies after
-- measuring preconditions live and posting verification back to KAN-100.

CREATE OR REPLACE FUNCTION public.get_profile_by_id(p_profile_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'id', p.id,
      'user_id', p.user_id,
      'username', p.username,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url,
      'bio', p.bio,
      'age', p.age,
      'city', p.city,
      'country', p.country,
      'gender', p.gender,
      'language', p.language,
      'verified', p.verified,
      'is_active', p.is_active,
      'profile_type', p.profile_type,
      'persona_type', p.persona_type,
      'intention', p.intention,
      'preferred_sport', p.preferred_sport,
      'primary_sport', p.primary_sport,
      'interests', p.interests,
      'created_at', p.created_at,
      'updated_at', p.updated_at
    )
    FROM profiles p
    WHERE p.id = p_profile_id
      AND (p.is_active = true OR p.user_id = auth.uid())
    LIMIT 1
  );
END;
$function$;

-- Re-apply grants AFTER the body change -- CREATE OR REPLACE can reset the ACL.
REVOKE EXECUTE ON FUNCTION public.get_profile_by_id(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_by_id(uuid) TO authenticated, service_role;

-- ============================================================
-- VERIFICATION (run all, all must hold)
-- ============================================================
-- 1. has_function_privilege('anon', 'public.get_profile_by_id(uuid)',
--    'EXECUTE') is false; has_function_privilege('authenticated', ...) is
--    true -- ACL unchanged from KAN-82.
--
-- 2. As an authenticated caller, get_profile_by_id on an is_active = true
--    profile returns exactly the 21 allowlisted keys -- no latitude,
--    longitude, last_location_updated_at, last_seen, news,
--    hashtag_reputation_score, skill_level, is_player, onboard,
--    profile_completion, is_original, or search_tsv.
--
-- 3. As a stranger (auth.uid() <> user_id), get_profile_by_id on an
--    is_active = false profile returns null -- same as a nonexistent id.
--
-- 4. As the owning caller (auth.uid() = user_id), get_profile_by_id on
--    their own is_active = false profile still returns the 21 columns --
--    the owner-reads-own-benched-persona path (KAN-82 AC4 / PO's roposox
--    check on 2026-08-30) must survive this narrowing.
--
-- 5. Profile loading via supabase_profile_datasource.dart still works on
--    Canary for the normal (is_active = true, any caller) case, exercised
--    in the running app.
--
-- 6. flutter-feature-agent has designed the not-found state for a stranger
--    following a stale link to a now-benched profile (P-019(a): designed,
--    not defaulted -- neutral, no "deleted"/"banned" wording) before this
--    is treated as fully closed.
