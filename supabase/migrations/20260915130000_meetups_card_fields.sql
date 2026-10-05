-- KAN-429 (Meetups WP3) -- additive card fields for the Meetups listing and details.
-- AUTHORED, NOT APPLIED. Does not edit 20260915120000_meetups_hardening.sql.
--
--   (a) v_meetup_list: CREATE OR REPLACE appending ONE column at the end,
--       attendee_avatars (up to 5 going RSVPs, newest first). Every existing
--       column keeps its name, type and position; non-invoker semantics, the
--       WHERE visibility gate and the grants are unchanged. Empty for anon: the
--       view is anon-readable (T-002) and member names are not.
--   (b) rpc_meetup_card(uuid, text): same signature, SECURITY DEFINER,
--       search_path. Returns the existing jsonb PLUS sport_key, sport_name_en,
--       sport_name_ar, min_skill, max_skill, area_name, venue_name,
--       host.avatar_url and attendees (up to 8 going; authenticated only).
--       counts is unchanged.
BEGIN;

CREATE OR REPLACE VIEW public.v_meetup_list AS
 SELECT m.id,
    m.title,
    m.description,
    m.start_at,
    m.end_at,
    m.capacity,
    m.members_only,
    m.listing_visibility,
    m.rsvp_policy,
    m.is_cancelled,
    m.vibe_key,
    m.created_at,
    m.updated_at,
    m.creator_profile_id,
    cp.display_name AS creator_display_name,
    cp.username AS creator_username,
    cp.avatar_url AS creator_avatar_url,
    m.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    s.emoji AS sport_emoji,
    m.area_id,
    a.name AS area_name,
    m.venue_id,
    v.name_en AS venue_name,
    m.location_name,
    m.geo_location_id,
    m.min_skill,
    m.max_skill,
    m.joining_rule,
    m.cost_cover,
    COALESCE(c.going_count, 0::bigint) AS going_count,
    COALESCE(c.interested_count, 0::bigint) AS interested_count,
    COALESCE(c.declined_count, 0::bigint) AS declined_count,
    att.status AS my_rsvp_status,
    -- appended (KAN-429): up to five going attendees for the card's faces.
    -- Authenticated callers only: this view is anon-readable and member
    -- names/avatars are not (rpc_meetup_attendees is closed to anon).
    CASE WHEN auth.uid() IS NULL THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name) ORDER BY x.updated_at DESC NULLS LAST)
      FROM (SELECT r2.profile_id, r2.updated_at FROM public.meetup_rsvps r2
            WHERE r2.meetup_id = m.id AND r2.status = 'going'
            ORDER BY r2.updated_at DESC NULLS LAST, r2.created_at DESC LIMIT 5) x
      JOIN public.profiles ap ON ap.id = x.profile_id
    ), '[]'::jsonb) END AS attendee_avatars
   FROM public.meetups m
     LEFT JOIN public.profiles cp ON cp.id = m.creator_profile_id
     LEFT JOIN public.sports s ON s.id = m.sport_id
     LEFT JOIN public.areas a ON a.id = m.area_id
     LEFT JOIN public.venues v ON v.id = m.venue_id
     LEFT JOIN public.v_meetup_counts c ON c.meetup_id = m.id
     LEFT JOIN public.meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
  WHERE public.can_view_owner(m.creator_user_id, m.listing_visibility) = true
  ORDER BY COALESCE(m.updated_at, m.created_at) DESC;


ALTER VIEW public.v_meetup_list OWNER TO postgres;
REVOKE ALL ON TABLE public.v_meetup_list FROM PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.v_meetup_list TO anon;
GRANT SELECT, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.v_meetup_list TO authenticated;
GRANT ALL ON TABLE public.v_meetup_list TO service_role;

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

COMMIT;
