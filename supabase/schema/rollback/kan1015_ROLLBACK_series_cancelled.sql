-- KAN-1015 rollback: undoes 20261117163934_kan1015_series_cancelled, nothing else. Restores the KAN-981 consumer
-- body (20261117102109; CREATE OR REPLACE keeps its ACL) and removes the kind. Notifications already sent stay in the inbox.
BEGIN;
CREATE OR REPLACE FUNCTION public.kan981_consume_event_changes(
    p_now      timestamptz DEFAULT now(),
    p_settle   interval    DEFAULT '60 seconds',
    p_max_wait interval    DEFAULT '5 minutes')
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_mark     jsonb := jsonb_build_object('w1_b3', p_now);
  v_sent     int := 0;
  v_notices  int := 0;
  v_silent   int := 0;
  v_series_n int := 0;
  s          record;
  ev         public.events;
  v_ids      bigint[];
  v_max      bigint;
  v_actors   uuid[];
  v_c        jsonb;
  v_tz       text;
  v_series   uuid;
  v_title_en text;  v_title_ar text;
  f_en text[]; f_ar text[]; o_en text[]; o_ar text[]; n_en text[]; n_ar text[];
  v_time boolean; v_place boolean;
  o_start timestamptz; o_end timestamptz; o_venue uuid; o_area uuid;
  v_o text; v_n text;
  v_kind     text;
  v_args     jsonb;
  v_ec       bigint;
  u          uuid;
  v_id       uuid;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('kan981_consume_event_changes')) THEN
    RETURN jsonb_build_object('skipped', 'locked');
  END IF;

  -- (a) series batches: one transaction touched two or more occurrences of one game series.
  FOR s IN
    WITH ready AS (
      SELECT x.event_id FROM public.event_changes x
       WHERE NOT (x.consumed_by ? 'w1_b3') AND x.occurred_at <= p_now
       GROUP BY x.event_id
      HAVING max(x.occurred_at) <= p_now - p_settle OR min(x.occurred_at) <= p_now - p_max_wait)
    SELECT g.series_id, x.occurred_at, array_agg(DISTINCT x.event_id) AS events,
           array_agg(x.id) AS ids, max(x.id) AS max_id,
           array_agg(DISTINCT x.actor_user_id) FILTER (WHERE x.actor_user_id IS NOT NULL) AS actors
      FROM public.event_changes x
      JOIN ready r ON r.event_id = x.event_id
      JOIN public.games g ON g.event_id = x.event_id
     WHERE NOT (x.consumed_by ? 'w1_b3') AND g.series_id IS NOT NULL
     GROUP BY g.series_id, x.occurred_at
    HAVING count(DISTINCT x.event_id) >= 2
  LOOP
    v_title_en := coalesce(nullif(btrim((SELECT gs.title FROM public.game_series gs WHERE gs.id = s.series_id)), ''),
                           public.kan981_event_title(s.events[1], 'en'));
    v_title_ar := coalesce(nullif(btrim((SELECT gs.title FROM public.game_series gs WHERE gs.id = s.series_id)), ''),
                           public.kan981_event_title(s.events[1], 'ar'));
    v_args := jsonb_build_object('title_en', v_title_en, 'title_ar', v_title_ar,
                                 'occurrences', cardinality(s.events), 'series_id', s.series_id);
    FOR u IN SELECT DISTINCT r FROM unnest(s.events) AS e(id), LATERAL public.kan981_recipients(e.id) AS r
              WHERE r <> ALL (coalesce(s.actors, '{}')) LOOP
      v_id := public.notify_v2(u, 'game.series_changed', v_args, 'game', s.events[1], s.actors[1],
                               'event_changes:' || s.max_id, 'w1_b3:series:' || s.series_id || ':' || s.max_id,
                               'series:' || s.series_id, NULL);
      IF v_id IS NOT NULL THEN v_sent := v_sent + 1; END IF;
    END LOOP;
    UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (s.ids);
    v_series_n := v_series_n + 1;
  END LOOP;

  -- (b) one event at a time.
  FOR s IN
    SELECT x.event_id, array_agg(x.id ORDER BY x.id) AS ids, max(x.id) AS max_id,
           array_agg(DISTINCT x.actor_user_id) FILTER (WHERE x.actor_user_id IS NOT NULL) AS actors
      FROM public.event_changes x
     WHERE NOT (x.consumed_by ? 'w1_b3') AND x.occurred_at <= p_now
     GROUP BY x.event_id
    HAVING max(x.occurred_at) <= p_now - p_settle OR min(x.occurred_at) <= p_now - p_max_wait
  LOOP
    v_ids := s.ids; v_max := s.max_id; v_actors := coalesce(s.actors, '{}');
    SELECT * INTO ev FROM public.events e WHERE e.id = s.event_id;
    IF NOT FOUND THEN
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      CONTINUE;
    END IF;
    v_tz := public.event_timezone(ev.id);
    v_series := NULL;
    IF ev.event_type = 'game' THEN SELECT g.series_id INTO v_series FROM public.games g WHERE g.event_id = ev.id; END IF;
    v_title_en := public.kan981_event_title(ev.id, 'en');
    v_title_ar := public.kan981_event_title(ev.id, 'ar');

    -- collapse: first old, last new, per field; drop fields that ended where they started
    SELECT coalesce(jsonb_object_agg(c.field, jsonb_build_object('o', c.o, 'n', c.n)), '{}'::jsonb) INTO v_c
      FROM (SELECT x.field,
                   (array_agg(x.old_value ORDER BY x.id))[1]      AS o,
                   (array_agg(x.new_value ORDER BY x.id DESC))[1] AS n
              FROM public.event_changes x WHERE x.id = ANY (v_ids) GROUP BY x.field) c
     WHERE c.o IS DISTINCT FROM c.n;

    -- cancel of a series occurrence (single events are sent at once by trg_game_updated_notify)
    IF ev.is_cancelled AND v_c ? 'is_cancelled' THEN
      SELECT max(x.id) INTO v_ec FROM public.event_changes x WHERE x.id = ANY (v_ids) AND x.field = 'is_cancelled';
      v_kind := CASE WHEN v_series IS NOT NULL THEN 'game.occurrence_cancelled' ELSE ev.event_type || '.cancelled' END;
      v_args := jsonb_build_object('title_en', v_title_en, 'title_ar', v_title_ar,
                                   'when_en', public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'en'),
                                   'when_ar', public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'ar'));
      FOR u IN SELECT r FROM public.kan981_recipients(ev.id) AS r WHERE r <> ALL (v_actors) LOOP
        v_id := public.notify_v2(u, v_kind, v_args, ev.event_type, ev.id, coalesce(v_actors[1], ev.creator_user_id),
                                 'event_changes:' || v_ec, 'w1_b3:cancel:' || v_ec, 'event:' || ev.id, NULL);
        IF v_id IS NOT NULL THEN v_sent := v_sent + 1; END IF;
      END LOOP;
      v_notices := v_notices + 1;
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      CONTINUE;
    END IF;

    -- a cancelled event gets no change notice; a past event neither
    IF ev.is_cancelled
       OR (ev.start_at < p_now AND coalesce((v_c #>> '{start_at,o}')::timestamptz, ev.start_at) < p_now) THEN
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      v_silent := v_silent + 1;
      CONTINUE;
    END IF;

    f_en := '{}'; f_ar := '{}'; o_en := '{}'; o_ar := '{}'; n_en := '{}'; n_ar := '{}';
    v_time := false; v_place := false;

    IF v_c ? 'start_at' OR v_c ? 'end_at' THEN
      o_start := CASE WHEN v_c ? 'start_at' THEN (v_c #>> '{start_at,o}')::timestamptz ELSE ev.start_at END;
      o_end   := CASE WHEN v_c ? 'end_at'   THEN (v_c #>> '{end_at,o}')::timestamptz   ELSE ev.end_at   END;
      v_time := true;
      f_en := f_en || public.kan981_value_label('field', 'time', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'time', 'ar');
      o_en := o_en || public.kan981_fmt_span(o_start, o_end, v_tz, 'en');
      o_ar := o_ar || public.kan981_fmt_span(o_start, o_end, v_tz, 'ar');
      n_en := n_en || public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'en');
      n_ar := n_ar || public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'ar');
    END IF;

    IF v_c ? 'venue_id' OR v_c ? 'area_id' OR v_c ? 'geo_location_id' THEN
      o_venue := CASE WHEN v_c ? 'venue_id' THEN (v_c #>> '{venue_id,o}')::uuid ELSE ev.venue_id END;
      o_area  := CASE WHEN v_c ? 'area_id'  THEN (v_c #>> '{area_id,o}')::uuid  ELSE ev.area_id  END;
      v_o := public.kan981_place_name(o_venue, o_area, 'en');
      v_n := public.kan981_place_name(ev.venue_id, ev.area_id, 'en');
      IF v_o IS DISTINCT FROM v_n THEN
        v_place := true;
        f_en := f_en || public.kan981_value_label('field', 'place', 'en');
        f_ar := f_ar || public.kan981_value_label('field', 'place', 'ar');
        o_en := o_en || v_o;
        n_en := n_en || v_n;
        o_ar := o_ar || public.kan981_place_name(o_venue, o_area, 'ar');
        n_ar := n_ar || public.kan981_place_name(ev.venue_id, ev.area_id, 'ar');
      END IF;
    END IF;

    IF v_c ? 'capacity' THEN
      f_en := f_en || public.kan981_value_label('field', 'capacity', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'capacity', 'ar');
      o_en := o_en || public.kan981_value_label('capacity', v_c #>> '{capacity,o}', 'en');
      o_ar := o_ar || public.kan981_value_label('capacity', v_c #>> '{capacity,o}', 'ar');
      n_en := n_en || public.kan981_value_label('capacity', ev.capacity::text, 'en');
      n_ar := n_ar || public.kan981_value_label('capacity', ev.capacity::text, 'ar');
    END IF;

    IF v_c ? 'join_policy' THEN
      f_en := f_en || public.kan981_value_label('field', 'join_policy', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'join_policy', 'ar');
      o_en := o_en || public.kan981_value_label('join_policy', v_c #>> '{join_policy,o}', 'en');
      o_ar := o_ar || public.kan981_value_label('join_policy', v_c #>> '{join_policy,o}', 'ar');
      n_en := n_en || public.kan981_value_label('join_policy', ev.join_policy, 'en');
      n_ar := n_ar || public.kan981_value_label('join_policy', ev.join_policy, 'ar');
    END IF;

    IF v_c ? 'joining_rule' OR v_c ? 'cost_cover' THEN
      v_o := coalesce(v_c #>> '{joining_rule,o}', ev.joining_rule);
      v_n := coalesce(v_c #>> '{cost_cover,o}', ev.cost_cover);
      f_en := f_en || public.kan981_value_label('field', 'joining_rule', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'joining_rule', 'ar');
      o_en := o_en || (public.kan981_value_label('joining_rule', v_o, 'en')
                       || CASE WHEN v_n <> v_o THEN ' (' || public.kan981_value_label('joining_rule', v_n, 'en') || ')' ELSE '' END);
      o_ar := o_ar || (public.kan981_value_label('joining_rule', v_o, 'ar')
                       || CASE WHEN v_n <> v_o THEN ' (' || public.kan981_value_label('joining_rule', v_n, 'ar') || ')' ELSE '' END);
      n_en := n_en || (public.kan981_value_label('joining_rule', ev.joining_rule, 'en')
                       || CASE WHEN ev.cost_cover <> ev.joining_rule
                               THEN ' (' || public.kan981_value_label('joining_rule', ev.cost_cover, 'en') || ')' ELSE '' END);
      n_ar := n_ar || (public.kan981_value_label('joining_rule', ev.joining_rule, 'ar')
                       || CASE WHEN ev.cost_cover <> ev.joining_rule
                               THEN ' (' || public.kan981_value_label('joining_rule', ev.cost_cover, 'ar') || ')' ELSE '' END);
    END IF;

    IF v_c ? 'min_skill' OR v_c ? 'max_skill' THEN
      v_o := CASE WHEN coalesce(v_c #>> '{min_skill,o}', ev.min_skill::text) IS NULL
                   AND coalesce(v_c #>> '{max_skill,o}', ev.max_skill::text) IS NULL THEN NULL
                  ELSE coalesce(CASE WHEN v_c ? 'min_skill' THEN v_c #>> '{min_skill,o}' ELSE ev.min_skill::text END, '1')
                       || '–' ||
                       coalesce(CASE WHEN v_c ? 'max_skill' THEN v_c #>> '{max_skill,o}' ELSE ev.max_skill::text END, '10') END;
      v_n := CASE WHEN ev.min_skill IS NULL AND ev.max_skill IS NULL THEN NULL
                  ELSE coalesce(ev.min_skill::text, '1') || '–' || coalesce(ev.max_skill::text, '10') END;
      f_en := f_en || public.kan981_value_label('field', 'skill', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'skill', 'ar');
      o_en := o_en || coalesce(v_o, 'Any');      o_ar := o_ar || coalesce(v_o, 'أي مستوى');
      n_en := n_en || coalesce(v_n, 'Any');      n_ar := n_ar || coalesce(v_n, 'أي مستوى');
    END IF;

    IF cardinality(f_en) = 0 THEN
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      v_silent := v_silent + 1;
      CONTINUE;
    END IF;

    v_kind := ev.event_type || CASE WHEN v_time THEN '.time_changed' WHEN v_place THEN '.venue_changed'
                                    ELSE '.details_changed' END;
    v_args := jsonb_build_object(
      'title_en', v_title_en, 'title_ar', v_title_ar,
      'field_en', array_to_string(f_en, ', '), 'field_ar', array_to_string(f_ar, '، '),
      'old_en', array_to_string(o_en, ' · '), 'old_ar', array_to_string(o_ar, ' · '),
      'new_en', array_to_string(n_en, ' · '), 'new_ar', array_to_string(n_ar, ' · '),
      'changes', (SELECT jsonb_agg(jsonb_build_object('field_en', f_en[i], 'field_ar', f_ar[i],
                                                      'old_en', o_en[i], 'old_ar', o_ar[i],
                                                      'new_en', n_en[i], 'new_ar', n_ar[i]) ORDER BY i)
                    FROM generate_subscripts(f_en, 1) AS i),
      'schedule_revision', ev.schedule_revision);

    FOR u IN SELECT r FROM public.kan981_recipients(ev.id) AS r WHERE r <> ALL (v_actors) LOOP
      v_id := public.notify_v2(u, v_kind, v_args, ev.event_type, ev.id,
                               coalesce(v_actors[array_upper(v_actors, 1)], ev.creator_user_id),
                               'event_changes:' || v_ids[1] || '-' || v_max,
                               'w1_b3:change:' || ev.id || ':' || v_max, 'event:' || ev.id, NULL);
      IF v_id IS NOT NULL THEN v_sent := v_sent + 1; END IF;
    END LOOP;
    v_notices := v_notices + 1;
    UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
  END LOOP;

  RETURN jsonb_build_object('notices', v_notices, 'series', v_series_n, 'silent', v_silent, 'sent', v_sent);
END
$function$;

DELETE FROM public.notification_kinds WHERE key = 'game.series_cancelled'
   AND NOT EXISTS (SELECT 1 FROM public.notifications n WHERE n.kind_key = 'game.series_cancelled');
UPDATE public.notification_kinds SET is_active = false WHERE key = 'game.series_cancelled';
COMMIT;
