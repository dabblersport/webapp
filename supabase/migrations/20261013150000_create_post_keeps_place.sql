-- KAN-524: create_post keeps the place the user chose (circle posts included).
--
-- STATUS: AUTHORED, NOT APPLIED. Nothing in this file was run against any database. Memphis applies it
-- under the CEO approval of 2026-10-13 (execute_sql only, never apply_migration, test data only, rollback
-- in supabase/tests/create_post_place/rollback.sql). Project wtncuzcskpigqpmnxwws only.
--
-- Why. public.create_post(15 parameters) INSERTs the post without venue_id, location_name, geo_lat, geo_lng
-- or area_id, so a circle post loses the place the user chose and falls to the trg_posts_set_geo paths.
--
-- What it does (nothing is removed; the baseline body is kept verbatim except the INSERT and the guard):
--   1. Renames the 15-argument function to create_post_legacy_v1 (pattern of 20261008140000, Step 8).
--   2. Revokes ALL on the legacy function from PUBLIC, anon, authenticated (service_role keeps EXECUTE).
--   3. Creates public.create_post with the same 15 parameters in the same order, then five new defaulted
--      ones: p_venue_id, p_location_name, p_geo_lat, p_geo_lng, p_area_id (p_location_tag_id was already
--      there). The INSERT also sets venue_id, location_name, geo_lat, geo_lng, area_id; NULLs when not
--      supplied, exactly as the omitted columns behave today, so the trigger takes its existing paths.
--      Half a coordinate pair raises 'geo_incomplete' (errcode P0001).
--   4. Restores the baseline ACL on the new function: PUBLIC and anon revoked, authenticated and
--      service_role granted. SECURITY DEFINER, search_path public, pg_temp, owner postgres, and the DEBUG
--      circle exception are unchanged.
-- Because the old name is gone there is exactly one create_post, so named-argument calls stay unambiguous.
-- Callers: supabase/tests/create_post_place/CALLERS.md (the app uses named parameters only).
-- Order: sorts after KAN-497's and KAN-499's migrations (20261013100000 .. 20261013120000).

ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[]) RENAME TO create_post_legacy_v1;

REVOKE ALL ON FUNCTION public.create_post_legacy_v1(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[]) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.create_post(
  p_kind text, p_visibility text, p_post_type text DEFAULT NULL, p_origin_type text DEFAULT NULL,
  p_body text DEFAULT NULL, p_sport text DEFAULT NULL, p_media jsonb DEFAULT '[]'::jsonb,
  p_tags text[] DEFAULT '{}'::text[], p_game_id uuid DEFAULT NULL, p_location_tag_id uuid DEFAULT NULL,
  p_primary_vibe_id uuid DEFAULT NULL, p_vibe_ids uuid[] DEFAULT '{}'::uuid[],
  p_circle_ids uuid[] DEFAULT NULL, p_squad_ids uuid[] DEFAULT NULL, p_mention_profile_ids uuid[] DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL, p_location_name text DEFAULT NULL,
  p_geo_lat double precision DEFAULT NULL, p_geo_lng double precision DEFAULT NULL, p_area_id uuid DEFAULT NULL
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_uid uuid := auth.uid(); v_profile record; v_post_id uuid; v_result jsonb;
  v_cid uuid; v_sid uuid; v_mid uuid; v_post_type text; v_circle_count int := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
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
  INSERT INTO public.posts (
    author_user_id, author_profile_id, author_display_name,
    kind, visibility, post_type, origin_type,
    body, sport, media, tags, game_id, location_tag_id,
    vibe_id, persona_type_snapshot,
    venue_id, location_name, geo_lat, geo_lng, area_id
  ) VALUES (
    v_uid, v_profile.id, v_profile.display_name,
    p_kind::post_kind, p_visibility, v_post_type::post_type_enum,
    COALESCE(p_origin_type, 'manual')::origin_type_enum,
    p_body, p_sport, p_media, p_tags, p_game_id, p_location_tag_id,
    p_primary_vibe_id, v_profile.persona_type,
    p_venue_id, p_location_name, p_geo_lat, p_geo_lng, p_area_id
  ) RETURNING id INTO v_post_id;
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

ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) TO authenticated, service_role;
