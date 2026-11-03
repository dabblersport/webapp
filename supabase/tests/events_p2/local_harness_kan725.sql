-- KAN-725 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Load position: last step of supabase/tests/events_p2/build_kan725.sh, AFTER KAN-718 (20261104110300) and BEFORE
-- 20261104100600_kan714_b06_rpc_meetup_reads.sql and supabase/tests/events_p2/kan714_b06_meetup_reads.sql.
--
-- Why it exists: no earlier harness creates the three B06 pre-image RPCs, citext, or the baseline columns they read
-- and the test seeds, and local_harness_kan712.sql installs a one-argument STUB rpc_meetup_card(uuid) that shadows
-- the real rpc_meetup_card(uuid, text DEFAULT 'player') for one-argument calls. Without this file the migration
-- refuses at its stage guard and the test cannot seed. It COMMITS:
--   1. citext, and stand-in columns no earlier harness creates: meetup_rsvps.created_at; profiles.display_name,
--      username (citext), avatar_url; sports.sport_key, name_en, name_ar; areas.name; venues.name_en.
--   2. the KAN-712 harness stub rpc_meetup_card(uuid) RENAMED to harness_kan712_rpc_meetup_card_stub (not dropped),
--      so public holds only the real signature, as on the stage catalogue.
--   3. VERBATIM pre-images, extracted by line range with sed (not retyped):
--      a. rpc_meetup_card       20260915130000_meetups_card_fields.sql:80-184, grants :186-187
--      b. rpc_meetup_attendees  20260915120000_meetups_hardening.sql:406-443, grants :771-772
--      c. rpc_meetup_my         20260829080500_baseline_schema.sql:13835-13846, grants :36505-36507
--         (created with check_function_bodies off, as the baseline dump does: its body names columns meetups
--         does not have, so every call raises 42703 — the state the test pins in R1)
--   4. asserts md5(pg_get_functiondef) of each pre-image equals the migration's drift pin.

\set ON_ERROR_STOP 1
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-725 harness: this looks like a Supabase database; local throwaway cluster only';
  END IF;
  IF to_regprocedure('public.rpc_meetup_card(uuid,text)') IS NOT NULL
     OR to_regprocedure('public.rpc_meetup_attendees(uuid,text,integer,integer)') IS NOT NULL
     OR to_regprocedure('public.rpc_meetup_my()') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-725 harness: a pre-image already exists; load this once, on a fresh chain';
  END IF;
END $$;

BEGIN;

-- 1. Stand-ins ---------------------------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS citext;
ALTER TABLE public.meetup_rsvps ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name text, ADD COLUMN IF NOT EXISTS username citext,
  ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.sports ADD COLUMN IF NOT EXISTS sport_key text, ADD COLUMN IF NOT EXISTS name_en text,
  ADD COLUMN IF NOT EXISTS name_ar text;
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE public.venues ADD COLUMN IF NOT EXISTS name_en text;

-- 2. Retire the KAN-712 harness stub (renamed, not dropped) ------------------------------------------------------
ALTER FUNCTION public.rpc_meetup_card(uuid) RENAME TO harness_kan712_rpc_meetup_card_stub;

-- 3a. rpc_meetup_card, verbatim: 20260915130000_meetups_card_fields.sql:80-184, grants :186-187 ----------------
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
$function$;

REVOKE ALL ON FUNCTION public.rpc_meetup_card(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_card(uuid, text) TO anon, authenticated, service_role;

-- 3b. rpc_meetup_attendees, verbatim: 20260915120000_meetups_hardening.sql:406-443, grants :771-772 ---------
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
$function$;

REVOKE ALL ON FUNCTION public.rpc_meetup_attendees(uuid, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_attendees(uuid, text, integer, integer) TO authenticated, service_role;

-- 3c. rpc_meetup_my, verbatim: 20260829080500_baseline_schema.sql:13835-13846, grants :36505-36507 ----------
SET LOCAL check_function_bodies = false;
CREATE OR REPLACE FUNCTION "public"."rpc_meetup_my"() RETURNS TABLE("id" "uuid", "title" "text", "starts_at" timestamp with time zone, "visibility" "text", "host_actor_id" "uuid", "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select m.id, m.title, m.starts_at, m.visibility, m.host_actor_id, m.updated_at
  from public.meetups m
  where m.owner_user_id = auth.uid()
  order by m.starts_at
$$;


ALTER FUNCTION "public"."rpc_meetup_my"() OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."rpc_meetup_my"() TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_meetup_my"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_meetup_my"() TO "service_role";
SET LOCAL check_function_bodies = true;

-- 4. The pre-images equal the migration's drift pins -------------------------------------------------------------
DO $$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_meetup_card(uuid,text)',                       'ba562664e6a99fee30a75de6fe5cbbeb'),
      ('public.rpc_meetup_attendees(uuid,text,integer,integer)',  '9c82e357c7b0fe58afc645f37d889523'),
      ('public.rpc_meetup_my()',                                  '9459dd31f4dfc534d26b3e37e49326b9')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-725 harness: % pre-image md5 % expected %', r.fn, v, r.md;
    END IF;
  END LOOP;
END $$;

COMMIT;
