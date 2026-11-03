-- KAN-725 rollback: restores the pre-image of rpc_meetup_card(uuid,text) and
-- rpc_meetup_attendees(uuid,text,integer,integer) after 20261104100600_kan714_b06_rpc_meetup_reads.sql.
-- Bodies below are pg_get_functiondef of the KAN-713 stage catalogue, verbatim (T-058).
-- rpc_meetup_my() was never changed and is not touched.
-- KAN-789 note: rpc_meetup_my() was since RETIRED by KAN-785 (20261104110400). The post-check below still pins its
-- pre-image md5 (historical B06 state), so on a post-KAN-785 catalogue run KAN-785's rollback (its migration header) first.
-- Single transaction; no DROP, no CASCADE, no data mutation, no grant change.
-- CREATE OR REPLACE FUNCTION keeps owner and ACL; asserted below.

BEGIN;

-- Guard: refuse unless the exact KAN-725 post-image is present.
DO $guard$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_meetup_card(uuid,text)',                       '11a9f38356fc23e4430c9353b246eb8f'),
      ('public.rpc_meetup_attendees(uuid,text,integer,integer)',  'bb414558f86659d89497da378babcb7f')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-725 rollback: % is not the KAN-725 post-image (md5 %) — nothing to roll back', r.fn, v;
    END IF;
  END LOOP;
END
$guard$;

CREATE TEMP TABLE kan725_rb_pre ON COMMIT DROP AS
  SELECT p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig FROM pg_proc p
   WHERE p.oid IN ('public.rpc_meetup_card(uuid,text)'::regprocedure,
                   'public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure);

CREATE OR REPLACE FUNCTION public.rpc_meetup_card(p_meetup_id uuid, p_profile_type text DEFAULT 'player'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_host  boolean;
  g int; i int; d int; pn int;
  my_status_ text;
  hp_name text;
  hp_user citext;
  counts_ jsonb;
  hp_avatar text;
  sp public.sports%rowtype;
  v_area text;
  v_venue text;
  atts jsonb := '[]'::jsonb;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, m.creator_user_id, m.listing_visibility, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (m.creator_user_id = me or public.is_admin(me));

  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int,
    (count(*) filter (where r.status = 'pending'))::int
    into g, i, d, pn
  from public.meetup_rsvps r
  where r.meetup_id = p_meetup_id;

  if me is not null then
    select r.status into my_status_
    from public.meetup_rsvps r
    where r.meetup_id = p_meetup_id and r.user_id = me;
  end if;

  select hp.display_name, hp.username, hp.avatar_url into hp_name, hp_user, hp_avatar
  from public.profiles hp where hp.id = m.host_actor_id;

  select * into sp from public.sports s where s.id = m.sport_id;
  select a.name into v_area from public.areas a where a.id = m.area_id;
  select v.name_en into v_venue from public.venues v where v.id = m.venue_id;

  -- member names/avatars: authenticated callers only (the card is anon-callable)
  if me is not null then
    select coalesce(jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name)
                              order by x.updated_at desc nulls last), '[]'::jsonb)
      into atts
    from (select r.profile_id, r.updated_at from public.meetup_rsvps r
          where r.meetup_id = p_meetup_id and r.status = 'going'
          order by r.updated_at desc nulls last, r.created_at desc limit 8) x
    join public.profiles ap on ap.id = x.profile_id;
  end if;

  counts_ := jsonb_build_object(
    'going',      coalesce(g,0),
    'interested', coalesce(i,0),
    'declined',   coalesce(d,0)
  );
  if v_host then
    counts_ := counts_ || jsonb_build_object('pending', coalesce(pn,0));
  end if;

  return jsonb_build_object(
    'id',               m.id,
    'title',            m.title,
    'description',      m.description,
    'start_at',         m.start_at,
    'end_at',           m.end_at,
    'location_name',    m.location_name,
    'capacity',         m.capacity,
    'visibility',       m.listing_visibility,
    'is_cancelled',     m.is_cancelled,
    'owner_profile_id', m.creator_profile_id,
    'host', jsonb_build_object(
      'actor_profile_id', m.host_actor_id,
      'display_name',     hp_name,
      'username',         hp_user,
      'avatar_url',       hp_avatar
    ),
    'counts',    counts_,
    'my_status', my_status_,
    'sport_key',     sp.sport_key,
    'sport_name_en', sp.name_en,
    'sport_name_ar', sp.name_ar,
    'min_skill',     m.min_skill,
    'max_skill',     m.max_skill,
    'area_name',     v_area,
    'venue_name',    v_venue,
    'attendees',     atts,
    'is_host',   v_host
  );
end;
$function$

;

CREATE OR REPLACE FUNCTION public.rpc_meetup_attendees(p_meetup_id uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(actor_profile_id uuid, display_name text, username citext, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  m       public.meetups%rowtype;
  v_host  boolean;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, m.creator_user_id, m.listing_visibility, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (m.creator_user_id = me or public.is_admin(me));

  return query
  select
    r.profile_id,
    p.display_name,
    p.username,
    r.status
  from public.meetup_rsvps r
  left join public.profiles p on p.id = r.profile_id
  where r.meetup_id = p_meetup_id
    and (p_status is null or r.status = p_status)
    and (v_host or r.status in ('going','interested'))
  order by r.updated_at desc nulls last, r.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$

;

DO $post$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_meetup_card(uuid,text)',                       'ba562664e6a99fee30a75de6fe5cbbeb'),
      ('public.rpc_meetup_attendees(uuid,text,integer,integer)',  '9c82e357c7b0fe58afc645f37d889523'),
      ('public.rpc_meetup_my()',                                  '9459dd31f4dfc534d26b3e37e49326b9')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-725 rollback post: % md5 % (expected pre-image %)', r.fn, v, r.md;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_temp.kan725_rb_pre p JOIN pg_proc c ON c.oid = p.oid
              WHERE c.proowner <> p.proowner OR c.proacl::text IS DISTINCT FROM p.acl
                 OR c.prosecdef <> p.prosecdef OR c.provolatile <> p.provolatile
                 OR c.proconfig IS DISTINCT FROM p.proconfig)
     OR (SELECT count(*) FROM pg_temp.kan725_rb_pre) <> 2 THEN
    RAISE EXCEPTION 'KAN-725 rollback post: owner / ACL / SECURITY DEFINER / search_path changed';
  END IF;
END
$post$;

COMMIT;
