-- KAN-1053: live functions that referenced missing tables, columns or functions (found by plpgsql_check in KAN-1044).
-- Rollback: supabase/rollbacks/20261127120000_kan1053_broken_functions_rollback.sql
-- Caller check (2026-11-27): grep lib/ + supabase/functions (no hits), pg_depend, pg_trigger, cron.job (none),
-- function bodies (prosrc), pg_stat_statements, and 7 days of edge_logs /rest/v1/rpc paths (no hits for any of these).
-- Callers found: trgfn_payment_to_ledger + trgfn_set_venue_space_sport_id (triggers), rpc_admin_approve_venue_submission
-- (service_role in pg_stat_statements), admin_force_delete_auth_user + compute_*_fingerprint (postgres in pg_stat_statements),
-- award_* (run_badge_engine), generate_space_slot_grid (generate_slot_grid_range), quote_space_slot_price (list_space_slots),
-- list_challenge_statuses (pick_challenge_status). Admin/moderation RPCs are fixed by rule. Signatures, SECURITY mode,
-- search_path and grants are unchanged (CREATE OR REPLACE keeps the ACL).
-- Dropped (no caller anywhere, and built on tables/columns that no longer exist): rpc_feed_ranked, _vibes_momentum_nudge, _post_vibes_json, respond_vibe_request, unsync, rpc_profile_update_basic, rpc_autocomplete_people, search_venues_with_filters.
BEGIN;

-- render_notification
CREATE OR REPLACE FUNCTION public.render_notification(p_type_key text, p_user uuid, p_context jsonb)
 RETURNS TABLE(title text, body text, action_route text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  loc text := coalesce((select locale from public.user_settings where user_id=p_user),'en');
  tt text; bt text; aroute text;
  k text; v text;
begin
  -- KAN-1053: notification_templates is gone; templates live on notification_kinds
  -- (title/body per en/ar, route_template). Unknown locale falls back to en.
  select case when loc like 'ar%' then coalesce(nk.title_template_ar, nk.title_template_en) else nk.title_template_en end,
         case when loc like 'ar%' then coalesce(nk.body_template_ar,  nk.body_template_en)  else nk.body_template_en  end,
         nk.route_template
  into tt, bt, aroute
  from public.notification_kinds nk
  where nk.key = p_type_key;

  title := coalesce(tt,'Notification');
  body  := coalesce(bt,'You have an update');
  action_route := coalesce(aroute,'/inbox');

  -- Replace {{key}} and {key} tokens with context values.
  for k, v in
    select e.key, e.value from jsonb_each_text(coalesce(p_context,'{}'::jsonb)) e
  loop
    title := replace(replace(title, '{{'||k||'}}', v), '{'||k||'}', v);
    body  := replace(replace(body,  '{{'||k||'}}', v), '{'||k||'}', v);
    action_route := replace(replace(action_route, '{{'||k||'}}', v), '{'||k||'}', v);
  end loop;

  return next;
end;
$function$;
-- rpc_admin_approve_venue_submission
CREATE OR REPLACE FUNCTION public.rpc_admin_approve_venue_submission(p_submission_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
DECLARE
  v_submission public.venue_submissions%rowtype;
  v_admin_user_id uuid;
  v_venue_id uuid;
  v_area_id uuid;
  v_geo_id uuid;
BEGIN
  -- 1️⃣ Resolve admin identity from JWT
  v_admin_user_id :=
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid;

  IF v_admin_user_id IS NULL THEN
    RAISE EXCEPTION 'Missing auth context';
  END IF;

  IF NOT public.is_admin(v_admin_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- 2️⃣ Lock submission
  SELECT *
  INTO v_submission
  FROM public.venue_submissions
  WHERE id = p_submission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Submission not found';
  END IF;

  IF v_submission.status <> 'pending' THEN
    RAISE EXCEPTION
      'Submission is not pending (current: %)',
      v_submission.status;
  END IF;

  -- 3. Create venue (KAN-1053: against the live venues columns).
  -- venues needs area_id and geo_location_id (NOT NULL): area = nearest area to the
  -- submitted point, geo_location created the way trg_fn_venues_set_geo does.
  -- venues has no city/district/address_line1/is_indoor/surface_type: address_line1
  -- goes to address_en; city/district/is_indoor/surface_type stay on the submission.
  IF v_submission.lat IS NULL OR v_submission.lng IS NULL THEN
    RAISE EXCEPTION 'Submission has no location (lat/lng)';
  END IF;

  SELECT a.id INTO v_area_id
  FROM public.resolve_nearest_area(v_submission.lat, v_submission.lng) a
  LIMIT 1;
  IF v_area_id IS NULL THEN
    RAISE EXCEPTION 'No area found for submission location';
  END IF;

  INSERT INTO public.geo_locations (location, area_id, geohash)
  VALUES (
    public.ST_SetSRID(public.ST_MakePoint(v_submission.lng, v_submission.lat), 4326)::public.geography,
    v_area_id,
    encode(sha256((v_submission.lat::text || ',' || v_submission.lng::text)::bytea), 'hex')
  )
  RETURNING id INTO v_geo_id;

  INSERT INTO public.venues (
    owner_user_id,
    name_en,
    name_ar,
    description_en,
    description_ar,
    area,
    address_en,
    lat,
    lng,
    phone,
    website,
    instagram,
    amenities,
    sports,
    area_id,
    geo_location_id,
    is_active,
    is_verified
  )
  VALUES (
    v_submission.submitted_by_user_id,
    v_submission.name_en,
    v_submission.name_ar,
    v_submission.description_en,
    v_submission.description_ar,
    v_submission.area,
    v_submission.address_line1,
    v_submission.lat,
    v_submission.lng,
    v_submission.phone,
    v_submission.website,
    v_submission.instagram,
    COALESCE(v_submission.amenities, '{}'::text[]),
    -- 4. Sports: venue_sports no longer exists; venues.sports holds sport keys.
    (SELECT array_agg(s.sport_key ORDER BY s.sport_key)
       FROM public.venue_submission_sports vss
       JOIN public.sports s ON s.id = vss.sport_id
      WHERE vss.venue_submission_id = p_submission_id),
    v_area_id,
    v_geo_id,
    true,
    false
  )
  RETURNING id INTO v_venue_id;

  -- 5. Finalize submission
  UPDATE public.venue_submissions
  SET
    status = 'approved',
    approved_venue_id = v_venue_id,
    approved_at = now(),
    approved_by = v_admin_user_id,
    reviewed_at = now(),
    reviewed_by = v_admin_user_id,
    updated_at = now()
  WHERE id = p_submission_id;

  RETURN v_venue_id;
END;
$function$;
-- rpc_admin_freeze_user
CREATE OR REPLACE FUNCTION public.rpc_admin_freeze_user(p_user_id uuid, p_scope text DEFAULT 'all'::text, p_days integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare until_ts timestamptz;
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  until_ts := case when p_days is null then null else now() + (p_days||' days')::interval end;
  -- KAN-1053: user_freezes has no id; its key is user_id, which is what is returned
  -- (and what rpc_admin_unfreeze_user takes as p_freeze_id).
  insert into public.user_freezes(user_id,scope,reason,created_by,until,is_active,is_frozen)
  values (p_user_id, p_scope, left(coalesce(p_reason,'admin freeze'),280), auth.uid(), until_ts, true, true)
  on conflict (user_id) do update
    set scope = excluded.scope, reason = excluded.reason, created_by = excluded.created_by,
        until = excluded.until, is_active = true, is_frozen = true, frozen_at = now(), lifted_at = null;
  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, target_user_id, reason, expires_at, meta)
  values (auth.uid(), 'freeze', 'user', p_user_id, p_user_id, p_reason, until_ts, jsonb_build_object('action_type','admin_freeze_user','scope',p_scope));
  return p_user_id;
end;
$function$;
-- rpc_admin_hide_post
CREATE OR REPLACE FUNCTION public.rpc_admin_hide_post(p_post_id uuid, p_hide boolean, p_notes text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  update public.posts set is_hidden_admin = coalesce(p_hide,true) where id=p_post_id;
  insert into public.moderation_actions(target_type,target_id,target_user_id,action,actor_user_id,reason,meta)
  values ('post', p_post_id, (select author_user_id from public.posts where id=p_post_id),
          case when coalesce(p_hide,true) then 'takedown'::public.mod_action else 'restore'::public.mod_action end,
          auth.uid(), left(p_notes,280),
          jsonb_build_object('action_type', case when coalesce(p_hide,true) then 'hide' else 'unhide' end));
  return case when coalesce(p_hide,true) then 'hidden' else 'unhidden' end;
end;
$function$;
-- rpc_admin_unfreeze_user
CREATE OR REPLACE FUNCTION public.rpc_admin_unfreeze_user(p_freeze_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  -- KAN-1053: the freeze id is the user_id (user_freezes PK).
  update public.user_freezes set is_active=false, is_frozen=false, lifted_at=now() where user_id=p_freeze_id;
  if not found then return 'not_found'; end if;
  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, target_user_id, meta)
  values (auth.uid(), 'unfreeze', 'user', p_freeze_id, p_freeze_id, jsonb_build_object('action_type','admin_unfreeze_user'));
  return 'unfrozen';
end;
$function$;
-- rpc_ban_display_name
CREATE OR REPLACE FUNCTION public.rpc_ban_display_name(p_display_name text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  dn      text;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  dn := public.normalize_display_name(p_display_name);

  insert into public.display_name_banned(pattern, reason)
  values (dn, coalesce(p_reason,'moderation_ban'))
  on conflict (pattern) do nothing;

  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, reason, meta)
  values (v_actor, 'ban', 'other', gen_random_uuid(), p_reason, jsonb_build_object('action_type','ban_display_name','display_name_norm', dn));
end;
$function$;
-- rpc_ban_username
CREATE OR REPLACE FUNCTION public.rpc_ban_username(p_username text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  norm    text;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  norm := public.normalize_username(p_username);

  insert into public.username_banned(username, reason, created_at)
  values (norm, coalesce(p_reason,'moderation_ban'), now())
  on conflict (username) do nothing;

  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, reason, meta)
  values (v_actor, 'ban', 'other', gen_random_uuid(), p_reason, jsonb_build_object('action_type','ban_username','username', norm));
end;
$function$;
-- rpc_delete_post
CREATE OR REPLACE FUNCTION public.rpc_delete_post(p_post_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  p public.posts%rowtype;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;
  select * into p from public.posts where id=p_post_id;
  if not found then raise exception using errcode='P0001', message='not_found'; end if;

  if p.author_user_id <> auth.uid() and not public.is_admin(auth.uid()) then
    raise exception using errcode='P0001', message='forbidden';
  end if;

  update public.posts set is_deleted = true where id=p_post_id;
  insert into public.moderation_actions(target_type,target_id,target_user_id,action,actor_user_id,reason,meta)
  values ('post', p_post_id, p.author_user_id, 'takedown', auth.uid(), 'soft-delete', jsonb_build_object('action_type','delete'));
  return 'deleted';
end;
$function$;
-- rpc_freeze_user
CREATE OR REPLACE FUNCTION public.rpc_freeze_user(p_user_id uuid, p_reason text DEFAULT NULL::text, p_until timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
begin
  if v_actor is null then
    raise exception using errcode='P0001', message='not_authenticated';
  end if;

  if not public.is_admin(v_actor) then
    raise exception using errcode='P0001', message='not_admin';
  end if;

  insert into public.user_freezes(user_id, is_frozen, reason, until, created_by, is_active)
  values (p_user_id, true, p_reason, p_until, v_actor, true)
  on conflict (user_id) do update
    set is_frozen = true,
        is_active = true,
        reason    = excluded.reason,
        until     = excluded.until,
        frozen_at = now(),
        lifted_at = null;

  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, target_user_id, reason, expires_at, meta)
  values (v_actor, 'freeze', 'user', p_user_id, p_user_id, p_reason, p_until, jsonb_build_object('action_type','freeze_user'));
end;
$function$;
-- rpc_moderation_resolve_ticket
CREATE OR REPLACE FUNCTION public.rpc_moderation_resolve_ticket(p_ticket_id uuid, p_action text, p_notes text DEFAULT NULL::text, p_freeze_scope text DEFAULT NULL::text, p_freeze_days integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t public.moderation_tickets%rowtype;
        target_user uuid;
        until_ts timestamptz;
        v_action public.mod_action;
        v_target public.mod_target;
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  select * into t from public.moderation_tickets where id=p_ticket_id;
  if not found then raise exception using errcode='P0001', message='ticket_not_found'; end if;

  -- KAN-1053: post_comments is now public.comments.
  if t.target_kind='post' then
    if p_action='hide' then update public.posts set is_hidden_admin=true where id=t.target_id;
    elsif p_action='unhide' then update public.posts set is_hidden_admin=false where id=t.target_id;
    elsif p_action='delete' then update public.posts set is_deleted=true where id=t.target_id;
    end if;
    select author_user_id into target_user from public.posts where id=t.target_id;
  elsif t.target_kind='comment' then
    if p_action='hide' then update public.comments set is_hidden_admin=true where id=t.target_id;
    elsif p_action='unhide' then update public.comments set is_hidden_admin=false where id=t.target_id;
    elsif p_action='delete' then update public.comments set is_deleted=true where id=t.target_id;
    end if;
    select author_user_id into target_user from public.comments where id=t.target_id;
  end if;

  if p_action='freeze' then
    if target_user is null then raise exception using errcode='P0001', message='target_user_not_found'; end if;
    until_ts := case when p_freeze_days is null then null else now() + (p_freeze_days||' days')::interval end;
    -- user_freezes is one row per user (PK user_id): upsert instead of a second insert.
    insert into public.user_freezes(user_id, scope, reason, created_by, until, is_active, is_frozen)
    values (target_user, coalesce(p_freeze_scope,'all'), left(coalesce(p_notes,'moderation freeze'),280), auth.uid(), until_ts, true, true)
    on conflict (user_id) do update
      set scope = excluded.scope, reason = excluded.reason, created_by = excluded.created_by,
          until = excluded.until, is_active = true, is_frozen = true, frozen_at = now(), lifted_at = null;
  end if;

  update public.moderation_tickets set status =
    case when p_action='dismiss' then 'dismissed' else 'resolved' end,
    updated_at = now()
  where id = p_ticket_id;

  v_action := case p_action when 'hide' then 'takedown' when 'delete' then 'takedown'
                            when 'unhide' then 'restore' when 'freeze' then 'freeze' end;
  v_target := case when t.target_kind in ('user','profile','post','comment','game','squad','venue','message','meetup')
                   then t.target_kind::public.mod_target else 'other' end;
  -- 'dismiss' (and any action mod_action cannot express) is recorded on the ticket only.
  if v_action is not null then
    insert into public.moderation_actions(target_type,target_id,target_user_id,action,actor_user_id,reason,expires_at,meta)
    values (v_target, t.target_id, target_user, v_action, auth.uid(), left(p_notes, 500), until_ts,
            jsonb_build_object('action_type', p_action, 'ticket_id', p_ticket_id));
  end if;

  return 'resolved';
end;
$function$;
-- rpc_unfreeze_user
CREATE OR REPLACE FUNCTION public.rpc_unfreeze_user(p_user_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
begin
  if v_actor is null then
    raise exception using errcode='P0001', message='not_authenticated';
  end if;
  if not public.is_admin(v_actor) then
    raise exception using errcode='P0001', message='not_admin';
  end if;

  update public.user_freezes
     set is_frozen = false,
         is_active = false,
         lifted_at = now(),
         reason    = coalesce(p_reason, reason)
   where user_id = p_user_id;

  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, target_user_id, reason, meta)
  values (v_actor, 'unfreeze', 'user', p_user_id, p_user_id, p_reason, jsonb_build_object('action_type','unfreeze_user'));
end;
$function$;
-- rpc_unverify_profile
CREATE OR REPLACE FUNCTION public.rpc_unverify_profile(p_profile_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  uid     uuid;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  insert into public.profile_verifications(profile_id, verified, verified_at, verified_by, reason)
  values (p_profile_id, false, now(), v_actor, p_reason)
  on conflict (profile_id) do update
    set verified    = false,
        verified_at = now(),
        verified_by = v_actor,
        reason      = coalesce(p_reason, public.profile_verifications.reason);

  select user_id into uid from public.profiles where id = p_profile_id;

  -- mod_action has no verify value: 'restrict' plus meta.action_type keeps the audit row.
  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, target_user_id, reason, meta)
  values (v_actor, 'restrict', 'profile', p_profile_id, uid, p_reason, jsonb_build_object('action_type','unverify_profile'));
end;
$function$;
-- rpc_verify_profile
CREATE OR REPLACE FUNCTION public.rpc_verify_profile(p_profile_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  uid     uuid;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  insert into public.profile_verifications(profile_id, verified, verified_at, verified_by, reason)
  values (p_profile_id, true, now(), v_actor, p_reason)
  on conflict (profile_id) do update
    set verified    = true,
        verified_at = now(),
        verified_by = v_actor,
        reason      = coalesce(p_reason, public.profile_verifications.reason);

  select user_id into uid from public.profiles where id = p_profile_id;

  -- mod_action has no verify value: 'restore' plus meta.action_type keeps the audit row.
  insert into public.moderation_actions(actor_user_id, action, target_type, target_id, target_user_id, reason, meta)
  values (v_actor, 'restore', 'profile', p_profile_id, uid, p_reason, jsonb_build_object('action_type','verify_profile'));
end;
$function$;
-- trgfn_payment_to_ledger
CREATE OR REPLACE FUNCTION public.trgfn_payment_to_ledger()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_platform_pct numeric;
  v_platform_fee numeric;
  v_venue_amount numeric;

  v_user_wallet uuid;
  v_platform_wallet uuid;
  v_venue_wallet uuid;

  v_venue_id uuid;
BEGIN
  -- Only fire on success
  IF NEW.status <> 'succeeded' THEN
    RETURN NEW;
  END IF;

  -- Prevent double processing
  -- KAN-128 / T-049 Invariant 4: this EXISTS check is a read-then-write with no
  -- lock. It is NOT idempotency and is no longer the only thing between a
  -- webhook and a double credit -- financial_ledger_payment_entry_unique is. It
  -- stays as a cheap early return that avoids an error round-trip.
  IF EXISTS (
    SELECT 1
    FROM public.financial_ledger
    WHERE payment_intent_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  -- Get booking venue
  -- KAN-140 / T-061: two-hop join through venue_bookings -> venue_spaces.
  -- Both venue_bookings.venue_space_id and venue_spaces.venue_id are NOT NULL
  -- with FKs enforcing referential integrity, so given a venue_bookings row
  -- venue_id cannot be NULL -- no NULL-handling branch is written. INTO
  -- STRICT asserts (does not establish) that booking_id resolves to exactly
  -- one row, a guarantee KAN-145's payment_intents_booking_id_fkey holds.
  SELECT vs.venue_id
  INTO STRICT v_venue_id
  FROM public.venue_bookings vb
  JOIN public.venue_spaces vs ON vs.id = vb.venue_space_id
  WHERE vb.id = NEW.booking_id;

  -- Get commission
  -- KAN-1053: commission_rules has no percentage/applies_to. The platform rate is
  -- commission_rate (a percent, CHECK 0..100) of the global default rule
  -- (organiser_user_id IS NULL AND sport IS NULL), resolved by the canonical
  -- resolve_commission(): active, inside starts_at/ends_at, newest first.
  -- No rule -> raise: never post a split with a NULL or invented fee.
  SELECT rc.rate
  INTO v_platform_pct
  FROM public.resolve_commission(NULL::uuid, NULL::text, now()) rc;

  IF v_platform_pct IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'commission_rule_missing',
      detail = 'no active global commission_rules row; ledger split not posted';
  END IF;

  v_platform_fee := round(NEW.amount * (v_platform_pct / 100), 2);
  v_venue_amount := NEW.amount - v_platform_fee;

  -- Resolve wallets
  v_user_wallet := fn_get_wallet('user', NEW.user_id, NEW.currency);
  v_platform_wallet := fn_get_wallet('platform', fn_platform_owner_id(), NEW.currency);
  v_venue_wallet := fn_get_wallet('venue', v_venue_id, NEW.currency);

  -- USER pays
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'user', NEW.user_id, v_user_wallet,
    NEW.booking_id, NEW.id,
    'debit', NEW.amount, NEW.currency, 'booking_payment'
  )
  ON CONFLICT DO NOTHING;

  -- PLATFORM commission
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'platform', fn_platform_owner_id(), v_platform_wallet,
    NEW.booking_id, NEW.id,
    'credit', v_platform_fee, NEW.currency, 'commission'
  )
  ON CONFLICT DO NOTHING;

  -- VENUE revenue
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'venue', v_venue_id, v_venue_wallet,
    NEW.booking_id, NEW.id,
    'credit', v_venue_amount, NEW.currency, 'booking_payment'
  )
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$function$;
-- trgfn_set_venue_space_sport_id
CREATE OR REPLACE FUNCTION public.trgfn_set_venue_space_sport_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- KAN-1053: venue_spaces has no legacy text "sport" column any more and
  -- sport_id is NOT NULL, so there is nothing to derive. Kept as a pass-through
  -- so trg_set_venue_space_sport_id stays attached and harmless.
  RETURN new;
END;
$function$;

-- compute_*_fingerprint: pgcrypto lives in schema extensions; qualify digest().
CREATE OR REPLACE FUNCTION public.compute_challenge_fingerprint(p_payload jsonb)
 RETURNS TABLE(hash text, fields jsonb)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  sport text;
  kind text;                 -- 'round_robin'|'knockout'|'ladder'|'league'|...
  squads int;                -- number of squads
  rounds_per_week int;
  default_slot text;         -- preferred slot for fixtures (optional)
  f jsonb;
begin
  sport := lower(coalesce(p_payload->>'sport',''));
  kind  := lower(coalesce(p_payload->>'challenge_type',''));
  squads := coalesce((p_payload->>'squads')::int, 0);
  rounds_per_week := coalesce((p_payload->>'rounds_per_week')::int, 0);
  default_slot := coalesce(p_payload->>'default_slot', null);

  f := jsonb_build_object(
    'sport', sport,
    'challenge_type', kind,
    'squads', squads,
    'rounds_per_week', rounds_per_week,
    'default_slot', default_slot
  );

  hash := encode(extensions.digest(f::text,'sha256'),'hex');
  fields := f;
  return next;
end;
$function$;

CREATE OR REPLACE FUNCTION public.compute_game_fingerprint(p_payload jsonb)
 RETURNS TABLE(hash text, fields jsonb)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  sport text; venue_space uuid; start_at timestamptz; end_at timestamptz;
  capacity int; listing text; joinp text; dur int; slot text; f jsonb;
BEGIN
  sport := lower(COALESCE(p_payload->>'sport', ''));
  venue_space := nullif(p_payload->>'venue_space_id', '')::uuid;
  start_at := (p_payload->>'start_at')::timestamptz;
  end_at := (p_payload->>'end_at')::timestamptz;
  capacity := COALESCE((p_payload->>'capacity')::int, 0);
  listing := COALESCE(p_payload->>'listing_visibility', 'public');
  joinp := COALESCE(p_payload->>'join_policy', 'request');
  dur := GREATEST(30, COALESCE(((extract(epoch from (end_at - start_at)) / 60)::int), 60));
  slot := public._slot_key(start_at, 30);
  f := jsonb_build_object(
    'sport', sport, 'venue_space_id', venue_space,
    'weekday', extract(dow from start_at)::int,
    'slot', slot, 'duration_mins', dur, 'capacity', capacity,
    'listing_visibility', listing, 'join_policy', joinp);
  hash := encode(extensions.digest(COALESCE(f::text, ''), 'sha256'), 'hex');
  fields := f;
  RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.compute_meetup_fingerprint(p_payload jsonb)
 RETURNS TABLE(hash text, fields jsonb)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  cat text; venue_space uuid; start_at timestamptz; end_at timestamptz;
  dur int; slot text; listing text; f jsonb;
BEGIN
  cat := 'social';
  venue_space := nullif(p_payload->>'venue_space_id', '')::uuid;
  start_at := (p_payload->>'start_at')::timestamptz;
  end_at := (p_payload->>'end_at')::timestamptz;
  dur := GREATEST(30, COALESCE(((extract(epoch from (end_at - start_at)) / 60)::int), 60));
  slot := public._slot_key(start_at, 30);
  listing := COALESCE(p_payload->>'listing_visibility', 'public');
  f := jsonb_build_object(
    'category', cat, 'venue_space_id', venue_space,
    'weekday', extract(dow from start_at)::int,
    'slot', slot, 'duration_mins', dur,
    'listing_visibility', listing);
  hash := encode(extensions.digest(f::text, 'sha256'), 'hex');
  fields := f;
  RETURN NEXT;
END;
$function$;

-- award_*: format() has no %.Nf; round in SQL and print with %s.
CREATE OR REPLACE FUNCTION public.award_top_host_weekly(p_badge_key text, p_params jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  top_n      int  := public._param_int(p_params,'top_n',10);
  min_hosted int  := public._param_int(p_params,'min_hosted',2);
  orderby    text := lower(public._param_txt(p_params,'orderby','fill_rate')); -- or 'games_hosted'
  target_isoy int := extract(isoyear from now())::int;
  target_isow int := extract(week    from now())::int;
  n int := 0;
  rec record;
  win_tag text := format('%s-W%02s', target_isoy, target_isow);
begin
  for rec in
    select user_id, games_hosted, fill_rate
    from public.v_host_weekly_metrics
    where isoy = target_isoy and isow = target_isow and games_hosted >= min_hosted
    order by case when orderby='games_hosted' then games_hosted end desc nulls last,
             case when orderby='fill_rate'   then fill_rate   end desc nulls last
    limit greatest(1, top_n)
  loop
    insert into public.user_badges(user_id, badge_key, reason, context)
    values (
      rec.user_id, p_badge_key,
      format('Week %s: hosted %s game(s), fill %s%%', win_tag, rec.games_hosted, round(100*coalesce(rec.fill_rate,0))),
      jsonb_build_object('window', win_tag, 'games_hosted', rec.games_hosted, 'fill_rate', rec.fill_rate)
    )
    on conflict do nothing;
    n := n + 1;
  end loop;
  return n;
end;
$function$;

CREATE OR REPLACE FUNCTION public.award_venue_dim_top(p_badge_key text, p_params jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  dim         text := public._param_txt(p_params,'dimension','lighting');
  v_district  text := public._param_txt(p_params,'district','Al Quoz');  -- renamed to avoid clash
  top_n       int  := public._param_int(p_params,'top_n',3);
  min_count   int  := public._param_int(p_params,'min_count',10);
  n           int := 0;
  rec         record;
  win_tag     text := to_char(current_date, 'YYYY-MM'); -- monthly cycle by default
begin
  for rec in
    select vdbd.venue_id, vdbd.avg_score, vdbd.ratings_count
    from public.v_venue_dimension_by_district vdbd
    where vdbd.dimension_key = dim
      and vdbd.district = v_district
      and vdbd.ratings_count >= min_count
    order by vdbd.avg_score desc, vdbd.ratings_count desc
    limit greatest(1, top_n)
  loop
    insert into public.user_badges(user_id,badge_key,reason,context)
    select vm.user_id, p_badge_key,
           format('%s in %s (avg %s, %s ratings)', initcap(dim), v_district, round(rec.avg_score::numeric,2), rec.ratings_count),
           jsonb_build_object('window', win_tag, 'venue_id', rec.venue_id, 'dimension', dim,
                              'district', v_district, 'avg', rec.avg_score, 'count', rec.ratings_count)
    from public.venue_members vm
    where vm.venue_id = rec.venue_id and vm.role in ('owner','manager')
    on conflict do nothing;

    get diagnostics n = row_count;
  end loop;

  return coalesce(n,0);
end;
$function$;

-- admin_force_delete_auth_user: ROW_COUNT went into a boolean, then compared to 0.
CREATE OR REPLACE FUNCTION public.admin_force_delete_auth_user(p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_user_uuid UUID;
  v_deleted_sessions INTEGER := 0;
  v_deleted_identities INTEGER := 0;
  v_deleted_mfa_factors INTEGER := 0;
  v_deleted_refresh_tokens INTEGER := 0;
  v_deleted_user INTEGER := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin privileges required';
  END IF;

  -- Validate input and convert to UUID
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'User ID cannot be null or empty';
  END IF;

  -- Cast to UUID to ensure type safety
  BEGIN
    v_user_uuid := p_user_id::UUID;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid UUID format: %', p_user_id;
  END;

  -- Delete from auth.sessions
  EXECUTE format('DELETE FROM auth.sessions WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_sessions = ROW_COUNT;

  -- Delete from auth.identities
  EXECUTE format('DELETE FROM auth.identities WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_identities = ROW_COUNT;

  -- Delete from auth.mfa_factors
  EXECUTE format('DELETE FROM auth.mfa_factors WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_mfa_factors = ROW_COUNT;

  -- Delete from auth.refresh_tokens
  EXECUTE format('DELETE FROM auth.refresh_tokens WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_refresh_tokens = ROW_COUNT;

  -- Delete from auth.mfa_amr_claims if exists
  BEGIN
    EXECUTE format('DELETE FROM auth.mfa_amr_claims WHERE session_id IN (SELECT id FROM auth.sessions WHERE user_id::text = %L)', v_user_uuid::text);
  EXCEPTION
    WHEN undefined_table THEN NULL; -- Table might not exist
  END;

  -- Delete from auth.mfa_challenges if exists
  BEGIN
    EXECUTE format('DELETE FROM auth.mfa_challenges WHERE factor_id IN (SELECT id FROM auth.mfa_factors WHERE user_id::text = %L)', v_user_uuid::text);
  EXCEPTION
    WHEN undefined_table THEN NULL; -- Table might not exist
  END;

  -- Finally, delete the user from auth.users
  EXECUTE format('DELETE FROM auth.users WHERE id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_user = ROW_COUNT;

  IF v_deleted_user = 0 THEN
    RAISE EXCEPTION 'User not found in auth.users: %', p_user_id;
  END IF;

  -- Return summary
  RETURN jsonb_build_object(
    'success', TRUE,
    'user_id', v_user_uuid,
    'deleted', jsonb_build_object(
      'sessions', v_deleted_sessions,
      'identities', v_deleted_identities,
      'mfa_factors', v_deleted_mfa_factors,
      'refresh_tokens', v_deleted_refresh_tokens,
      'user', TRUE
    )
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error deleting auth user: %', SQLERRM;
END;
$function$;

-- list_challenge_statuses: pg_enum.enumlabel is name, the function returns text.
CREATE OR REPLACE FUNCTION public.list_challenge_statuses()
 RETURNS SETOF text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  t_oid   oid;
  atttyp  oid;
  def     text;
  vals    text[] := '{}';
begin
  select 'public.challenges'::regclass::oid into t_oid;
  select a.atttypid
  into atttyp
  from pg_attribute a
  where a.attrelid = t_oid and a.attname = 'status' and a.attnum > 0 and not a.attisdropped;

  -- If ENUM: return enum labels
  if atttyp::regtype::text !~* 'text' then
    return query
    select e.enumlabel::text
    from pg_enum e
    where e.enumtypid = atttyp
    order by e.enumsortorder;
    return;
  end if;

  -- Else parse CHECK constraints that mention status
  for def in
    select pg_get_constraintdef(c.oid)
    from pg_constraint c
    where c.conrelid = t_oid
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%status%'
  loop
    vals := vals || (
      select array_agg(m[1])
      from regexp_matches(def, '''([^'']+)''(?:::?[a-zA-Z0-9_.]+)?', 'g') m
    );
  end loop;

  if vals is not null and array_length(vals,1) is not null then
    return query select distinct v::text from unnest(vals) v;
  end if;

  return;
end;
$function$;

-- opening_hours has day_group ('weekdays' = Mon-Thu, 'fri','sat','sun'), not weekday; venue_spaces has no sport
-- (sport_id -> sports.sport_key) and venues has no city (areas.city via area_id).
CREATE OR REPLACE FUNCTION public.quote_space_slot_price(p_space_id uuid, p_start_utc timestamp with time zone, p_end_utc timestamp with time zone)
 RETURNS TABLE(venue_space_id uuid, venue_id uuid, venue_tz text, local_date date, local_weekday integer, local_start timestamp without time zone, local_end timestamp without time zone, minutes integer, is_open boolean, is_blackout boolean, hourly_aed numeric, price_aed numeric, reason text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_tz   text;
  v_vid  uuid;
  v_ls   timestamp;  -- local start (no tz)
  v_le   timestamp;  -- local end (no tz)
  v_wd   int;        -- 0..6
  v_open time;
  v_close time;
  v_rate numeric(10,2);
  v_minutes int;
  v_reason text := null;
  v_is_open boolean := false;
  v_is_blackout boolean := false;
begin
  if p_end_utc <= p_start_utc then
    venue_space_id := p_space_id;
    reason := 'end <= start';
    return next; return;
  end if;

  -- ✅ fixed alias here: s.venue_id (not v.venue_id)
  select s.venue_id, ven.timezone
  into v_vid, v_tz
  from public.venue_spaces s
  join public.venues ven on ven.id = s.venue_id
  where s.id = p_space_id;

  if v_tz is null then
    venue_space_id := p_space_id;
    reason := 'space_or_venue_not_found';
    return next; return;
  end if;

  v_ls := (p_start_utc at time zone v_tz);
  v_le := (p_end_utc   at time zone v_tz);

  if v_ls::date <> v_le::date then
    venue_space_id := p_space_id; venue_id := v_vid; venue_tz := v_tz;
    local_date := v_ls::date; local_weekday := extract(dow from v_ls)::int;
    local_start := v_ls; local_end := v_le; minutes := extract(epoch from (p_end_utc - p_start_utc))::int / 60;
    reason := 'slot_crosses_midnight_local';
    return next; return;
  end if;

  v_wd := extract(dow from v_ls)::int;

  select oh.open_time, oh.close_time
  into v_open, v_close
  from public.opening_hours oh
  where oh.venue_space_id = p_space_id and oh.day_group = (CASE v_wd WHEN 0 THEN 'sun' WHEN 5 THEN 'fri' WHEN 6 THEN 'sat' ELSE 'weekdays' END)
    and oh.is_open is distinct from false and oh.is_closed is distinct from true;

  if v_open is null then
    venue_space_id := p_space_id; venue_id := v_vid; venue_tz := v_tz;
    local_date := v_ls::date; local_weekday := v_wd; local_start := v_ls; local_end := v_le;
    minutes := extract(epoch from (p_end_utc - p_start_utc))::int / 60;
    reason := 'no_opening_hours_for_weekday';
    return next; return;
  end if;

  v_is_open := (v_ls::time >= v_open) and (v_le::time <= v_close);

  select exists (
    select 1
    from public.blackouts b
    where b.venue_space_id = p_space_id
      and b.starts_at < p_end_utc
      and b.ends_at   > p_start_utc
  ) into v_is_blackout;

  select sp.price_per_hour_aed
  into v_rate
  from public.space_prices sp
  where sp.venue_space_id = p_space_id
    and sp.weekday = v_wd
    and sp.is_active = true
    and sp.start_time <= v_ls::time
    and sp.end_time   >= v_le::time
  order by sp.start_time asc
  limit 1;

  v_minutes := (extract(epoch from (p_end_utc - p_start_utc)) / 60)::int;

  if not v_is_open then
    v_reason := 'outside_opening_hours';
  elsif v_is_blackout then
    v_reason := 'blackout';
  elsif v_rate is null then
    v_reason := 'no_price_rule_covers_slot';
  end if;

  venue_space_id := p_space_id;
  venue_id := v_vid;
  venue_tz := v_tz;
  local_date := v_ls::date;
  local_weekday := v_wd;
  local_start := v_ls;
  local_end := v_le;
  minutes := v_minutes;
  is_open := v_is_open;
  is_blackout := v_is_blackout;
  hourly_aed := v_rate;
  price_aed := case when v_rate is not null and v_is_open and not v_is_blackout
                    then round((v_minutes::numeric / 60.0) * v_rate, 2)
                    else null end;
  reason := v_reason;

  return next;
end
$function$;

CREATE OR REPLACE FUNCTION public.generate_space_slot_grid(p_space_id uuid, p_date date, p_granularity_minutes integer DEFAULT 60)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  tz text;
  wd int;
  open_t time; close_t time; open_flag boolean;
  day_start timestamptz; day_end timestamptz;
  cur timestamptz; nxt timestamptz;
  inserted int := 0;
begin
  if p_granularity_minutes not in (30,45,60,90,120) then
    raise exception using errcode='P0001', message='invalid_granularity';
  end if;

  select v.timezone into tz
  from public.venue_spaces s join public.venues v on v.id = s.venue_id
  where s.id = p_space_id;
  if tz is null then tz := 'Asia/Dubai'; end if;

  day_start := (p_date::timestamptz at time zone tz);
  day_end   := ((p_date + 1)::timestamptz at time zone tz);
  wd := extract(dow from day_start at time zone tz);

  select open_time, close_time, is_open
    into open_t, close_t, open_flag
  from public.opening_hours
  where venue_space_id = p_space_id and day_group = (CASE wd WHEN 0 THEN 'sun' WHEN 5 THEN 'fri' WHEN 6 THEN 'sat' ELSE 'weekdays' END);

  delete from public.space_slot_grid
   where venue_space_id = p_space_id
     and slot_date = p_date
     and granularity_minutes = p_granularity_minutes
     and version = 1;

  if open_flag is distinct from true or open_t is null or close_t is null or close_t <= open_t then
    return 0;
  end if;

  cur := (date_trunc('day', day_start at time zone tz) + open_t) at time zone tz;
  nxt := cur + make_interval(mins => p_granularity_minutes);

  while nxt <= (date_trunc('day', day_start at time zone tz) + close_t) at time zone tz loop
    insert into public.space_slot_grid(
      venue_space_id, slot_date, slot_start, slot_end,
      granularity_minutes, base_price_aed, version
    )
    values (
      p_space_id, p_date, cur, nxt,
      p_granularity_minutes,
      public._compute_slot_price_for_window(p_space_id, cur, nxt),
      1
    )
    on conflict do nothing;

    inserted := inserted + 1;
    cur := nxt;
    nxt := cur + make_interval(mins => p_granularity_minutes);
  end loop;

  return inserted;
end;
$function$;

CREATE OR REPLACE FUNCTION public.generate_slot_grid_range(p_from date, p_to date, p_granularity_minutes integer DEFAULT 60, p_sport text DEFAULT NULL::text, p_city text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  rec record;           -- <- record variable
  d   date;
  total int := 0;
begin
  if p_to < p_from then
    raise exception using errcode='P0001', message='invalid_date_range';
  end if;

  for rec in
    select sp.id as space_id
    from public.venue_spaces sp
    join public.venues v on v.id = sp.venue_id
    where sp.is_active = true
      and v.is_active = true
      and (p_sport is null or exists (select 1 from public.sports s where s.id = sp.sport_id and s.sport_key = p_sport))
      and (p_city  is null or exists (select 1 from public.areas a where a.id = v.area_id and a.city = p_city))
  loop
    d := p_from;
    while d <= p_to loop
      total := total + public.generate_space_slot_grid(rec.space_id, d, p_granularity_minutes);
      d := d + 1;
    end loop;
  end loop;

  return total;
end;
$function$;

-- _skill_level/_get_skill_level: sport_profiles is keyed by profile_id; reach the user through profiles.
CREATE OR REPLACE FUNCTION public._skill_level(u uuid, sport text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare lvl int;
begin
  if to_regclass('public.sport_profiles') is null then
    return null;
  end if;

  select sp.skill_level
    into lvl
  from public.sport_profiles sp
  join public.profiles pr on pr.id = sp.profile_id
  where pr.user_id = $1
    and sp.sport = $2
  limit 1;

  return lvl;
end;
$function$;

CREATE OR REPLACE FUNCTION public._get_skill_level(u uuid, sport text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare lvl int;
begin
  if to_regclass('public.sport_profiles') is null then
    return null;
  end if;

  select spm.skill_level
    into lvl
  from public.sport_profiles spm
  join public.profiles pr on pr.id = spm.profile_id
  where pr.user_id = $1
    and spm.sport = $2
  limit 1;

  return lvl;
end;
$function$;

-- rpc_mark_all_read: notifications.to_user_id, not user_id.
CREATE OR REPLACE FUNCTION public.rpc_mark_all_read()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  update public.notifications
  set is_read = true, read_at = now()
  where to_user_id = auth.uid() and is_read = false;
  get diagnostics n = row_count;
  return n;
end;
$function$;

-- admin_fill_posts_sport_key: posts.sport, not sport_key.
CREATE OR REPLACE FUNCTION public.admin_fill_posts_sport_key()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
declare
  v_count  int  := 0;
  v_sample jsonb := '[]'::jsonb;
begin
  with c as (
    select
      id,
      replace(
        lower( (regexp_match(body, '(?i)(Padel Doubles|Indoor Cricket|Football|Cricket|Padel)'))[1] ),
        ' ',
        '_'
      ) as sk
    from public.posts
    where sport is null
      and body is not null
      and body ~* '(Padel Doubles|Indoor Cricket|Football|Cricket|Padel)'
  ),
  u as (
    update public.posts p
       set sport = c.sk
    from c
    where p.id = c.id
      and c.sk is not null
      and c.sk <> ''
    returning p.id, left(p.body, 80) as body_prefix, p.sport as sport_key
  )
  select
    coalesce((select count(*) from u), 0),
    coalesce((
      select jsonb_agg(jsonb_build_object('id', id, 'body_prefix', body_prefix, 'sport_key', sport_key))
      from (select * from u limit 12) s
    ), '[]'::jsonb)
  into v_count, v_sample;

  return jsonb_build_object('rows_updated', v_count, 'sample', v_sample);
end;
$function$;

-- Dead functions.
DROP FUNCTION public.rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer);
DROP FUNCTION public._vibes_momentum_nudge(uuid);
DROP FUNCTION public._post_vibes_json(uuid);
DROP FUNCTION public.respond_vibe_request(uuid,text);
DROP FUNCTION public.unsync(uuid);
DROP FUNCTION public.rpc_profile_update_basic(text,text,text,text,text,text);
DROP FUNCTION public.rpc_autocomplete_people(text,text[],text,integer);
DROP FUNCTION public.search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text);

COMMIT;
