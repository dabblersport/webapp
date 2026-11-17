-- KAN-1013: live probe pack for 20261117163717_kan1013_meetup_wants_to_join_full.sql and
-- 20261117164151_kan1013b_wants_full_plural_safe.sql (plural-safe titles).
-- Run as postgres on wtncuzcskpigqpmnxwws. One DO block ending in RAISE EXCEPTION, so every write rolls back.
-- Cast: H (organiser) and P1..P4, distinct users with an active player profile, not frozen, no blocks.
-- Meetup M (capacity 1) and control meetup C (capacity 10), created inside the block.
--   W1  P1 Going on M fills it; P2 Going on M (full -> stored Interested) -> H gets one meetup.wants_to_join_full,
--       no meetup.rsvp_interested; the RPC returns 'interested'
--   W2  P3 taps Interested on M (a real Interested, same transaction, right after W1) -> meetup.rsvp_interested,
--       not wants_to_join_full (negative control: the marker was cleared)
--   W3  P4 Going on M (still full) grows the same wants_to_join_full card (1 row, 2 actors); the interested card
--       stays separate
--   W4  P2 Going on C (not full) -> going, no wants_to_join_full for C (negative control)
--   W5  the marker is empty after the RPC returns
--   W6  templates (KAN-1013b): EN "{actor} asked to come to {title}, but it's full", AR "طلب حضور {title} من {actor}،
--       لكنه مكتمل"; bodies unchanged; category meetups, in-app
--
-- Run 2026-11-17 by backend-4 after apply (migration 20261117163717): W1..W6 all ok. W1 "Ziad Amin wants to come to
-- KAN1013 Probe M, but it's full"; W3 grown card "Tamer Said and 1 other wants to come to KAN1013 Probe M, but it's full"
-- (group meetup_wants_full:meetup:<id>, total_count 2). After the rollback: 0 probe events, 0 wants_to_join_full rows.
-- Re-run after 20261117164151 (KAN-1013b) with an EN host and an AR host: W1, W3, W6 ok.
--   EN single  "Ziad Amin asked to come to KAN1013 Probe M, but it's full"
--   EN grouped "Tamer Said and 1 other asked to come to KAN1013 Probe M, but it's full"
--   AR single  "طلب حضور KAN1013 Probe M2 من Ziad Amin، لكنه مكتمل"
--   AR grouped "طلب حضور KAN1013 Probe M2 من Tamer Said وشخص آخر، لكنه مكتمل"
CREATE OR REPLACE FUNCTION pg_temp.k1013_as(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
END $$;

DO $probe$
DECLARE
  u uuid[]; pr uuid[]; h uuid; p1 uuid; p2 uuid; p3 uuid; p4 uuid;
  m uuid; c uuid; e uuid; s text; r text := ''; ok boolean; nt record;
  n_w int; n_i int;
BEGIN
  SELECT array_agg(user_id ORDER BY created_at), array_agg(id ORDER BY created_at) INTO u, pr FROM (
    SELECT DISTINCT ON (p.user_id) p.user_id, p.id, p.created_at FROM public.profiles p
     WHERE p.persona_type = 'player' AND p.is_active AND NOT public.is_frozen(p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_user_id = p.user_id OR b.blocked_user_id = p.user_id)
     ORDER BY p.user_id, p.created_at) s
   LIMIT 5;
  h := u[1]; p1 := u[2]; p2 := u[3]; p3 := u[4]; p4 := u[5];

  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy)
  VALUES (e, 'meetup', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN1013 Probe M', 1, 'open');
  INSERT INTO public.meetups(id, event_id, host_actor_id) VALUES (e, e, pr[1]) RETURNING id INTO m;
  e := gen_random_uuid();
  INSERT INTO public.events(id, event_type, creator_user_id, creator_profile_id, start_at, end_at, title, capacity, join_policy)
  VALUES (e, 'meetup', h, pr[1], now() + interval '3 days', now() + interval '3 days 2 hours', 'KAN1013 Probe C', 10, 'open');
  INSERT INTO public.meetups(id, event_id, host_actor_id) VALUES (e, e, pr[1]) RETURNING id INTO c;

  -- W1
  PERFORM pg_temp.k1013_as(p1); PERFORM public.rpc_meetup_rsvp(m, 'going');
  PERFORM pg_temp.k1013_as(p2); s := public.rpc_meetup_rsvp(m, 'going');
  SELECT count(*) FILTER (WHERE kind_key = 'meetup.wants_to_join_full'), count(*) FILTER (WHERE kind_key = 'meetup.rsvp_interested')
    INTO n_w, n_i FROM public.notifications WHERE to_user_id = h AND context ->> 'entity_id' = m::text;
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = h AND kind_key = 'meetup.wants_to_join_full' AND context ->> 'entity_id' = m::text;
  ok := s = 'interested' AND n_w = 1 AND n_i = 0 AND nt.title LIKE '%KAN1013 Probe M%';
  r := r || format(E'W1 Going on a full meetup -> wants_to_join_full only: %s (%s, w=%s i=%s | %s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, s, n_w, n_i, nt.title);

  -- W5 (checked here, right after the RPC returned)
  ok := COALESCE(current_setting('dabbler.rsvp_full_downgrade', true), '') = '';
  r := r || format(E'W5 marker empty after the RPC: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- W2
  PERFORM pg_temp.k1013_as(p3); s := public.rpc_meetup_rsvp(m, 'interested');
  SELECT count(*) FILTER (WHERE kind_key = 'meetup.wants_to_join_full'), count(*) FILTER (WHERE kind_key = 'meetup.rsvp_interested')
    INTO n_w, n_i FROM public.notifications WHERE to_user_id = h AND context ->> 'entity_id' = m::text;
  ok := s = 'interested' AND n_w = 1 AND n_i = 1;
  r := r || format(E'W2 real Interested -> rsvp_interested, not wants_full: %s (w=%s i=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n_w, n_i);

  -- W3
  PERFORM pg_temp.k1013_as(p4); s := public.rpc_meetup_rsvp(m, 'going');
  SELECT count(*) FILTER (WHERE kind_key = 'meetup.wants_to_join_full'), count(*) FILTER (WHERE kind_key = 'meetup.rsvp_interested')
    INTO n_w, n_i FROM public.notifications WHERE to_user_id = h AND context ->> 'entity_id' = m::text;
  SELECT * INTO nt FROM public.notifications WHERE to_user_id = h AND kind_key = 'meetup.wants_to_join_full' AND context ->> 'entity_id' = m::text;
  ok := s = 'interested' AND n_w = 1 AND n_i = 1 AND (nt.context ->> 'total_count')::int = 2
        AND nt.group_key LIKE 'meetup_wants_full:%';
  r := r || format(E'W3 second full Going grows the same card: %s (count %s | %s | %s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, nt.context ->> 'total_count', nt.group_key, nt.title);

  -- W4
  PERFORM pg_temp.k1013_as(p2); s := public.rpc_meetup_rsvp(c, 'going');
  ok := s = 'going' AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = h
                                     AND kind_key = 'meetup.wants_to_join_full' AND context ->> 'entity_id' = c::text);
  r := r || format(E'W4 Going on a meetup with room -> no wants_full: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, s);

  -- W6
  SELECT * INTO nt FROM public.notification_kinds WHERE key = 'meetup.wants_to_join_full';
  ok := nt.category = 'meetups' AND nt.default_channels = '{inapp}' AND nt.is_active
        AND nt.body_template_en = 'They''ll get a place if one opens.' AND nt.body_template_ar = 'سيحصل على مكان إذا توفّر.'
        AND public.notify_v2_render(nt.title_template_en, '{"actor":"Sara","title":"Padel night"}', 'en') = 'Sara asked to come to Padel night, but it''s full'
        AND public.notify_v2_render(nt.title_template_ar, '{"actor":"سارة","title":"ليلة بادل"}', 'ar') = 'طلب حضور ليلة بادل من سارة، لكنه مكتمل';
  r := r || format(E'W6 kind, category and EN/AR templates: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  RAISE EXCEPTION E'KAN1013 PROBE RESULTS (rolled back)\n%', r;
END
$probe$;
