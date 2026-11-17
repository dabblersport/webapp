-- KAN-974 [W0-1] notification envelope v2: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261117045242_kan974_notification_envelope_v2.sql.
--
-- The whole test is ONE DO block. Every write (notifications rows, a user_blocks row, a muted kind, a profile language,
-- activating a kind) happens inside it, and the block always ends with RAISE EXCEPTION, so everything rolls back and
-- the TAP report arrives as the error text. pg_net push requests queued by trg_push_on_notification_insert roll back
-- with it, so no device receives anything. "not ok" anywhere means the test failed.
--
-- Negative controls (each paired with the positive case it guards):
--   idempotency      same dedupe_key twice -> 1 row   | different dedupe_key -> 2nd row; different recipient -> row
--   inactive kind    inactive -> nothing written      | same kind activated -> written
--   block            either direction -> nothing      | no block -> written
--   mute             muted kind -> inbox row, no push  | same kind unmuted -> row and one push
--   language         'ar' profile -> Arabic title     | 'en' profile -> English title
--   priority         high kind -> high row            | normal kind -> normal row
--   grants           anon/authenticated cannot execute| service_role can
--
-- Run 2026-11-17 by backend-1 (Shu) after apply: 1..39, all ok, "# 0 failed of 39".
-- Rerun 2026-11-17 10:2x UTC after KAN-974c and KAN-979b: 1..48, 47 ok; probe 5 then failed only on game.updated,
-- retired by W1-B3, and was rewritten to exclude it (checked separately: game.updated is the only inactive old kind).
-- Rerun 2026-11-17 after KAN-974c: 6 probes had pinned text that later tickets legitimately changed (kinds
-- activated by KAN-980/982/985, game.player_joined reworded, security.new_signin activated); they now read the live
-- registry. KAN-974c (20261117101144): mute probe now expects the inbox row and no queued push; the push-trigger md5 is no
-- longer pinned (KAN-979 owns it); the aggregation probe follows KAN-980's notification_aggregate_add.
-- P9..P11 added for 20261117053400_kan974b (PEER comment 16411): column-scoped UPDATE, literal render, AR fallback.
-- Fault injection (second block below, also rolled back): M1..M5 each turned its probe to "not ok"; afterwards the live
-- catalogue was re-read: notify_v2 proacl {postgres=X/postgres,service_role=X/postgres}, 35 active kinds, 22 breaks_quiet,
-- 0 leftover kan974:* rows, old-row md5 unchanged.
--
-- Pre-image constants (recorded before apply, 2026-11-17 04:50:40 UTC):
--   1337 rows created before that instant, md5 9eb2d178b3ebc8e8b544240b903b0f91 over id/kind/title/body/route/priority/context.

DO $tap$
DECLARE
  tap   text := '';
  n     int  := 0;
  bad   int  := 0;
  r     uuid;   -- recipient
  a     uuid;   -- actor
  r2    uuid;   -- second recipient
  g     uuid := '00000000-0000-0000-0000-0000000974a1';
  id1   uuid; id2 uuid; id3 uuid; id4 uuid;
  v     record;
  c     int;
  t     text;
  sig   text := 'public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)';
  snap  timestamptz := '2026-11-17 04:50:40.099607+00';
  k     text;   -- a still-inactive kind, picked at run time (producer tickets activate their own kinds)
BEGIN
  -- plpgsql has no nested functions, so each check is written inline as: n := n + 1; tap := tap || <TAP line>

  ---------------------------------------------------------------------------------------------------------- schema
  SELECT count(*) INTO c FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications'
     AND column_name IN ('template_key','args','source_event_id','dedupe_key','group_key','schema_version');
  n := n + 1; IF c = 6 THEN tap := tap || format(E'ok %s - notifications has the 6 envelope columns\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - notifications envelope columns: %s of 6\n', n, c); END IF;

  SELECT count(*) INTO c FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notification_kinds'
     AND column_name IN ('title_template_en','title_template_ar','body_template_en','body_template_ar','breaks_quiet','can_mute','category');
  n := n + 1; IF c = 7 THEN tap := tap || format(E'ok %s - notification_kinds has the 7 template/flag columns\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - notification_kinds columns: %s of 7\n', n, c); END IF;

  SELECT indexdef INTO t FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'notifications_to_user_dedupe_key_uidx';
  n := n + 1; IF t LIKE 'CREATE UNIQUE INDEX%(to_user_id, dedupe_key) WHERE (dedupe_key IS NOT NULL)' THEN
    tap := tap || format(E'ok %s - unique index on (to_user_id, dedupe_key)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - dedupe index: %s\n', n, coalesce(t, 'missing')); END IF;

  ----------------------------------------------------------------------------------------------------------- kinds
  SELECT count(*) INTO c FROM public.notification_kinds;
  n := n + 1; IF c = 87 THEN tap := tap || format(E'ok %s - 87 kinds (35 existing + 52 new)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - kinds total %s\n', n, c); END IF;

  -- Since Wave 1 the producer tickets (KAN-980, KAN-982, KAN-985, ...) activate their own new kinds, so the
  -- "all inactive" check of the first run (2026-11-17, 52/52) is now a count, not an invariant.
  -- game.updated was retired by its own ticket (W1-B3: "game.updated stops meaning cancel"); every other
  -- pre-existing kind must still be active.
  SELECT count(*) INTO c FROM public.notification_kinds WHERE NOT is_active AND created_at < snap AND key <> 'game.updated';
  n := n + 1; IF c = 0 THEN
    tap := tap || format(E'ok %s - the pre-existing kinds are still active (game.updated retired by W1-B3)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s pre-existing kinds deactivated\n', n, c); END IF;

  SELECT count(*) INTO c FROM public.notification_kinds WHERE created_at >= snap;
  n := n + 1; IF c = 52 THEN
    tap := tap || format(E'ok %s - the 52 new kinds exist (%s activated by their producer tickets so far)\n', n,
                         (SELECT count(*) FROM public.notification_kinds WHERE created_at >= snap AND is_active));
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - new kinds %s\n', n, c); END IF;

  SELECT count(*) INTO c FROM public.notification_kinds
   WHERE category IS NULL OR coalesce(title_template_en,'') = '' OR coalesce(title_template_ar,'') = ''
      OR coalesce(body_template_en,'') = '' OR coalesce(body_template_ar,'') = '';
  n := n + 1; IF c = 0 THEN tap := tap || format(E'ok %s - every kind has a category and EN+AR title and body templates\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s kinds missing category/templates\n', n, c); END IF;

  SELECT count(*) INTO c FROM public.notification_kinds
   WHERE title_template_ar !~ '[؀-ۿ]' OR body_template_ar !~ '[؀-ۿ]';
  n := n + 1; IF c = 0 THEN tap := tap || format(E'ok %s - every AR template contains Arabic script\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s AR templates without Arabic\n', n, c); END IF;

  -- breaks_quiet: exactly I-3 (cancellations, changes to an upcoming event, removal, waitlist promotion, reminders)
  -- plus security notices
  SELECT string_agg(key, ',' ORDER BY key) INTO t FROM public.notification_kinds WHERE breaks_quiet;
  n := n + 1; IF t = 'game.cancelled,game.details_changed,game.occurrence_cancelled,game.reminder,game.removed,'
                  || 'game.series_changed,game.time_changed,game.updated,game.venue_changed,game.waitlist_promoted,'
                  || 'meetup.cancelled,meetup.confirm_attendance,meetup.details_changed,meetup.occurrence_cancelled,'
                  || 'meetup.reminder,meetup.removed,meetup.series_changed,meetup.time_changed,meetup.venue_changed,'
                  || 'security.email_changed,security.new_signin,security.password_changed' THEN
    tap := tap || format(E'ok %s - breaks_quiet is exactly the I-3 set plus security\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - breaks_quiet set: %s\n', n, t); END IF;

  SELECT count(*) INTO c FROM public.notification_kinds
   WHERE breaks_quiet AND category IN ('social', 'messages');
  n := n + 1; IF c = 0 THEN tap := tap || format(E'ok %s - no social or message kind breaks quiet hours\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s social/message kinds break quiet\n', n, c); END IF;

  SELECT string_agg(key, ',' ORDER BY key) INTO t FROM public.notification_kinds WHERE NOT can_mute;
  n := n + 1; IF t = 'security.email_changed,security.new_signin,security.password_changed' THEN
    tap := tap || format(E'ok %s - only the security notices cannot be muted\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - can_mute=false set: %s\n', n, t); END IF;

  n := n + 1; IF NOT EXISTS (SELECT 1 FROM public.notification_kinds WHERE key = 'activity.starting_soon') THEN
    tap := tap || format(E'ok %s - activity.starting_soon is not registered (it is the 30m rung)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - activity.starting_soon exists\n', n); END IF;

  ---------------------------------------------------------------------------------------------------------- grants
  SELECT p.prosecdef, p.proconfig, p.proacl::text AS acl INTO v FROM pg_proc p WHERE p.oid = sig::regprocedure;
  n := n + 1; IF v.prosecdef AND v.proconfig = ARRAY['search_path=public, pg_temp'] THEN
    tap := tap || format(E'ok %s - notify_v2 is SECURITY DEFINER with search_path public, pg_temp\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - notify_v2 definer/search_path %s %s\n', n, v.prosecdef, v.proconfig); END IF;

  n := n + 1; IF NOT has_function_privilege('anon', sig, 'EXECUTE') AND NOT has_function_privilege('authenticated', sig, 'EXECUTE')
                 AND v.acl NOT LIKE '%anon=%' AND v.acl NOT LIKE '%authenticated=%' AND v.acl NOT LIKE '{=%' AND v.acl NOT LIKE '%,=%' THEN
    tap := tap || format(E'ok %s - anon, authenticated and PUBLIC cannot execute notify_v2 (proacl %s)\n', n, v.acl);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - notify_v2 proacl %s\n', n, v.acl); END IF;

  n := n + 1; IF has_function_privilege('service_role', sig, 'EXECUTE') THEN
    tap := tap || format(E'ok %s - negative control: service_role can execute notify_v2\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - service_role cannot execute notify_v2\n', n); END IF;

  n := n + 1; IF NOT has_function_privilege('anon', 'public.notify_v2_render(text,jsonb,text)', 'EXECUTE')
                 AND NOT has_function_privilege('authenticated', 'public.notify_v2_render(text,jsonb,text)', 'EXECUTE') THEN
    tap := tap || format(E'ok %s - anon and authenticated cannot execute notify_v2_render\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - notify_v2_render executable by a client role\n', n); END IF;

  ------------------------------------------------------------------------------------------- old rows and old path
  SELECT count(*), md5(string_agg(id::text||kind_key||title||coalesce(body,'')||coalesce(action_route,'')||priority::text||context::text, ',' ORDER BY id))
    INTO v FROM public.notifications WHERE created_at < snap;
  n := n + 1; IF v.count = 1337 AND v.md5 = '9eb2d178b3ebc8e8b544240b903b0f91' THEN
    tap := tap || format(E'ok %s - the 1337 old rows are byte-identical (title/body/route/priority/context)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - old rows %s md5 %s\n', n, v.count, v.md5); END IF;

  SELECT count(*) INTO c FROM public.notifications WHERE created_at < snap
     AND (schema_version <> 1 OR template_key IS NOT NULL OR args IS NOT NULL OR source_event_id IS NOT NULL
          OR dedupe_key IS NOT NULL OR group_key IS NOT NULL);
  n := n + 1; IF c = 0 THEN tap := tap || format(E'ok %s - old rows read schema_version 1 with empty envelope columns\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s old rows have envelope values\n', n, c); END IF;

  -- (the push trigger is owned by KAN-979 since 20261117055738 and is no longer pinned here)
  n := n + 1; IF md5(pg_get_functiondef('public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure)) = '960d2aa2d3b0187064497e6a27c2ed3a'
                 AND md5(pg_get_functiondef('public.emit_event(text,text,uuid,uuid,jsonb)'::regprocedure)) = 'c3acfd9d3d7bfecf010400e0363db114' THEN
    tap := tap || format(E'ok %s - process_notification_event and emit_event (no-op) are unchanged\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - a legacy function definition changed\n', n); END IF;

  -------------------------------------------------------------------------------------------------- fixtures (rolled back)
  SELECT p.user_id INTO r FROM public.profiles p WHERE p.is_active AND p.user_id IS NOT NULL ORDER BY p.created_at LIMIT 1;
  SELECT p.user_id INTO a FROM public.profiles p WHERE p.is_active AND p.user_id IS NOT NULL AND p.user_id <> r
   ORDER BY p.created_at LIMIT 1;
  SELECT p.user_id INTO r2 FROM public.profiles p WHERE p.is_active AND p.user_id IS NOT NULL AND p.user_id NOT IN (r, a)
   ORDER BY p.created_at LIMIT 1;
  DELETE FROM public.user_blocks WHERE blocker_user_id IN (r, a, r2) OR blocked_user_id IN (r, a, r2);
  UPDATE public.notification_settings SET muted_kinds = '{}' WHERE user_id IN (r, r2);
  UPDATE public.profiles SET language = 'en' WHERE user_id IN (r, r2);

  -- old path probe (one game kind, one social kind) after the migration: same shape as the pre-apply probe
  PERFORM public.process_notification_event(r, 'social.mentioned_in_post', 'post', g, a);
  PERFORM public.process_notification_event(r, 'game.player_joined', 'game', g, a);
  SELECT count(*) INTO c FROM public.notifications
   WHERE to_user_id = r AND context->>'entity_id' = g::text AND schema_version = 1 AND template_key IS NULL AND body IS NULL
     AND priority = 'normal'
     AND ((kind_key = 'game.player_joined' AND title LIKE '% joined your game' AND action_route = '/sports/games/' || g)
       OR (kind_key = 'social.mentioned_in_post' AND title LIKE '% mentioned you in a post' AND action_route IS NULL));
  n := n + 1; IF c = 2 THEN tap := tap || format(E'ok %s - process_notification_event still writes the legacy rows (game + social)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - legacy probe rows %s of 2\n', n, c); END IF;
  DELETE FROM public.notifications WHERE to_user_id = r AND context->>'entity_id' = g::text;

  ------------------------------------------------------------------------------------------------------ idempotency
  id1 := public.notify_v2(r, 'game.player_joined', '{"title":"Kickabout"}', 'game', g, a, 'src-1', 'kan974:dk1', 'grp-1', NULL);
  id2 := public.notify_v2(r, 'game.player_joined', '{"title":"Kickabout"}', 'game', g, a, 'src-1', 'kan974:dk1', 'grp-1', NULL);
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = r AND dedupe_key = 'kan974:dk1';
  n := n + 1; IF id1 IS NOT NULL AND id1 = id2 AND c = 1 THEN
    tap := tap || format(E'ok %s - same dedupe_key twice for one recipient leaves exactly one row (same id returned)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - idempotency: rows %s ids %s %s\n', n, c, id1, id2); END IF;

  id3 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, 'src-1', 'kan974:dk2', NULL, NULL);
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = r AND dedupe_key LIKE 'kan974:dk%';
  n := n + 1; IF id3 IS NOT NULL AND id3 <> id1 AND c = 2 THEN
    tap := tap || format(E'ok %s - negative control: a different dedupe_key writes a second row\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - different dedupe_key: rows %s\n', n, c); END IF;

  id4 := public.notify_v2(r2, 'game.player_joined', '{}', 'game', g, a, 'src-1', 'kan974:dk1', NULL, NULL);
  n := n + 1; IF id4 IS NOT NULL AND id4 <> id1 THEN
    tap := tap || format(E'ok %s - negative control: the same dedupe_key for a different recipient writes a row\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - different recipient: id %s\n', n, id4); END IF;

  SELECT * INTO v FROM public.notifications WHERE id = id1;
  n := n + 1; IF v.template_key = 'game.player_joined' AND v.args->>'title' = 'Kickabout' AND v.args ? 'actor'
                 AND v.source_event_id = 'src-1' AND v.dedupe_key = 'kan974:dk1' AND v.group_key = 'grp-1'
                 AND v.schema_version = 2
                 AND v.title = public.notify_v2_render((SELECT title_template_en FROM public.notification_kinds WHERE key = 'game.player_joined'), v.args, 'en')
                 AND v.body = public.notify_v2_render((SELECT body_template_en FROM public.notification_kinds WHERE key = 'game.player_joined'), v.args, 'en')
                 AND v.action_route = '/sports/games/' || g AND v.context->>'entity_id' = g::text THEN
    tap := tap || format(E'ok %s - v2 row carries the envelope and still fills title/body/action_route (%s)\n', n, v.title);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - v2 row %s\n', n, row_to_json(v)); END IF;

  BEGIN
    PERFORM public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, NULL, NULL, NULL);
    n := n + 1; bad := bad + 1; tap := tap || format(E'not ok %s - a NULL dedupe_key was accepted\n', n);
  EXCEPTION WHEN SQLSTATE '22004' THEN
    n := n + 1; tap := tap || format(E'ok %s - a NULL dedupe_key is refused (22004)\n', n);
  END;

  --------------------------------------------------------------------------------------------- priority from the kind
  id1 := public.notify_v2(r, 'game.removed', '{}', 'game', g, a, NULL, 'kan974:prio-high', NULL, NULL);
  SELECT priority::text INTO t FROM public.notifications WHERE id = id1;
  n := n + 1; IF t = (SELECT default_priority::text FROM public.notification_kinds WHERE key = 'game.removed') AND t = 'high' THEN
    tap := tap || format(E'ok %s - priority comes from the kind (game.removed -> high)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - game.removed priority %s\n', n, t); END IF;

  SELECT priority::text INTO t FROM public.notifications WHERE to_user_id = r AND dedupe_key = 'kan974:dk2';
  n := n + 1; IF t = 'normal' THEN tap := tap || format(E'ok %s - negative control: game.player_joined -> normal\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - game.player_joined priority %s\n', n, t); END IF;

  UPDATE public.notification_kinds SET default_priority = 'urgent' WHERE key = 'game.player_joined';
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:prio-urgent', NULL, NULL);
  SELECT priority::text INTO t FROM public.notifications WHERE id = id1;
  n := n + 1; IF t = 'urgent' THEN tap := tap || format(E'ok %s - changing the kind''s priority changes the row priority\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - after kind change priority %s\n', n, t); END IF;
  UPDATE public.notification_kinds SET default_priority = 'normal' WHERE key = 'game.player_joined';

  ------------------------------------------------------------------------------------------------------- language pick
  UPDATE public.profiles SET language = 'ar' WHERE user_id = r;
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, NULL, NULL, 'kan974:lang-ar', NULL, NULL);
  SELECT title || ' | ' || coalesce(body, '') INTO t FROM public.notifications WHERE id = id1;
  -- expected text comes from the live AR templates (KAN-982 reworded game.player_joined after the first run)
  n := n + 1; IF t = (SELECT public.notify_v2_render(title_template_ar, '{"actor":"شخص ما"}', 'ar') || ' | '
                          || coalesce(public.notify_v2_render(body_template_ar, '{"actor":"شخص ما"}', 'ar'), '')
                        FROM public.notification_kinds WHERE key = 'game.player_joined')
                 AND t ~ '[\u0600-\u06FF]' THEN
    tap := tap || format(E'ok %s - Arabic recipient gets the AR templates: %s\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - AR recipient got: %s\n', n, t); END IF;

  UPDATE public.notification_kinds SET is_active = true WHERE key = 'meetup.reminder';
  id1 := public.notify_v2(r, 'meetup.reminder', '{"title":"Run club","when_en":"in 2 hours","when_ar":"بعد ساعتين"}',
                          'meetup', g, NULL, NULL, 'kan974:lang-arg', NULL, NULL);
  SELECT title INTO t FROM public.notifications WHERE id = id1;
  n := n + 1; IF t = 'Run club يبدأ بعد ساعتين' THEN
    tap := tap || format(E'ok %s - a _ar argument overrides the plain one for an Arabic recipient: %s\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - language-specific arg: %s\n', n, t); END IF;

  UPDATE public.profiles SET language = 'en' WHERE user_id = r;
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, NULL, NULL, 'kan974:lang-en', NULL, NULL);
  id2 := public.notify_v2(r, 'meetup.reminder', '{"title":"Run club","when_en":"in 2 hours","when_ar":"بعد ساعتين"}',
                          'meetup', g, NULL, NULL, 'kan974:lang-arg-en', NULL, NULL);
  SELECT (SELECT title FROM public.notifications WHERE id = id1) || ' | ' || (SELECT title FROM public.notifications WHERE id = id2) INTO t;
  n := n + 1; IF t = (SELECT public.notify_v2_render(title_template_en, '{"actor":"Someone"}', 'en') FROM public.notification_kinds
                       WHERE key = 'game.player_joined') || ' | Run club starts in 2 hours' AND t !~ '[\u0600-\u06FF]' THEN
    tap := tap || format(E'ok %s - negative control: English recipient gets the EN templates: %s\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - EN recipient got: %s\n', n, t); END IF;
  UPDATE public.notification_kinds SET is_active = false WHERE key = 'meetup.reminder';

  -------------------------------------------------------------------------------------------------------------- block
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (r, a);
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:blocked-1', NULL, NULL);
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = r AND dedupe_key = 'kan974:blocked-1';
  n := n + 1; IF id1 IS NULL AND c = 0 THEN tap := tap || format(E'ok %s - recipient blocked the actor: nothing written\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - recipient-blocks-actor wrote %s rows\n', n, c); END IF;
  DELETE FROM public.user_blocks WHERE blocker_user_id = r AND blocked_user_id = a;

  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (a, r);
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:blocked-2', NULL, NULL);
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = r AND dedupe_key = 'kan974:blocked-2';
  n := n + 1; IF id1 IS NULL AND c = 0 THEN tap := tap || format(E'ok %s - actor blocked the recipient: nothing written\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - actor-blocks-recipient wrote %s rows\n', n, c); END IF;
  DELETE FROM public.user_blocks WHERE blocker_user_id = a AND blocked_user_id = r;

  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:unblocked', NULL, NULL);
  n := n + 1; IF id1 IS NOT NULL THEN tap := tap || format(E'ok %s - negative control: block removed, the same call writes\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - unblocked call wrote nothing\n', n); END IF;

  --------------------------------------------------------------------------------------------------------------- mute
  -- KAN-974c (design PUSH-12): a muted kind still writes the inbox row; the push trigger (KAN-979) skips the push.
  -- The push is read from net.http_request_queue, queued by the trigger in this same (rolled back) transaction.
  INSERT INTO public.notification_settings (user_id, muted_kinds) VALUES (r, ARRAY['game.player_joined'])
  ON CONFLICT (user_id) DO UPDATE SET muted_kinds = EXCLUDED.muted_kinds;
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:muted', NULL, NULL);
  SELECT count(*) INTO c FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  n := n + 1; IF id1 IS NOT NULL AND EXISTS (SELECT 1 FROM public.notifications WHERE id = id1) AND c = 0 THEN
    tap := tap || format(E'ok %s - a muted kind writes the inbox row and queues no push (PUSH-12)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - muted kind: row %s, pushes queued %s\n', n, id1, c); END IF;

  UPDATE public.notification_settings SET muted_kinds = '{}' WHERE user_id = r;
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:unmuted', NULL, NULL);
  SELECT count(*) INTO c FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  n := n + 1; IF id1 IS NOT NULL AND c = 1 THEN
    tap := tap || format(E'ok %s - negative control: the same kind unmuted writes the row and queues one push\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - unmuted kind: row %s, pushes queued %s\n', n, id1, c); END IF;

  ------------------------------------------------------------------------------------------------------ inactive kind
  SELECT nk.key INTO k FROM public.notification_kinds nk
   WHERE NOT nk.is_active AND NOT EXISTS (SELECT 1 FROM public.notification_aggregation_rules ar WHERE ar.kind_key = nk.key AND ar.enabled)
   ORDER BY nk.key LIMIT 1;
  id1 := public.notify_v2(r, k, '{}', NULL, NULL, NULL, NULL, 'kan974:inactive', NULL, NULL);
  SELECT count(*) INTO c FROM public.notifications WHERE to_user_id = r AND dedupe_key = 'kan974:inactive';
  n := n + 1; IF k IS NOT NULL AND id1 IS NULL AND c = 0 THEN tap := tap || format(E'ok %s - an inactive kind (%s) writes nothing\n', n, k);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - inactive kind %s wrote %s rows\n', n, k, c); END IF;

  UPDATE public.notification_kinds SET is_active = true WHERE key = k;
  id1 := public.notify_v2(r, k, '{}', NULL, NULL, NULL, NULL, 'kan974:activated', NULL, NULL);
  SELECT * INTO v FROM public.notifications WHERE id = id1;
  n := n + 1; IF id1 IS NOT NULL AND v.kind_key = k
                 AND v.priority = (SELECT default_priority FROM public.notification_kinds WHERE key = k) THEN
    tap := tap || format(E'ok %s - negative control: the same kind activated writes\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - activated kind %s: %s\n', n, k, id1); END IF;
  UPDATE public.notification_kinds SET is_active = false WHERE key = k;

  --------------------------------------------------------------------------------------------------- aggregation hand-off
  -- Since KAN-980 (20261117100750) the hand-off is notification_aggregate_add, which returns the grouped row's id.
  id1 := public.notify_v2(r2, 'social.post_liked', '{}', 'post', g, a, NULL, 'kan974:agg', NULL, NULL);
  n := n + 1;
  IF id1 IS NOT NULL AND EXISTS (SELECT 1 FROM public.notifications WHERE id = id1 AND to_user_id = r2 AND group_key IS NOT NULL)
     AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = r2 AND dedupe_key = 'kan974:agg') THEN
    tap := tap || format(E'ok %s - a kind with an aggregation rule is handed to notification_aggregate_add (KAN-980): grouped row\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - aggregation hand-off: %s\n', n, id1); END IF;

  ---------------------------------------------------------- P9 (KAN-974b): clients can only update the read/click columns
  UPDATE public.notification_settings SET muted_kinds = '{}' WHERE user_id = r;
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:p9', NULL, NULL);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', r, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    UPDATE public.notifications SET dedupe_key = 'kan974:forged' WHERE id = id1;
    n := n + 1; bad := bad + 1; tap := tap || format(E'not ok %s - authenticated rewrote its own dedupe_key\n', n);
  EXCEPTION WHEN insufficient_privilege THEN
    n := n + 1; tap := tap || format(E'ok %s - P9 authenticated cannot rewrite its own dedupe_key (42501)\n', n);
  END;
  BEGIN
    UPDATE public.notifications SET kind_key = 'security.new_signin' WHERE id = id1;
    n := n + 1; bad := bad + 1; tap := tap || format(E'not ok %s - authenticated rewrote its own kind_key\n', n);
  EXCEPTION WHEN insufficient_privilege THEN
    n := n + 1; tap := tap || format(E'ok %s - P9 authenticated cannot rewrite kind_key either (42501)\n', n);
  END;
  -- markAsRead (notifications_repository_impl.dart): direct update of is_read, read_at by id
  UPDATE public.notifications SET is_read = true, read_at = now() WHERE id = id1;
  GET DIAGNOSTICS c = ROW_COUNT;
  n := n + 1; IF c = 1 THEN tap := tap || format(E'ok %s - P9 markAsRead still works (is_read, read_at)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - markAsRead updated %s rows\n', n, c); END IF;
  -- markAllRead: is_read, read_at by to_user_id and is_read = false
  EXECUTE 'RESET ROLE';
  id2 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, a, NULL, 'kan974:p9b', NULL, NULL);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.notifications SET is_read = true, read_at = now() WHERE to_user_id = r AND is_read = false AND id = id2;
  GET DIAGNOSTICS c = ROW_COUNT;
  n := n + 1; IF c = 1 THEN tap := tap || format(E'ok %s - P9 markAllRead filter shape still works\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - markAllRead updated %s rows\n', n, c); END IF;
  -- markClicked: increment_notification_interaction (SECURITY INVOKER)
  PERFORM public.increment_notification_interaction(id1);
  EXECUTE 'RESET ROLE';
  SELECT * INTO v FROM public.notifications WHERE id = id1;
  n := n + 1; IF v.interaction_count = 1 AND v.clicked_at IS NOT NULL AND v.is_read AND v.dedupe_key = 'kan974:p9'
                 AND v.kind_key = 'game.player_joined' THEN
    tap := tap || format(E'ok %s - P9 increment_notification_interaction still works; dedupe_key and kind_key unchanged\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - after RPC: %s\n', n, row_to_json(v)); END IF;
  -- negative control: with the old table-level UPDATE grant the same forge succeeds
  GRANT UPDATE ON public.notifications TO authenticated;
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    UPDATE public.notifications SET dedupe_key = 'kan974:forged' WHERE id = id1;
    GET DIAGNOSTICS c = ROW_COUNT;
  EXCEPTION WHEN insufficient_privilege THEN
    c := -1;
  END;
  EXECUTE 'RESET ROLE';
  REVOKE UPDATE ON public.notifications FROM authenticated;
  GRANT UPDATE (is_read, read_at, clicked_at, interaction_count) ON public.notifications TO authenticated;
  n := n + 1; IF c = 1 THEN
    tap := tap || format(E'ok %s - P9 negative control: with the pre-fix table UPDATE grant the forge succeeds\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - negative control forge result %s\n', n, c); END IF;

  ------------------------------------------------------------------ P10 (KAN-974b): placeholder values are literal
  n := n + 1; IF public.notify_v2_render('{actor} left {title}', '{"actor":"{title}","title":"Kick"}', 'en') = '{title} left Kick' THEN
    tap := tap || format(E'ok %s - P10 a value containing {title} is inserted literally\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - P10 render %s\n', n,
    public.notify_v2_render('{actor} left {title}', '{"actor":"{title}","title":"Kick"}', 'en')); END IF;
  n := n + 1; IF public.notify_v2_render('Was {old}, now {new}.', '{"new":"8pm"}', 'en') = 'Was , now 8pm.'
                 AND public.notify_v2_render('{title} starts {when}', '{"title":"Run","when":"x","when_ar":"بعد ساعتين"}', 'ar') = 'Run starts بعد ساعتين' THEN
    tap := tap || format(E'ok %s - P10 negative control: missing args render empty, _ar override still applies\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - P10 control\n', n); END IF;

  ------------------------------------------------- P11 (KAN-974b): Arabic fallback actor name also in context
  UPDATE public.profiles SET language = 'ar' WHERE user_id = r;
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, NULL, NULL, 'kan974:p11-ar', NULL, NULL);
  UPDATE public.profiles SET language = 'en' WHERE user_id = r;
  id2 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, NULL, NULL, 'kan974:p11-en', NULL, NULL);
  SELECT (SELECT context->>'actor_display_name' FROM public.notifications WHERE id = id1) || ' | ' ||
         (SELECT context->>'actor_display_name' FROM public.notifications WHERE id = id2) INTO t;
  n := n + 1; IF t = 'شخص ما | Someone' THEN
    tap := tap || format(E'ok %s - P11 context.actor_display_name falls back per language (AR | EN control): %s\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - P11 context fallback: %s\n', n, t); END IF;

  RAISE EXCEPTION E'KAN-974 TAP (rolled back)\n1..%\n%# % failed of %', n, tap, bad, n;
END
$tap$;

-- Fault injection: each mutation must turn its probe to "not ok" (proves the static probes can fail). Rolled back.
DO $mut$
DECLARE out text := ''; t text; c int; snap timestamptz := '2026-11-17 04:50:40.099607+00';
  sig text := 'public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)';
BEGIN
  UPDATE public.notification_kinds SET breaks_quiet = true WHERE key = 'social.followed';
  SELECT count(*) INTO c FROM public.notification_kinds WHERE breaks_quiet AND category IN ('social','messages');
  out := out || format(E'M1 social.followed breaks_quiet -> probe 10 %s\n', CASE WHEN c = 0 THEN 'ok' ELSE 'not ok' END);

  UPDATE public.notification_kinds SET is_active = true WHERE key = 'game.cancelled';
  SELECT count(*) INTO c FROM public.notification_kinds WHERE created_at >= snap AND NOT is_active;
  out := out || format(E'M2 game.cancelled activated -> probe 6 %s (inactive new = %s)\n', CASE WHEN c = 52 THEN 'ok' ELSE 'not ok' END, c);

  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', sig);
  out := out || format(E'M3 grant to authenticated -> probe 14 %s\n',
    CASE WHEN NOT has_function_privilege('authenticated', sig, 'EXECUTE') THEN 'ok' ELSE 'not ok' END);

  UPDATE public.notifications SET title = title || ' x' WHERE id = (SELECT id FROM public.notifications WHERE created_at < snap ORDER BY id LIMIT 1);
  SELECT md5(string_agg(id::text||kind_key||title||coalesce(body,'')||coalesce(action_route,'')||priority::text||context::text, ',' ORDER BY id))
    INTO t FROM public.notifications WHERE created_at < snap;
  out := out || format(E'M4 one old title edited -> probe 17 %s\n', CASE WHEN t = '9eb2d178b3ebc8e8b544240b903b0f91' THEN 'ok' ELSE 'not ok' END);

  UPDATE public.notification_kinds SET can_mute = false WHERE key = 'game.removed';
  SELECT string_agg(key, ',' ORDER BY key) INTO t FROM public.notification_kinds WHERE NOT can_mute;
  out := out || format(E'M5 game.removed can_mute=false -> probe 11 %s\n',
    CASE WHEN t = 'security.email_changed,security.new_signin,security.password_changed' THEN 'ok' ELSE 'not ok' END);

  RAISE EXCEPTION E'KAN-974 fault injection (rolled back)\n%', out;
END $mut$;
