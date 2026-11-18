-- KAN-997b: ratings hardening after PEER review. Function bodies are the live pg_get_functiondef text (md5 guarded).
-- 1. Stored scores are exactly what the user submitted. trg_norm_venue_scores (normalize_venue_scores, hard-coded to the
--    old keys facility/staff/lighting/cleanliness/value, filling missing keys with 4.5) is DROPPED with its trigger
--    function. rpc_rate_venue already validates every key against the active venue_rating_dimensions, and
--    venue_rating_recompute loops the active dimensions and counts a dimension only where the key is present, so a
--    skipped dimension stays absent and does not count. user_reputation_events had no normalizer (only the recompute
--    trigger). normalize_venue_scores(jsonb) itself is kept (no other caller) but no longer executable by clients.
-- 2. No public aggregate reveals an individual rating: reputation_recompute / venue_rating_recompute keep NO aggregate
--    row while the target has fewer than 3 distinct raters (the app reads a missing row as "not rated yet"; it reads
--    venue_rating_aggregate by embed and user_reputation_aggregate directly). v_reputation_leaderboard and
--    v_venue_dimension_by_district expose a row only with >= 3 distinct raters; v_reliable_teammate_candidates keeps
--    badge_rules min_count but never below 3, and also needs 3 distinct raters.
-- 3. did_not_happen Events are not ratable (ratings_window.ratable false; ratings_guard raises not_ratable).
-- 4. EXECUTE revoked from PUBLIC, anon, authenticated on the recompute / rebuild / can_rate_* functions (no lib/ caller;
--    every in-database caller is SECURITY DEFINER owned by postgres). service_role keeps EXECUTE.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.reputation_recompute(uuid)'::regprocedure)) <> '7f11fa15e722b7e7f2937eb8c102b54e'
     OR md5(pg_get_functiondef('public.venue_rating_recompute(uuid)'::regprocedure)) <> '36ef771a89cc672babbf584a0f87474f'
     OR md5(pg_get_functiondef('public.ratings_window(uuid)'::regprocedure)) <> '88c9e50e2d053fefda4b855eaa5237c9'
     OR md5(pg_get_functiondef('public.ratings_guard(uuid,uuid)'::regprocedure)) <> 'c8930766bcca3c320d99126048175d6a' THEN
    RAISE EXCEPTION 'kan997b pre-image: a ratings function changed since 20261118114339';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_norm_venue_scores'
                  AND tgrelid = 'public.venue_rating_events'::regclass) THEN
    RAISE EXCEPTION 'kan997b pre-image: trg_norm_venue_scores missing';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname <> 'trgfn_norm_venue_scores'
              AND prosrc ILIKE '%normalize_venue_scores%') THEN
    RAISE EXCEPTION 'kan997b pre-image: another caller of normalize_venue_scores';
  END IF;
END
$guard$;

-- 1. Scores as submitted ---------------------------------------------------------------------------------------------
DROP TRIGGER trg_norm_venue_scores ON public.venue_rating_events;
DROP FUNCTION public.trgfn_norm_venue_scores();

-- 2. Aggregates: no row below 3 distinct raters ----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reputation_recompute(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  prior_m numeric; prior_w int;
  dim record;
  sum_map jsonb := '{}'::jsonb;
  cnt_map jsonb := '{}'::jsonb;
  comp numeric := 0.0;
  total_w numeric := 0.0;
  dim_sum numeric; dim_cnt numeric; dim_mean numeric;
  evt_count int;
begin
  -- KAN-997b: fewer than 3 distinct raters -> no public aggregate at all
  if (select count(distinct e.rater_user_id) from public.user_reputation_events e where e.ratee_user_id = p_user_id) < 3 then
    delete from public.user_reputation_aggregate where user_id = p_user_id;
    return;
  end if;

  select prior_mean, prior_weight into prior_m, prior_w from public.reputation_config where id=true;

  for dim in select key, weight from public.reputation_dimensions where is_active loop
    select
      coalesce(sum( public._clamp_star((e.scores ->> dim.key)::numeric) * public.reputation_decay_factor(e.created_at) ), 0.0),
      coalesce(sum( case when e.scores ? dim.key then public.reputation_decay_factor(e.created_at) else 0 end ), 0.0)
    into dim_sum, dim_cnt
    from public.user_reputation_events e
    where e.ratee_user_id = p_user_id;

    sum_map := sum_map || jsonb_build_object(dim.key, round(dim_sum::numeric,3));
    cnt_map := cnt_map || jsonb_build_object(dim.key, round(dim_cnt::numeric,3));

    dim_mean := case when (prior_w + dim_cnt) > 0
                     then (prior_m * prior_w + dim_sum) / (prior_w + dim_cnt)
                     else prior_m
                end;

    comp := comp + coalesce(dim.weight,0.0) * dim_mean;
    total_w := total_w + coalesce(dim.weight,0.0);
  end loop;

  if total_w > 0 then comp := comp / total_w; else comp := prior_m; end if;

  select count(*) into evt_count from public.user_reputation_events where ratee_user_id=p_user_id;

  insert into public.user_reputation_aggregate(user_id,event_count,dim_sums,dim_counts,composite_score,last_event_at,updated_at)
  values (
    p_user_id, evt_count, sum_map, cnt_map, round(comp::numeric,2),
    (select max(created_at) from public.user_reputation_events where ratee_user_id=p_user_id),
    now()
  )
  on conflict (user_id) do update set
    event_count     = excluded.event_count,
    dim_sums        = excluded.dim_sums,
    dim_counts      = excluded.dim_counts,
    composite_score = excluded.composite_score,
    last_event_at   = excluded.last_event_at,
    updated_at      = excluded.updated_at;
end;
$function$;

CREATE OR REPLACE FUNCTION public.venue_rating_recompute(p_venue_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  cfg record;
  dim record;
  dim_sum numeric; dim_cnt numeric; dim_mean numeric;
  sum_map jsonb := '{}'::jsonb;
  cnt_map jsonb := '{}'::jsonb;
  comp numeric := 0.0; total_w numeric := 0.0;
  evt_count int;
begin
  -- KAN-997b: fewer than 3 distinct raters -> no public aggregate at all
  if (select count(distinct e.rater_user_id) from public.venue_rating_events e where e.venue_id = p_venue_id) < 3 then
    delete from public.venue_rating_aggregate where venue_id = p_venue_id;
    return;
  end if;

  select * into cfg from public._get_context_config('venue');

  for dim in select key, weight from public.venue_rating_dimensions where is_active loop
    select
      coalesce(sum( public._clamp_star((e.scores ->> dim.key)::numeric) *
                    public._decay_factor(e.created_at, cfg.half_life_days) ), 0.0),
      coalesce(sum( case when e.scores ? dim.key then public._decay_factor(e.created_at, cfg.half_life_days) else 0 end ), 0.0)
    into dim_sum, dim_cnt
    from public.venue_rating_events e
    where e.venue_id = p_venue_id;

    sum_map := sum_map || jsonb_build_object(dim.key, round(dim_sum::numeric,3));
    cnt_map := cnt_map || jsonb_build_object(dim.key, round(dim_cnt::numeric,3));

    dim_mean := case when (cfg.prior_weight + dim_cnt) > 0
                     then (cfg.prior_mean * cfg.prior_weight + dim_sum) / (cfg.prior_weight + dim_cnt)
                     else cfg.prior_mean
                end;

    comp := comp + coalesce(dim.weight,0.0) * dim_mean;
    total_w := total_w + coalesce(dim.weight,0.0);
  end loop;

  if total_w > 0 then comp := comp / total_w; else comp := coalesce(cfg.prior_mean,4.5); end if;

  select count(*) into evt_count from public.venue_rating_events where venue_id=p_venue_id;

  insert into public.venue_rating_aggregate(venue_id,event_count,dim_sums,dim_counts,composite_score,last_event_at,updated_at)
  values (
    p_venue_id, evt_count, sum_map, cnt_map, round(comp::numeric,2),
    (select max(created_at) from public.venue_rating_events where venue_id=p_venue_id),
    now()
  )
  on conflict (venue_id) do update set
    event_count     = excluded.event_count,
    dim_sums        = excluded.dim_sums,
    dim_counts      = excluded.dim_counts,
    composite_score = excluded.composite_score,
    last_event_at   = excluded.last_event_at,
    updated_at      = excluded.updated_at;
end;
$function$;

-- Existing aggregate rows below the floor go now (rebuilt through the gated recompute).
DELETE FROM public.user_reputation_aggregate a
 WHERE (SELECT count(DISTINCT e.rater_user_id) FROM public.user_reputation_events e WHERE e.ratee_user_id = a.user_id) < 3;
DELETE FROM public.venue_rating_aggregate a
 WHERE (SELECT count(DISTINCT e.rater_user_id) FROM public.venue_rating_events e WHERE e.venue_id = a.venue_id) < 3;

CREATE OR REPLACE VIEW public.v_reputation_leaderboard AS
 SELECT ratee_user_id AS user_id,
    round(avg(((scores ->> 'sportsmanship'::text))::numeric), 2) AS sportsmanship_avg,
    round(avg(((scores ->> 'reliability'::text))::numeric), 2) AS reliability_avg,
    count(*) AS ratings_count
   FROM user_reputation_events e
  WHERE (created_at > (now() - '90 days'::interval))
  GROUP BY ratee_user_id
 HAVING count(DISTINCT rater_user_id) >= 3
  ORDER BY (count(*)) DESC;

CREATE OR REPLACE VIEW public.v_venue_dimension_by_district AS
 SELECT a.name AS district,
    v.id AS venue_id,
    v.name_en,
    k.key AS dimension_key,
    round(avg(((vre.scores ->> k.key))::numeric), 3) AS avg_score,
    count(DISTINCT vre.id) FILTER (WHERE (vre.scores ? k.key)) AS ratings_count
   FROM ((((venues v
     JOIN areas a ON ((a.id = v.area_id)))
     JOIN venue_spaces s ON ((s.venue_id = v.id)))
     JOIN venue_rating_events vre ON ((vre.venue_id = v.id)))
     JOIN venue_rating_dimensions k ON ((k.is_active = true)))
  GROUP BY a.name, v.id, v.name_en, k.key
 HAVING count(DISTINCT vre.rater_user_id) FILTER (WHERE (vre.scores ? k.key)) >= 3;

CREATE OR REPLACE VIEW public.v_reliable_teammate_candidates AS
 WITH cfg AS (
         SELECT COALESCE(( SELECT ((badge_rules.params ->> 'window_days'::text))::integer AS int4
                   FROM badge_rules
                  WHERE (badge_rules.badge_key = 'reliable_teammate'::text)
                 LIMIT 1), 90) AS window_days,
            GREATEST(COALESCE(( SELECT ((badge_rules.params ->> 'min_count'::text))::integer AS int4
                   FROM badge_rules
                  WHERE (badge_rules.badge_key = 'reliable_teammate'::text)
                 LIMIT 1), 8), 3) AS min_count,
            COALESCE(( SELECT ((badge_rules.params ->> 'min_avg'::text))::numeric AS "numeric"
                   FROM badge_rules
                  WHERE (badge_rules.badge_key = 'reliable_teammate'::text)
                 LIMIT 1), 4.6) AS min_avg
        ), agg AS (
         SELECT e.ratee_user_id AS user_id,
            round(avg(((e.scores ->> 'reliability'::text))::numeric), 3) AS avg_score,
            count(*) FILTER (WHERE (e.scores ? 'reliability'::text)) AS ratings_count,
            count(DISTINCT e.rater_user_id) FILTER (WHERE (e.scores ? 'reliability'::text)) AS raters
           FROM user_reputation_events e,
            cfg cfg_1
          WHERE (e.created_at >= (now() - ((( SELECT cfg_2.window_days
                   FROM cfg cfg_2) || ' days'::text))::interval))
          GROUP BY e.ratee_user_id
        )
 SELECT agg.user_id,
    agg.avg_score,
    agg.ratings_count,
    cfg.window_days,
    cfg.min_count,
    cfg.min_avg
   FROM agg,
    cfg
  WHERE ((agg.ratings_count >= cfg.min_count) AND (agg.raters >= 3) AND (agg.avg_score >= cfg.min_avg));

-- 3. did_not_happen is not ratable -----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ratings_window(p_event_id uuid, OUT ratable boolean, OUT opens_at timestamp with time zone, OUT closes_at timestamp with time zone, OUT organiser uuid, OUT venue_id uuid, OUT event_type text, OUT game_id uuid)
 RETURNS record
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; v_dnh boolean; v_lc_dnh boolean;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  event_type := ev.event_type; organiser := ev.organiser;
  game_id := CASE WHEN ev.event_type = 'game' THEN ev.entity_id END;
  SELECT e.venue_id INTO venue_id FROM public.events e WHERE e.id = p_event_id;
  SELECT f.finalized_at, f.reason IS NOT DISTINCT FROM 'did_not_happen' INTO opens_at, v_dnh
    FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id;
  SELECT l.effective_end_at + interval '48 hours', l.state IS NOT DISTINCT FROM 'did_not_happen'
    INTO closes_at, v_lc_dnh FROM public.event_lifecycle_state(p_event_id) l;
  closes_at := COALESCE(closes_at, ev.end_at + interval '48 hours');
  ratable := ev.event_type IN ('game', 'meetup') AND NOT COALESCE(ev.is_cancelled, false) AND opens_at IS NOT NULL
             AND NOT COALESCE(v_dnh, false) AND NOT COALESCE(v_lc_dnh, false);
END;
$function$;

CREATE OR REPLACE FUNCTION public.ratings_guard(p_event_id uuid, p_uid uuid, OUT closes_at timestamp with time zone, OUT organiser uuid, OUT venue_id uuid, OUT game_id uuid)
 RETURNS record
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE w record;
BEGIN
  IF p_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO w FROM public.ratings_window(p_event_id);
  IF w.event_type IS NULL OR w.event_type NOT IN ('game', 'meetup') OR EXISTS (
       SELECT 1 FROM public.events e WHERE e.id = p_event_id AND COALESCE(e.is_cancelled, false)) THEN
    RAISE EXCEPTION 'not_ratable';
  END IF;
  -- KAN-997b: an Event that did not happen is never ratable
  IF EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id AND f.reason = 'did_not_happen')
     OR EXISTS (SELECT 1 FROM public.event_lifecycle_state(p_event_id) l WHERE l.state = 'did_not_happen') THEN
    RAISE EXCEPTION 'not_ratable';
  END IF;
  IF NOT w.ratable OR now() < w.opens_at THEN RAISE EXCEPTION 'window_not_open'; END IF;
  IF now() > w.closes_at THEN RAISE EXCEPTION 'window_closed'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ratings_eligible(p_event_id) u WHERE u = p_uid) THEN
    RAISE EXCEPTION 'not_eligible';
  END IF;
  closes_at := w.closes_at; organiser := w.organiser; venue_id := w.venue_id; game_id := w.game_id;
END;
$function$;

-- 4. Grants ----------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.reputation_recompute(uuid), public.venue_rating_recompute(uuid),
  public.game_rating_recompute(uuid), public.reputation_rebuild_all(), public.venue_rating_rebuild_all(),
  public.game_rating_rebuild_all(), public.can_rate_user(uuid), public.can_rate_venue(uuid),
  public.normalize_venue_scores(jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reputation_recompute(uuid), public.venue_rating_recompute(uuid),
  public.game_rating_recompute(uuid), public.reputation_rebuild_all(), public.venue_rating_rebuild_all(),
  public.game_rating_rebuild_all(), public.can_rate_user(uuid), public.can_rate_venue(uuid),
  public.normalize_venue_scores(jsonb)
  TO service_role;

-- 5. Post-image ------------------------------------------------------------------------------------------------------
DO $post$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(p.oid::regprocedure::text || ' ' || COALESCE(p.proacl::text, 'NULL'), '; ') INTO v_bad
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('reputation_recompute', 'venue_rating_recompute', 'game_rating_recompute', 'reputation_rebuild_all',
                       'venue_rating_rebuild_all', 'game_rating_rebuild_all', 'can_rate_user', 'can_rate_venue',
                       'normalize_venue_scores')
     AND (p.proacl IS NULL OR p.proacl::text LIKE '%anon=%' OR p.proacl::text LIKE '%authenticated=%'
          OR p.proacl::text LIKE '{=%' OR p.proacl::text LIKE '%,=%' OR p.proacl::text NOT LIKE '%service_role=X%'
          OR pg_get_userbyid(p.proowner) <> 'postgres');
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'kan997b post-image: ACL: %', v_bad; END IF;
  SELECT string_agg(p.oid::regprocedure::text, '; ') INTO v_bad FROM pg_proc p
   WHERE p.oid IN ('public.reputation_recompute(uuid)'::regprocedure, 'public.venue_rating_recompute(uuid)'::regprocedure)
     AND (NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public']);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'kan997b post-image: recompute attributes: %', v_bad; END IF;
  SELECT string_agg(p.oid::regprocedure::text, '; ') INTO v_bad FROM pg_proc p
   WHERE p.oid IN ('public.ratings_window(uuid)'::regprocedure, 'public.ratings_guard(uuid,uuid)'::regprocedure)
     AND (NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
          OR p.proacl::text LIKE '%anon=%' OR p.proacl::text LIKE '%authenticated=%' OR p.proacl::text LIKE '{=%');
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'kan997b post-image: ratings helper attributes: %', v_bad; END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.venue_rating_events'::regclass AND tgname = 'trg_norm_venue_scores')
     OR to_regproc('public.trgfn_norm_venue_scores') IS NOT NULL THEN
    RAISE EXCEPTION 'kan997b post-image: venue score normalizer still present';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal AND tgrelid = 'public.user_reputation_events'::regclass
              AND tgfoid <> 'public.trg_after_reputation_event()'::regprocedure) THEN
    RAISE EXCEPTION 'kan997b post-image: an unexpected trigger on user_reputation_events';
  END IF;
END
$post$;
