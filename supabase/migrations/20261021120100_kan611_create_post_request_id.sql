-- KAN-611 (2 of 4): create_post gains p_request_id.
--
-- STATUS: AUTHORED, NOT APPLIED. Memphis applies it after 20261021120000 (execute_sql only, never apply_migration).
-- Project wtncuzcskpigqpmnxwws only.
--
-- The 20-argument create_post (20261013125000) is renamed create_post_legacy_v2 and closed to clients. The new
-- 21-argument create_post is the legacy body VERBATIM plus exactly one trailing defaulted parameter, p_request_id, and
-- the code that uses it:
--   * right after the caller is identified (auth.uid()), and before every guard and insert, a lookup of
--     (author_user_id, request_id): a repeat returns the first call's post in the same jsonb shape and inserts nothing;
--   * request_id is written on the INSERT;
--   * a concurrent twin that loses the race on posts_author_user_request_id_key gets the winner's post back;
--     any other unique violation is re-raised.
-- Without p_request_id the function behaves exactly as today. Hashtags are NOT in scope here.
--
-- ACL (orchestrator ruling): EXECUTE for authenticated and service_role only; PUBLIC and anon revoked and asserted.

-- Pre-check: exactly one create_post overload, and no create_post_legacy_v2 yet.
DO $pre$
BEGIN
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'create_post') <> 1 THEN
    RAISE EXCEPTION 'KAN611 pre-check: expected exactly one public.create_post overload';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'create_post_legacy_v2') THEN
    RAISE EXCEPTION 'KAN611 pre-check: public.create_post_legacy_v2 already exists';
  END IF;
END
$pre$;

ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) RENAME TO create_post_legacy_v2;

REVOKE ALL ON FUNCTION public.create_post_legacy_v2(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.create_post(
  p_kind text, p_visibility text, p_post_type text DEFAULT NULL, p_origin_type text DEFAULT NULL,
  p_body text DEFAULT NULL, p_sport text DEFAULT NULL, p_media jsonb DEFAULT '[]'::jsonb,
  p_tags text[] DEFAULT '{}'::text[], p_game_id uuid DEFAULT NULL, p_location_tag_id uuid DEFAULT NULL,
  p_primary_vibe_id uuid DEFAULT NULL, p_vibe_ids uuid[] DEFAULT '{}'::uuid[],
  p_circle_ids uuid[] DEFAULT NULL, p_squad_ids uuid[] DEFAULT NULL, p_mention_profile_ids uuid[] DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL, p_location_name text DEFAULT NULL,
  p_geo_lat double precision DEFAULT NULL, p_geo_lng double precision DEFAULT NULL, p_area_id uuid DEFAULT NULL,
  p_request_id uuid DEFAULT NULL
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_uid uuid := auth.uid(); v_profile record; v_post_id uuid; v_result jsonb;
  v_cid uuid; v_sid uuid; v_mid uuid; v_post_type text; v_circle_count int := 0;
  v_constraint text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  -- KAN-611: request-id lookup FIRST, before every guard and insert. A repeat returns the first call's post.
  IF p_request_id IS NOT NULL THEN
    SELECT id INTO v_post_id FROM public.posts WHERE author_user_id = v_uid AND request_id = p_request_id;
    IF v_post_id IS NOT NULL THEN
      SELECT to_jsonb(p.*) || jsonb_build_object(
        'vibe',
        CASE WHEN p.vibe_id IS NOT NULL THEN (
          SELECT jsonb_build_object('id', v.id, 'key', v.key, 'label_en', v.label_en, 'label_ar', v.label_ar, 'emoji', v.emoji, 'color_hex', v.color_hex)
          FROM public.vibes v WHERE v.id = p.vibe_id
        ) ELSE NULL END
      ) INTO v_result FROM public.posts p WHERE p.id = v_post_id;
      RETURN v_result;
    END IF;
  END IF;
  SELECT id, display_name, persona_type INTO v_profile FROM public.profiles
  WHERE user_id = v_uid AND is_active = true ORDER BY created_at ASC LIMIT 1;
  IF v_profile IS NULL THEN
    SELECT id, display_name, persona_type INTO v_profile FROM public.profiles
    WHERE user_id = v_uid ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_profile IS NULL THEN RAISE EXCEPTION 'No profile found for user %', v_uid; END IF;
  -- Half a point is never stored (KAN-524).
  IF (p_geo_lat IS NULL) <> (p_geo_lng IS NULL) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'geo_incomplete';
  END IF;
  v_post_type := COALESCE(p_post_type, p_kind);
  IF v_post_type = 'kickin' THEN v_post_type := 'kick_in'; END IF;
  BEGIN
    INSERT INTO public.posts (
      author_user_id, author_profile_id, author_display_name,
      kind, visibility, post_type, origin_type,
      body, sport, media, tags, game_id, location_tag_id,
      vibe_id, persona_type_snapshot,
      venue_id, location_name, geo_lat, geo_lng, area_id,
      request_id
    ) VALUES (
      v_uid, v_profile.id, v_profile.display_name,
      p_kind::post_kind, p_visibility, v_post_type::post_type_enum,
      COALESCE(p_origin_type, 'manual')::origin_type_enum,
      p_body, p_sport, p_media, p_tags, p_game_id, p_location_tag_id,
      p_primary_vibe_id, v_profile.persona_type,
      p_venue_id, p_location_name, p_geo_lat, p_geo_lng, p_area_id,
      p_request_id
    ) RETURNING id INTO v_post_id;
  EXCEPTION WHEN unique_violation THEN
    -- KAN-611: a concurrent call with the same request id won the race; hand back its post. Anything else re-raises.
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    IF p_request_id IS NULL OR v_constraint IS DISTINCT FROM 'posts_author_user_request_id_key' THEN
      RAISE;
    END IF;
    SELECT id INTO v_post_id FROM public.posts WHERE author_user_id = v_uid AND request_id = p_request_id;
    IF v_post_id IS NULL THEN RAISE; END IF;
    SELECT to_jsonb(p.*) || jsonb_build_object(
      'vibe',
      CASE WHEN p.vibe_id IS NOT NULL THEN (
        SELECT jsonb_build_object('id', v.id, 'key', v.key, 'label_en', v.label_en, 'label_ar', v.label_ar, 'emoji', v.emoji, 'color_hex', v.color_hex)
        FROM public.vibes v WHERE v.id = p.vibe_id
      ) ELSE NULL END
    ) INTO v_result FROM public.posts p WHERE p.id = v_post_id;
    RETURN v_result;
  END;
  IF p_visibility = 'circle' AND p_circle_ids IS NOT NULL AND array_length(p_circle_ids, 1) > 0 THEN
    FOREACH v_cid IN ARRAY p_circle_ids LOOP
      INSERT INTO public.post_circles (post_id, circle_id) VALUES (v_post_id, v_cid) ON CONFLICT DO NOTHING;
      v_circle_count := v_circle_count + 1;
    END LOOP;
  END IF;
  IF p_visibility = 'circle' THEN
    IF NOT EXISTS (SELECT 1 FROM public.post_circles WHERE post_id = v_post_id) THEN
      RAISE EXCEPTION 'DEBUG: circle insert failed. p_circle_ids=%, array_length=%, loop_count=%',
        p_circle_ids, array_length(p_circle_ids, 1), v_circle_count;
    END IF;
  END IF;
  IF p_visibility = 'squad' AND p_squad_ids IS NOT NULL AND array_length(p_squad_ids, 1) > 0 THEN
    FOREACH v_sid IN ARRAY p_squad_ids LOOP
      INSERT INTO public.post_squads (post_id, squad_id) VALUES (v_post_id, v_sid) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;
  IF p_mention_profile_ids IS NOT NULL AND array_length(p_mention_profile_ids, 1) > 0 THEN
    FOREACH v_mid IN ARRAY p_mention_profile_ids LOOP
      INSERT INTO public.post_mentions (post_id, mentioned_profile_id) VALUES (v_post_id, v_mid) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;
  SELECT to_jsonb(p.*) || jsonb_build_object(
    'vibe',
    CASE WHEN p.vibe_id IS NOT NULL THEN (
      SELECT jsonb_build_object('id', v.id, 'key', v.key, 'label_en', v.label_en, 'label_ar', v.label_ar, 'emoji', v.emoji, 'color_hex', v.color_hex)
      FROM public.vibes v WHERE v.id = p.vibe_id
    ) ELSE NULL END
  ) INTO v_result FROM public.posts p WHERE p.id = v_post_id;
  RETURN v_result;
END;
$$;

ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) TO authenticated, service_role;

-- Post-check: the new create_post ACL holds no PUBLIC (grantee 0) and no anon entry, and is not NULL (NULL = default
-- PUBLIC execute).
DO $post$
DECLARE f regprocedure := 'public.create_post(text,text,text,text,text,text,jsonb,text[],uuid,uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid,text,double precision,double precision,uuid,uuid)'::regprocedure;
BEGIN
  IF (SELECT proacl FROM pg_proc WHERE oid = f) IS NULL
     OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                 WHERE p.oid = f AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)) THEN
    RAISE EXCEPTION 'KAN611 post-check: create_post is executable by PUBLIC or anon';
  END IF;
END
$post$;
