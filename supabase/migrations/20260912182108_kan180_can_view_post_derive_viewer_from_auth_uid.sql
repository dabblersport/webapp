-- APPLIED 2026-09-12 via apply_migration. Ledger version 20260912182108.
--
-- KAN-180 Finding A: public.can_view_post (BOTH overloads) accepted a
-- caller-supplied viewer identity and truthfully answered an arbitrary
-- (profile, author) / (user, author) relationship question, rather than only
-- the calling identity's own access decision.
--
-- Both overloads now derive the effective viewer from auth.uid() server-side.
-- The caller-supplied parameters are RETAINED and deliberately IGNORED -- they
-- are no longer identity authority (CEO invariant: "caller-supplied profile id
-- must not be identity authority"; a DEFAULT auth.uid() parameter would NOT
-- satisfy this, since the caller could still override it).
--
-- Retain-but-ignore rather than removal, decided from the actual callers:
-- posts.posts_select_policy depends on the 3-arg signature, so dropping it
-- would require dropping and recreating an RLS policy on a live 503-row table
-- for no security benefit; CREATE OR REPLACE also preserves proacl exactly.
-- All four internal call sites already pass auth.uid() (posts_select_policy,
-- _debug_can_view, get_feed, rpc_search_posts/rpc_trending_posts pass
-- auth.uid() or `me uuid := auth.uid()`), so ignoring the arguments is
-- behaviour-preserving by construction. No Dart call sites exist (lib/
-- mentions can_view_post only in two doc comments).
--
-- AC3 behaviour-preservation, measured live before applying:
--   * get_feed was the only caller passing a non-auth.uid() third argument,
--     current_setting('request.jwt.claim.profile_id'). That GUC is dead legacy
--     -- the custom_access_token hook is commented out (supabase/config.toml:228)
--     and 20260829130300_kan82_*.sql:30 already records it as dead -- so the
--     argument is always NULL and already fell through to the same derivation.
--   * 0 users have more than one active profile, so the derived
--     "first active profile ordered by created_at" is unambiguous for every
--     existing user.
--
-- Verified live post-apply (see probes below, each demonstrated FAILING first):
--   * EXPLOIT-NEGATIVE, 3-arg, as anon: probing post 535a2b48 (visibility
--     'followers') with an arbitrary profile returned true for a real follower
--     (b4002f84) and false for a non-follower (3ab8a68d) BEFORE -- a working
--     relationship oracle. AFTER: false for both, and false when spoofing
--     p_user_id and p_profile_id together.
--   * EXPLOIT-NEGATIVE, 3-arg, as an AUTHENTICATED non-follower (2bde2ed9):
--     the same arbitrary-profile probe returned true BEFORE, false AFTER.
--   * POSITIVE CONTROL, 3-arg: the REAL follower (28307fab), acting as
--     themselves, still gets true on that same followers-only post; the author
--     (f487f2c8) still gets true on their own post; anon still gets true on a
--     public post. The implementation is not permanently false.
--   * POSITIVE CONTROL, RLS: posts_select_policy still discriminates --
--     28307fab sees 497 of 503 posts, the author sees 500, anon sees 0
--     (anon was already 0; the policy is TO authenticated).
--   * 2-arg: all three of viewer=someone-else / viewer=NULL / viewer=self now
--     return the identical answer, proving the parameter is inert; and it
--     still returns true for a public post and for the caller's own post.
--   * Attributes unchanged: 2-arg stays STABLE, NOT SECURITY DEFINER; 3-arg
--     stays STABLE SECURITY DEFINER; both keep search_path = public, pg_temp;
--     both keep anon/authenticated/service_role EXECUTE (proacl preserved).
--   * Row counts unchanged, no writes performed: posts 503, profile_follows 24,
--     profiles 165.
--
-- NOT in this migration: KAN-180 Finding B (rpc_meetup_rsvp/4's unvalidated
-- p_profile_id) is NOT fixed here. That function cannot execute at all --
-- public.can_current_user_rsvp_meetup references m.owner_user_id, a column
-- public.meetups does not have (it has creator_user_id), on an unconditional
-- path, so every call raises 42703 before reaching any profile_id write.
-- AC5's live demonstration and its positive control are both impossible until
-- that separate, out-of-surface defect is ruled on. Reported, not worked
-- around.

CREATE OR REPLACE FUNCTION public.can_view_post(p_viewer uuid, p_post posts)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-180: p_viewer is accepted for signature compatibility and is
  -- deliberately IGNORED. The effective viewer is auth.uid().
  SELECT CASE
    WHEN p_post.is_deleted OR p_post.is_hidden_admin THEN false
    WHEN p_post.author_user_id = auth.uid() THEN true
    WHEN public.is_benched(p_post.author_user_id) OR public.is_frozen(p_post.author_user_id) THEN false
    WHEN public._is_hidden(auth.uid(), p_post.author_user_id) THEN false
    WHEN p_post.visibility IN ('public','private','circle','link')
      THEN public.can_view_with_scope(auth.uid(), p_post.author_user_id, p_post.visibility, NULL)
    ELSE false
  END;
$function$;

CREATE OR REPLACE FUNCTION public.can_view_post(p_post_id uuid, p_user_id uuid, p_profile_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_author_user uuid; v_author_profile uuid; v_visibility text;
  v_user_id uuid; v_resolved_profile_id uuid;
BEGIN
  -- KAN-180: p_user_id and p_profile_id are accepted for signature
  -- compatibility and are deliberately IGNORED. The effective viewer identity
  -- is derived from auth.uid() and the canonical profiles relationship, so
  -- this function can only answer the CALLING identity's own access decision.
  v_user_id := auth.uid();

  SELECT author_user_id, author_profile_id, visibility INTO v_author_user, v_author_profile, v_visibility
  FROM public.posts WHERE id = p_post_id;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_author_user = v_user_id THEN RETURN true; END IF;
  IF v_visibility = 'public' THEN RETURN true; END IF;
  IF v_user_id IS NULL THEN RETURN false; END IF;

  SELECT id INTO v_resolved_profile_id FROM public.profiles
  WHERE user_id = v_user_id AND is_active = true ORDER BY created_at ASC LIMIT 1;

  IF v_visibility = 'followers' THEN
    IF v_resolved_profile_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (SELECT 1 FROM public.profile_follows pf WHERE pf.follower_profile_id = v_resolved_profile_id AND pf.following_profile_id = v_author_profile);
  END IF;
  IF v_visibility = 'circle' THEN
    IF v_resolved_profile_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
      SELECT 1 FROM public.post_circles pc
      JOIN public.circles c ON c.id = pc.circle_id
      LEFT JOIN public.circle_members cm ON cm.circle_id = c.id AND cm.member_profile_id = v_resolved_profile_id
      WHERE pc.post_id = p_post_id AND (
        (c.circle_type = 'private' AND cm.member_profile_id IS NOT NULL)
        OR (c.circle_type = 'followers' AND EXISTS (
            SELECT 1 FROM public.profile_follows pf
            WHERE pf.follower_profile_id = v_resolved_profile_id AND pf.following_profile_id = c.owner_profile_id))
        OR (c.circle_type = 'public')
      )
    );
  END IF;
  IF v_visibility = 'squad' THEN
    IF v_resolved_profile_id IS NULL THEN RETURN false; END IF;
    RETURN EXISTS (
      SELECT 1 FROM public.post_squads ps
      JOIN public.squad_members sm ON sm.squad_id = ps.squad_id
      WHERE ps.post_id = p_post_id AND sm.profile_id = v_resolved_profile_id AND sm.status = 'active'
    );
  END IF;
  RETURN false;
END;
$function$;

DO $$
DECLARE
  v2 oid := 'public.can_view_post(uuid,public.posts)'::regprocedure;
  v3 oid := 'public.can_view_post(uuid,uuid,uuid)'::regprocedure;
  s2 text; s3 text;
BEGIN
  SELECT prosrc INTO s2 FROM pg_proc WHERE oid = v2;
  SELECT prosrc INTO s3 FROM pg_proc WHERE oid = v3;

  -- 2-arg: caller-supplied viewer must no longer reach any decision helper
  IF s2 ~ 'can_view_with_scope\(p_viewer' OR s2 ~ '_is_hidden\(p_viewer'
     OR s2 ~ 'author_user_id = p_viewer' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 2-arg still trusts p_viewer';
  END IF;
  IF NOT (s2 ~ 'can_view_with_scope\(auth\.uid\(\)') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 2-arg does not derive viewer from auth.uid()';
  END IF;

  -- 3-arg: caller-supplied identity must no longer reach the resolved profile
  IF s3 ~ ':= p_profile_id' OR s3 ~ '= p_user_id' OR s3 ~ 'user_id = p_user_id' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 3-arg still trusts p_user_id/p_profile_id';
  END IF;
  IF NOT (s3 ~ 'v_user_id := auth\.uid\(\)') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 3-arg does not derive viewer from auth.uid()';
  END IF;

  -- attributes unchanged
  IF (SELECT prosecdef FROM pg_proc WHERE oid = v2) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 2-arg became SECURITY DEFINER';
  END IF;
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v3) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 3-arg lost SECURITY DEFINER';
  END IF;
  IF NOT ((SELECT proconfig FROM pg_proc WHERE oid = v2) @> ARRAY['search_path=public, pg_temp']) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 2-arg search_path changed';
  END IF;
  IF NOT ((SELECT proconfig FROM pg_proc WHERE oid = v3) @> ARRAY['search_path=public, pg_temp']) THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 3-arg search_path changed';
  END IF;

  -- grants preserved (CREATE OR REPLACE must not have reset proacl)
  IF NOT (SELECT proacl::text FROM pg_proc WHERE oid = v2) ~ 'authenticated=X' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 2-arg lost authenticated EXECUTE';
  END IF;
  IF NOT (SELECT proacl::text FROM pg_proc WHERE oid = v3) ~ 'authenticated=X' THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: 3-arg lost authenticated EXECUTE';
  END IF;

  -- dependent RLS policy intact
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='posts'
                 AND policyname='posts_select_policy' AND qual ~ 'can_view_post') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: posts_select_policy missing or no longer uses can_view_post';
  END IF;
END $$;
