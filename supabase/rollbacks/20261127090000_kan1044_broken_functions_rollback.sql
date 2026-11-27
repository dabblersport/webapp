-- Rollback for KAN-1044 (20261127090000_kan1044_broken_functions.sql).
-- Every function body below is pg_get_functiondef output captured 2026-11-27 before the migration, with its ACL.
BEGIN;
SET LOCAL check_function_bodies = off;  -- the dropped SQL functions reference relations that no longer exist
DROP INDEX IF EXISTS public.squad_join_requests_pending_uniq;
DROP FUNCTION IF EXISTS public.rpc_squad_create(text,text,text,text,text,text,integer,text);

-- enforce_single_level_reply()
CREATE OR REPLACE FUNCTION public.enforce_single_level_reply()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    parent_parent_id uuid;
BEGIN
    -- If this is a reply
    IF NEW.parent_comment_id IS NOT NULL THEN

        -- Check if parent itself is already a reply
        SELECT parent_comment_id
        INTO parent_parent_id
        FROM public.post_comments
        WHERE id = NEW.parent_comment_id;

        IF parent_parent_id IS NOT NULL THEN
            RAISE EXCEPTION 'Replies to replies are not allowed (single-level threading only)';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.enforce_single_level_reply() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.enforce_single_level_reply() TO service_role;

-- is_shadow_hidden(text,uuid)
CREATE OR REPLACE FUNCTION public.is_shadow_hidden(p_table text, p_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1 from public.content_enforcement e
    where e.target_table = p_table
      and e.target_id = p_id
      and e.action = 'shadow_hide'
      and e.active = true
      and (e.expires_at is null or now() < e.expires_at)
  )
$function$;
REVOKE ALL ON FUNCTION public.is_shadow_hidden(text,uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_shadow_hidden(text,uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_shadow_hidden(text,uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_shadow_hidden(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_shadow_hidden(text,uuid) TO service_role;

-- is_takedown(text,uuid)
CREATE OR REPLACE FUNCTION public.is_takedown(p_table text, p_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1 from public.content_enforcement e
    where e.target_table = p_table
      and e.target_id = p_id
      and e.action = 'takedown'
      and e.active = true
      and (e.expires_at is null or now() < e.expires_at)
  )
$function$;
REVOKE ALL ON FUNCTION public.is_takedown(text,uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_takedown(text,uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_takedown(text,uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_takedown(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_takedown(text,uuid) TO service_role;

-- rpc_create_post(uuid,text,text,text,text,text,uuid,double precision,double precision,jsonb,uuid[])
CREATE OR REPLACE FUNCTION public.rpc_create_post(p_author_profile_id uuid, p_kind text, p_visibility text, p_body text DEFAULT NULL::text, p_lang text DEFAULT NULL::text, p_sport_key text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_geo_lat double precision DEFAULT NULL::double precision, p_geo_lng double precision DEFAULT NULL::double precision, p_media jsonb DEFAULT '[]'::jsonb, p_vibe_ids uuid[] DEFAULT NULL::uuid[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  prof record;
  new_id uuid;
  ltoken text := null;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  select id, user_id, profile_type into prof from public.profiles where id=p_author_profile_id;
  if not found or prof.user_id <> auth.uid() then
    raise exception using errcode='P0001', message='not_profile_owner';
  end if;
  if p_kind not in ('moment','dab','kickin') then raise exception using errcode='P0001', message='invalid_kind'; end if;
  if p_visibility not in ('public','circle','link','private') then raise exception using errcode='P0001', message='invalid_visibility'; end if;

  if p_visibility='link' then ltoken := public._gen_link_token(); end if;

  insert into public.posts(
    author_profile_id, author_user_id, kind, visibility, link_token,
    body, lang, sport_key, venue_id, geo_lat, geo_lng, media
  )
  values (
    p_author_profile_id, prof.user_id, p_kind, p_visibility, ltoken,
    left(p_body, 2000), p_lang, p_sport_key, p_venue_id, p_geo_lat, p_geo_lng,
    coalesce(p_media, '[]'::jsonb)
  )
  returning id into new_id;

  if p_vibe_ids is not null and array_length(p_vibe_ids,1) is not null then
    insert into public.post_vibes(post_id, vibe_id)
    select new_id, unnest(p_vibe_ids)::uuid
    on conflict do nothing;
  end if;

  return new_id;
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_create_post(uuid,text,text,text,text,text,uuid,double precision,double precision,jsonb,uuid[]) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_create_post(uuid,text,text,text,text,text,uuid,double precision,double precision,jsonb,uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_create_post(uuid,text,text,text,text,text,uuid,double precision,double precision,jsonb,uuid[]) TO service_role;

-- rpc_create_squad(uuid,text,text,text,text)
CREATE OR REPLACE FUNCTION public.rpc_create_squad(p_actor_profile_id uuid, p_sport text, p_name text, p_bio text DEFAULT NULL::text, p_logo_url text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor_user uuid;
  actor_type text;
  sid uuid;
  founder_is_player boolean;
begin
  if auth.uid() is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  if public.is_frozen(auth.uid()) then
    raise exception using errcode='P0001', message='user_frozen';
  end if;

  select user_id, profile_type into actor_user, actor_type from public.profiles where id = p_actor_profile_id;
  if actor_user is null or actor_user <> auth.uid() then
    raise exception using errcode='P0001', message='not_profile_owner';
  end if;

  if actor_type not in ('player','organiser') then
    raise exception using errcode='P0001', message='invalid_actor_type';
  end if;

  founder_is_player := (actor_type = 'player');

  if founder_is_player then
    -- Enforce: player can found at most 1 squad per sport
    if exists (select 1 from public.squads s where s.owner_user_id = actor_user and s.sport = p_sport) then
      raise exception using errcode='P0001', message='founder_limit_reached';
    end if;
  end if;

  insert into public.squads(sport, owner_profile_id, owner_user_id, name, bio, logo_url)
  values (p_sport, p_actor_profile_id, actor_user, p_name, p_bio, p_logo_url)
  returning id into sid;

  -- If founder is player, auto-join as captain
  if founder_is_player then
    insert into public.squad_members(squad_id, profile_id, user_id, role, status)
    values (sid, p_actor_profile_id, actor_user, 'captain', 'active');
  end if;

  -- Emit event
  perform public.emit_event('squad.created','squad', sid, actor_user, jsonb_build_object('sport', p_sport));

  return sid;
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_create_squad(uuid,text,text,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_create_squad(uuid,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_create_squad(uuid,text,text,text,text) TO service_role;

-- rpc_draft_publish_challenge(uuid)
CREATE OR REPLACE FUNCTION public.rpc_draft_publish_challenge(p_draft_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d record; cid uuid; h text; f jsonb;
begin
  select * into d from public.content_drafts
  where id = p_draft_id and owner_user_id = auth.uid() and context='challenge' and status='draft';
  if not found then raise exception using errcode='P0001', message='draft_not_found'; end if;

  if not exists (select 1 from information_schema.routines where routine_name='create_challenge') then
    raise exception using errcode='P0001', message='create_challenge_not_implemented';
  end if;

  cid := public.create_challenge(d.payload);

  select hash, fields into h, f from public.compute_challenge_fingerprint(d.payload);
  perform public.reuse_touch('challenge', f, h, 1, auth.uid(), d.payload);

  update public.content_drafts set status='published', updated_at=now() where id = d.id;
  insert into public.content_draft_events(draft_id, owner_user_id, action, details)
  values (d.id, auth.uid(), 'published', jsonb_build_object('challenge_id',cid));

  return cid;
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_draft_publish_challenge(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_draft_publish_challenge(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_draft_publish_challenge(uuid) TO service_role;

-- rpc_draft_publish_game(uuid)
CREATE OR REPLACE FUNCTION public.rpc_draft_publish_game(p_draft_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE d record; gid uuid; h text; f jsonb;
BEGIN
  SELECT * INTO d FROM public.content_drafts
  WHERE id = p_draft_id AND owner_user_id = auth.uid() AND context='game' AND status='draft';
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='draft_not_found'; END IF;
  gid := public.create_game(d.payload);
  SELECT hash, fields INTO h, f FROM public.compute_game_fingerprint(d.payload);
  PERFORM public.reuse_touch('game', f, h, 1, auth.uid(), d.payload);
  UPDATE public.content_drafts SET status='published', updated_at=now() WHERE id = d.id;
  INSERT INTO public.content_draft_events(draft_id, owner_user_id, action, details)
  VALUES (d.id, auth.uid(), 'published', jsonb_build_object('game_id', gid));
  RETURN gid;
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_draft_publish_game(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_draft_publish_game(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_draft_publish_game(uuid) TO service_role;

-- rpc_draft_publish_meetup(uuid)
CREATE OR REPLACE FUNCTION public.rpc_draft_publish_meetup(p_draft_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE d record; mid uuid; h text; f jsonb;
BEGIN
  SELECT * INTO d FROM public.content_drafts
  WHERE id = p_draft_id AND owner_user_id = auth.uid() AND context='meetup' AND status='draft';
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='draft_not_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name='create_meetup') THEN
    RAISE EXCEPTION USING errcode='P0001', message='create_meetup_not_implemented';
  END IF;
  mid := public.create_meetup(d.payload);
  SELECT hash, fields INTO h, f FROM public.compute_meetup_fingerprint(d.payload);
  PERFORM public.reuse_touch('meetup', f, h, 1, auth.uid(), d.payload);
  UPDATE public.content_drafts SET status='published', updated_at=now() WHERE id = d.id;
  INSERT INTO public.content_draft_events(draft_id, owner_user_id, action, details)
  VALUES (d.id, auth.uid(), 'published', jsonb_build_object('meetup_id', mid));
  RETURN mid;
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_draft_publish_meetup(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_draft_publish_meetup(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_draft_publish_meetup(uuid) TO service_role;

-- rpc_flag_content(text,uuid,text,text)
CREATE OR REPLACE FUNCTION public.rpc_flag_content(p_table text, p_id uuid, p_reason_code text, p_details text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare rid uuid;
begin
  -- frozen users cannot file reports
  perform public.guard_user_not_frozen(auth.uid());

  insert into public.content_reports(reporter_user_id, target_table, target_id, reason_code, details, status)
  values (auth.uid(), p_table, p_id, p_reason_code, p_details, 'open')
  returning id into rid;

  return rid;
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_flag_content(text,uuid,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_flag_content(text,uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_flag_content(text,uuid,text,text) TO service_role;

-- rpc_report_post(uuid,text,text)
CREATE OR REPLACE FUNCTION public.rpc_report_post(p_post_id uuid, p_reason text, p_details text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  insert into public.post_reports(post_id, reporter_user_id, reason, details)
  values (p_post_id, auth.uid(), left(p_reason,140), left(p_details,500))
  on conflict (post_id, reporter_user_id) do update
    set reason = excluded.reason, details = excluded.details, status='open', updated_at=now();
  select 'reported';
$function$;
REVOKE ALL ON FUNCTION public.rpc_report_post(uuid,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_report_post(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_report_post(uuid,text,text) TO service_role;

-- rpc_review_report(uuid,text,text,text)
CREATE OR REPLACE FUNCTION public.rpc_review_report(p_report_id uuid, p_new_status text, p_resolution_notes text DEFAULT NULL::text, p_action text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  r       record;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;
  if p_new_status not in ('reviewing','resolved','dismissed') then
    raise exception using errcode='P0001', message='invalid_status';
  end if;

  select * into r from public.content_reports where id = p_report_id for update;
  if not found then raise exception using errcode='P0001', message='report_not_found'; end if;

  update public.content_reports
     set status         = p_new_status,
         resolved_by    = case when p_new_status in ('resolved','dismissed') then v_actor else resolved_by end,
         resolution_notes = p_resolution_notes
   where id = p_report_id;

  if p_new_status = 'resolved' and p_action is not null then
    if p_action = 'shadow_hide' then
      perform public.rpc_shadow_hide(r.target_table, r.target_id, coalesce(p_resolution_notes,'report_resolved'), null);
    elsif p_action = 'takedown' then
      perform public.rpc_takedown(r.target_table, r.target_id, coalesce(p_resolution_notes,'report_resolved'));
    end if;
  end if;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, reason, metadata)
  values (
    v_actor,
    case when p_new_status='dismissed' then 'report_dismissed' else 'report_resolved' end,
    r.target_table, r.target_id,
    p_resolution_notes,
    jsonb_build_object('report_id', p_report_id, 'final_status', p_new_status, 'action', p_action)
  );

  return 'ok';
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_review_report(uuid,text,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_review_report(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_review_report(uuid,text,text,text) TO service_role;

-- rpc_shadow_hide(text,uuid,text,timestamp with time zone)
CREATE OR REPLACE FUNCTION public.rpc_shadow_hide(p_table text, p_id uuid, p_reason text DEFAULT NULL::text, p_expires timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  insert into public.content_enforcement(target_table, target_id, action, active, reason, created_by, expires_at)
  values (p_table, p_id, 'shadow_hide', true, p_reason, v_actor, p_expires)
  on conflict do nothing;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, reason)
  values (v_actor, 'shadow_hide', p_table, p_id, p_reason);
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_shadow_hide(text,uuid,text,timestamp with time zone) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_shadow_hide(text,uuid,text,timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_shadow_hide(text,uuid,text,timestamp with time zone) TO service_role;

-- rpc_shadow_unhide(text,uuid,text)
CREATE OR REPLACE FUNCTION public.rpc_shadow_unhide(p_table text, p_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  update public.content_enforcement
     set active = false,
         expires_at = now()
   where target_table = p_table
     and target_id    = p_id
     and action       = 'shadow_hide'
     and active       = true;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, reason)
  values (v_actor, 'shadow_unhide', p_table, p_id, p_reason);
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_shadow_unhide(text,uuid,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_shadow_unhide(text,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_shadow_unhide(text,uuid,text) TO service_role;

-- rpc_squad_create(uuid,text,text,text,text,text,integer,uuid)
CREATE OR REPLACE FUNCTION public.rpc_squad_create(p_created_by_profile_id uuid, p_sport text, p_name text, p_bio text DEFAULT NULL::text, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'request'::text, p_max_members integer DEFAULT NULL::integer, p_captain_user_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE pr record; sid uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  SELECT id, user_id, profile_type INTO pr
  FROM public.profiles WHERE id = p_created_by_profile_id;

  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='profile_not_found'; END IF;
  IF pr.user_id <> auth.uid() THEN RAISE EXCEPTION USING errcode='P0001', message='not_profile_owner'; END IF;

  IF pr.profile_type = 'player' THEN
    IF EXISTS (SELECT 1 FROM public.squads WHERE founder_user_id = auth.uid()) THEN
      RAISE EXCEPTION USING errcode='P0001', message='founder_limit_reached';
    END IF;

    INSERT INTO public.squads(
      sport,name,bio,created_by_user_id,created_by_profile_id,created_by_role,founder_user_id,
      listing_visibility,join_policy,max_members,city
    ) VALUES (
      p_sport, p_name, p_bio, auth.uid(), p_created_by_profile_id, 'player', auth.uid(),
      p_listing_visibility, p_join_policy, p_max_members, 'Dubai'
    ) RETURNING id INTO sid;

    INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
    VALUES (sid, auth.uid(), p_created_by_profile_id, 'captain','active');

  ELSIF pr.profile_type = 'organiser' THEN
    IF p_captain_user_id IS NULL THEN
      RAISE EXCEPTION USING errcode='P0001', message='captain_required';
    END IF;

    INSERT INTO public.squads(
      sport,name,bio,created_by_user_id,created_by_profile_id,created_by_role,founder_user_id,
      listing_visibility,join_policy,max_members,city
    ) VALUES (
      p_sport, p_name, p_bio, auth.uid(), p_created_by_profile_id, 'organiser', NULL,
      p_listing_visibility, p_join_policy, p_max_members, 'Dubai'
    ) RETURNING id INTO sid;

    IF NOT EXISTS (
      SELECT 1 FROM public.profiles px
      WHERE px.user_id = p_captain_user_id
        AND px.profile_type = 'player'
        AND public._profile_matches_sport(px.id, p_sport)
    ) THEN
      RAISE EXCEPTION USING errcode='P0001', message='captain_must_be_player';
    END IF;

    INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
    SELECT sid, px.user_id, px.id, 'captain','active'
    FROM public.profiles px
    WHERE px.user_id = p_captain_user_id
      AND px.profile_type='player'
      AND public._profile_matches_sport(px.id, p_sport)
    LIMIT 1;

  ELSE
    RAISE EXCEPTION USING errcode='P0001', message='invalid_creator_role';
  END IF;

  PERFORM public.emit_event('squad.created','squad', sid, auth.uid(),
    jsonb_build_object('sport',p_sport,'name',p_name));
  RETURN sid;
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_squad_create(uuid,text,text,text,text,text,integer,uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_squad_create(uuid,text,text,text,text,text,integer,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_squad_create(uuid,text,text,text,text,text,integer,uuid) TO service_role;

-- rpc_takedown(text,uuid,text)
CREATE OR REPLACE FUNCTION public.rpc_takedown(p_table text, p_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  insert into public.content_enforcement(target_table, target_id, action, active, reason, created_by)
  values (p_table, p_id, 'takedown', true, p_reason, v_actor)
  on conflict do nothing;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, reason)
  values (v_actor, 'takedown', p_table, p_id, p_reason);
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_takedown(text,uuid,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_takedown(text,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_takedown(text,uuid,text) TO service_role;

-- rpc_toggle_like(uuid)
CREATE OR REPLACE FUNCTION public.rpc_toggle_like(p_post_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  if exists (select 1 from public.post_likes where post_id=p_post_id and user_id=auth.uid()) then
    delete from public.post_likes where post_id=p_post_id and user_id=auth.uid();
    return 'unliked';
  else
    insert into public.post_likes(post_id, user_id) values (p_post_id, auth.uid());
    return 'liked';
  end if;
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_toggle_like(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_toggle_like(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_toggle_like(uuid) TO service_role;

-- send_vibe_request(uuid)
CREATE OR REPLACE FUNCTION public.send_vibe_request(p_to_user uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  a uuid; b uuid; existing record;
begin
  if me is null then raise exception using errcode='P0001', message='auth_required'; end if;
  if p_to_user = me then raise exception using errcode='P0001', message='cannot_vibe_self'; end if;

  select a,b into a,b from public._pair(me, p_to_user);

  -- Upsert edge
  select * into existing from public.friend_edges
   where least(user_a,user_b)=a and greatest(user_a,user_b)=b;

  if existing is null then
    insert into public.friend_edges(user_a,user_b,status,requested_by,responded_by)
    values (a,b,'pending',me,null);
  else
    -- If already accepted → noop; if pending and I am not the requester → noop (await response)
    if existing.status = 'accepted' then
      return 'already_synced';
    elsif existing.status = 'pending' then
      return case when existing.requested_by = me then 'already_requested' else 'awaiting_response' end;
    else
      -- rejected/removed → reopen as pending
      update public.friend_edges
      set status='pending', requested_by=me, responded_by=null, updated_at=now()
      where id=existing.id;
    end if;
  end if;

  insert into public.friend_requests_audit(from_user,to_user,action,edge_id)
  values (me, p_to_user, 'requested',
          (select id from public.friend_edges where least(user_a,user_b)=a and greatest(user_a,user_b)=b));

  -- TODO: enqueue notification: friend.requested
  return 'ok';
end;
$function$;
REVOKE ALL ON FUNCTION public.send_vibe_request(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_vibe_request(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_vibe_request(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.send_vibe_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_vibe_request(uuid) TO service_role;

-- toggle_venue_favorite_legacy_v1(uuid,uuid)
CREATE OR REPLACE FUNCTION public.toggle_venue_favorite_legacy_v1(venue_id uuid, user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if $2 <> auth.uid() then
    raise exception 'Unauthorized';
  end if;

  if exists (
    select 1
    from public.venue_favorites vf
    where vf.venue_id = $1
      and vf.user_id = $2
  ) then
    delete from public.venue_favorites vf
    where vf.venue_id = $1
      and vf.user_id = $2;
  else
    -- Insert without ON CONFLICT targets (avoids user_id ambiguity)
    insert into public.venue_favorites
    select gen_random_uuid(), $2, $1, now()
    where not exists (
      select 1
      from public.venue_favorites vf
      where vf.venue_id = $1
        and vf.user_id = $2
    );
  end if;
end;
$function$;
REVOKE ALL ON FUNCTION public.toggle_venue_favorite_legacy_v1(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.toggle_venue_favorite_legacy_v1(uuid,uuid) TO service_role;

-- toggle_venue_favorite_legacy_v1(uuid)
CREATE OR REPLACE FUNCTION public.toggle_venue_favorite_legacy_v1(venue_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  perform public.toggle_venue_favorite($1, auth.uid());
end;
$function$;
REVOKE ALL ON FUNCTION public.toggle_venue_favorite_legacy_v1(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.toggle_venue_favorite_legacy_v1(uuid) TO service_role;

-- trg_scan_post()
CREATE OR REPLACE FUNCTION public.trg_scan_post()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare r record; v_lang text;
begin
  v_lang := to_jsonb(new)->>'lang'; -- safe even if there's no 'lang' column
  for r in select * from public._scan_text_against_banlist('post', coalesce(new.body,''), v_lang) loop
    perform public._auto_flag_and_ticket(
      'post', new.id, r.term, r.severity,
      jsonb_build_object('kind',new.kind,'author_user_id',new.author_user_id)
    );
    exit;
  end loop;
  return new;
end; $function$;
REVOKE ALL ON FUNCTION public.trg_scan_post() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trg_scan_post() TO service_role;


-- squad join RPCs, pre-rename error text
CREATE OR REPLACE FUNCTION public.rpc_squad_respond_invite(p_invite_id uuid, p_action text, p_profile_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE inv record; sp text; members int; maxm int;
BEGIN
  SELECT * INTO inv FROM public.squad_invites WHERE id=p_invite_id AND to_user_id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invite_not_found'; END IF;

  SELECT sport, max_members INTO sp, maxm FROM public.squads WHERE id=inv.squad_id;

  IF p_action = 'decline' THEN
    UPDATE public.squad_invites SET status='declined' WHERE id=p_invite_id AND status='pending';
    RETURN 'declined';

  ELSIF p_action = 'accept' THEN
    -- KAN-1041: the profile must belong to the caller (as in rpc_squad_request_join), then live helpers.
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
      RAISE EXCEPTION USING errcode='42501', message='profile_not_owned';
    END IF;
    IF NOT public.actor_is_player(p_profile_id) THEN
      RAISE EXCEPTION USING errcode='P0001', message='profile_not_player_for_sport';
    END IF;

    IF public.is_frozen(auth.uid()) OR public.is_benched(auth.uid()) THEN
      RAISE EXCEPTION USING errcode='P0001', message='benched_or_frozen';
    END IF;

    IF maxm IS NOT NULL THEN
      SELECT COUNT(*) INTO members FROM public.squad_members WHERE squad_id=inv.squad_id AND status='active';
      IF members >= maxm THEN RAISE EXCEPTION USING errcode='P0001', message='squad_full'; END IF;
    END IF;

    INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
    VALUES (inv.squad_id, auth.uid(), p_profile_id, 'member','active')
    ON CONFLICT (squad_id, profile_id) DO UPDATE  -- KAN-1041: the live key is (squad_id, profile_id)
      SET status='active', user_id=EXCLUDED.user_id, left_at=NULL;

    UPDATE public.squad_invites SET status='accepted' WHERE id=p_invite_id AND status='pending';

    PERFORM public.emit_event('squad.member_joined','squad', inv.squad_id, auth.uid(), jsonb_build_object('via','invite'));
    RETURN 'accepted';

  ELSE
    RAISE EXCEPTION USING errcode='P0001', message='invalid_action';
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_squad_request_join(p_squad_id uuid, p_profile_id uuid, p_message text DEFAULT NULL::text, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE s record; members int;
BEGIN
  -- KAN-1038: the profile must belong to the caller.
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION USING errcode='42501', message='profile_not_owned';
  END IF;

  SELECT id, sport, join_policy, max_members INTO s
  FROM public.squads WHERE id=p_squad_id AND is_active=true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='squad_not_found'; END IF;

  -- KAN-1041: live equivalents of the never-created helpers (same checks as can_join_squad / game join).
  IF NOT public.actor_is_player(p_profile_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='profile_not_player_for_sport';
  END IF;
  IF public.is_frozen(auth.uid()) OR public.is_benched(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='benched_or_frozen';
  END IF;

  IF s.max_members IS NOT NULL THEN
    SELECT COUNT(*) INTO members FROM public.squad_members WHERE squad_id=s.id AND status='active';
    IF members >= s.max_members THEN RAISE EXCEPTION USING errcode='P0001', message='squad_full'; END IF;
  END IF;

  CASE s.join_policy
    WHEN 'open' THEN
      INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
      VALUES (s.id, auth.uid(), p_profile_id, 'member','active')
      ON CONFLICT (squad_id, profile_id) DO UPDATE  -- KAN-1041: the live key is (squad_id, profile_id)
        SET status='active', user_id=EXCLUDED.user_id, left_at=NULL;

      PERFORM public.emit_event('squad.member_joined','squad', s.id, auth.uid(), jsonb_build_object('via','open'));
      RETURN 'joined';

    WHEN 'request' THEN
      INSERT INTO public.squad_join_requests(squad_id,user_id,profile_id,status,message)
      VALUES (s.id, auth.uid(), p_profile_id, 'pending', LEFT(p_message,300))
      ON CONFLICT DO NOTHING;

      PERFORM public.emit_event('squad.join_requested','squad', s.id, auth.uid(), '{}');
      RETURN 'pending';

    WHEN 'invite' THEN
      RAISE EXCEPTION USING errcode='P0001', message='invite_only';

    WHEN 'closed' THEN
      RAISE EXCEPTION USING errcode='P0001', message='closed';

    WHEN 'link' THEN
      IF p_link_token IS NULL OR NOT public._squad_link_valid(s.id, p_link_token) THEN
        RAISE EXCEPTION USING errcode='P0001', message='link_required';
      END IF;
      PERFORM public._squad_link_consume(s.id, p_link_token);

      INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
      VALUES (s.id, auth.uid(), p_profile_id, 'member','active')
      ON CONFLICT (squad_id, profile_id) DO UPDATE  -- KAN-1041: the live key is (squad_id, profile_id)
        SET status='active', user_id=EXCLUDED.user_id, left_at=NULL;

      PERFORM public.emit_event('squad.member_joined','squad', s.id, auth.uid(), jsonb_build_object('via','link'));
      RETURN 'joined';

    ELSE
      RAISE EXCEPTION USING errcode='P0001', message='unknown_policy';
  END CASE;
END;
$function$
;

-- plpgsql_check is left installed (harmless); DROP EXTENSION plpgsql_check; if wanted.
COMMIT;
