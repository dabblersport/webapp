-- KAN-1006 / KAN-1000: Live Activity `lang` key and rpc_rating_get `is_organiser`.
--
-- Payload contract (Live Activity), additions in this migration:
--   lang  "en" | "ar". Per session user and installation: fcm_tokens.locale (that installation), then
--         profiles.language (original profile first), then 'en'. Anything starting with 'ar' is 'ar', else 'en'.
--         Computed by live_activity_lang(user_id, installation_id) at send time.
--   Carried in:
--     iOS     aps.content-state.lang (every event) and aps.attributes.lang (start)
--     Android data.lang and data.content.lang
--     rpc_live_activity_sessions  content.lang (computed live on read, so a language change shows at once)
--   NOT part of the change fingerprint: live_activity_session_step fingerprints live_activity_build_state's
--   content + basis, which carry no lang. A language change alone never bumps state_version and never sends.
--
-- rpc_rating_get gains `is_organiser` (boolean) in every response, for every event type: the caller is the
-- organiser per ratings_window(event).organiser (attendance_event's organiser, the definition ratings and results use).
-- Every existing key and behaviour is unchanged.

-- 0. Pre-image guards -----------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure)) <> '8e1597c04d3fd91637e02002637ccc8e'
  OR md5(pg_get_functiondef('public.rpc_live_activity_sessions(text)'::regprocedure)) <> 'd0fd29f45af6df483f73a6ed6d00fa73'
  OR md5(pg_get_functiondef('public.rpc_rating_get(uuid)'::regprocedure)) <> 'd311fe46d40503d9a3fd5a63f39a0675'
  THEN RAISE EXCEPTION 'kan1006b pre-image mismatch'; END IF;
END
$guard$;

-- 1. Language resolver ----------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_lang(p_user_id uuid, p_installation_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN coalesce(
           (SELECT nullif(f.locale, '') FROM public.fcm_tokens f
             WHERE f.user_id = p_user_id AND f.installation_id = p_installation_id LIMIT 1),
           (SELECT nullif(p.language, '') FROM public.profiles p WHERE p.user_id = p_user_id
             ORDER BY p.is_original DESC NULLS LAST, p.created_at LIMIT 1),
           'en') ILIKE 'ar%' THEN 'ar' ELSE 'en' END;
$function$;

-- 2. Edits of the live definitions ----------------------------------------------------------------------------------
DO $edit$
DECLARE d text; d2 text;
BEGIN
  -- enqueue: lang in content-state / data content, attributes on start, android data
  d := pg_get_functiondef('public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure);
  d2 := replace(d, $o$jsonb_build_object('state_version', v_ver));$o$,
    $n$jsonb_build_object('state_version', v_ver, 'lang', public.live_activity_lang(s.user_id, s.installation_id)));$n$);
  d2 := replace(d2, $o$'title', v_c->>'title')),$o$, $n$'title', v_c->>'title', 'lang', v_c->>'lang')),$n$);
  d2 := replace(d2, $o$'state_version', v_ver::text, 'content', v_c::text));$o$,
    $n$'state_version', v_ver::text, 'lang', v_c->>'lang', 'content', v_c::text));$n$);
  IF (length(d2) - length(d)) <> length(', ''lang'', public.live_activity_lang(s.user_id, s.installation_id)')
       + 2 * length(', ''lang'', v_c->>''lang''') THEN
    RAISE EXCEPTION 'kan1006b: enqueue edit did not apply exactly';
  END IF;
  EXECUTE d2;

  -- sessions: content.lang computed on read
  d := pg_get_functiondef('public.rpc_live_activity_sessions(text)'::regprocedure);
  d2 := replace(d, $o$'content', s.last_content)$o$,
    $n$'content', s.last_content || jsonb_build_object('lang', public.live_activity_lang(s.user_id, s.installation_id)))$n$);
  IF d2 = d THEN RAISE EXCEPTION 'kan1006b: sessions edit did not apply'; END IF;
  EXECUTE d2;

  -- rating_get: is_organiser in all three responses
  d := pg_get_functiondef('public.rpc_rating_get(uuid)'::regprocedure);
  d2 := replace(d, $o$THEN 'not_eligible' ELSE 'not_open' END);$o$,
    $n$THEN 'not_eligible' ELSE 'not_open' END, 'is_organiser', w.organiser IS NOT DISTINCT FROM v_uid);$n$);
  d2 := replace(d2, $o$RETURN jsonb_build_object('state', 'not_open');$o$,
    $n$RETURN jsonb_build_object('state', 'not_open', 'is_organiser', w.organiser IS NOT DISTINCT FROM v_uid);$n$);
  d2 := replace(d2, $o$'state', v_state, 'opens_at'$o$,
    $n$'state', v_state, 'is_organiser', w.organiser IS NOT DISTINCT FROM v_uid, 'opens_at'$n$);
  IF (length(d2) - length(d)) <> 3 * length(', ''is_organiser'', w.organiser IS NOT DISTINCT FROM v_uid') THEN
    RAISE EXCEPTION 'kan1006b: rating_get edit did not apply exactly';
  END IF;
  EXECUTE d2;
END
$edit$;

-- 3. ACL ------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.live_activity_lang(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_activity_lang(uuid,text) TO service_role;

-- 4. Post-assert ----------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure::text f, pg_get_userbyid(p.proowner) o, p.prosecdef d, p.proconfig c,
                  p.proacl::text a, pg_get_functiondef(p.oid) src
             FROM pg_proc p WHERE p.oid IN ('public.live_activity_lang(uuid,text)'::regprocedure,
               'public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure,
               'public.rpc_live_activity_sessions(text)'::regprocedure, 'public.rpc_rating_get(uuid)'::regprocedure) LOOP
    IF r.o <> 'postgres' OR NOT r.d OR r.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
      RAISE EXCEPTION 'kan1006b post-assert attributes: %', r.f;
    END IF;
    IF r.f IN ('live_activity_lang(uuid,text)', 'live_activity_enqueue(uuid,text,text,jsonb)')
       AND r.a IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan1006b post-assert acl: % %', r.f, r.a;
    END IF;
    IF r.f = 'rpc_live_activity_sessions(text)'
       AND r.a IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan1006b post-assert acl: % %', r.f, r.a;
    END IF;
    IF r.f = 'rpc_rating_get(uuid)'
       AND r.a IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}' THEN
      RAISE EXCEPTION 'kan1006b post-assert acl: % %', r.f, r.a;
    END IF;
  END LOOP;
END
$post$;
