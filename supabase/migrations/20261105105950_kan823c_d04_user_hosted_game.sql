-- KAN-888 (KAN-823 supplement "823c"; follows KAN-886 / step 29a, Epic KAN-708): deliver the KAN-772 D04 bodies
-- of public._user_hosted_game(uuid,uuid), public._recent_activity_score(uuid,integer) and
-- public.game_is_joinable(uuid), which no file in the release chain delivers to production.
--
-- AUTHORED, NOT APPLIED. needs-ops: applied by Memphis (D-043) after review (schema_change).
-- Release order: after 20261105105900_kan823b_d04_meetup_counts.sql (step 29a), before
-- 20261105110000_kan714_events_parent_reads_2.sql (step 30, applied unchanged).
--
-- WHY. KAN792_PIN_AUDIT.md:163 (H3) records the D04 step-25 change to _user_hosted_game (pre dc84da3e -> post
-- 41a0f3b1). Production still runs the pre-D04 body (md5(prosrc) dc84da3e337f875afecad11c80bf6e2e), because
-- KAN-772's file fails closed on production and KAN-823 (20261105120000:34) excludes it. 20261105110000 (part 2,
-- origin/staging, :184) pins _user_hosted_game at the D04 post-image 41a0f3b1..., and
-- 20261104112100_kan834_d04_residual_c.sql (:69-71) accepts only the KAN-772 post-images of all three as its
-- pre-image. Both fail closed until this file has run.
--
-- C1. _user_hosted_game: KAN-772 body VERBATIM, 20261104110100_kan718_d04_last_shared_field_reads.sql:138-159
--     (CREATE OR REPLACE through the closing $function$). Prosrc md5 proved = 41a0f3b192055a68f7dbaea2807c9933
--     on a scratch Postgres 16 (not Supabase).
--
-- C2/C3. The other two un-delivered KAN-772 INVOKER functions. Live pre-images read by Memphis on 2026-11-06
--     (prefixes ab433ed3 / 186286ad); full values = KAN-772 pre-image pins 20261104110100:84/:85, also listed in
--     20261105105900:26-27. Compared with the KAN-772 post-image:
--
--   function                          measured live md5(prosrc)          KAN-772 post-image md5             replaced
--   _user_hosted_game(uuid,uuid)      dc84da3e337f875afecad11c80bf6e2e   41a0f3b192055a68f7dbaea2807c9933   YES (:138-159)
--   _recent_activity_score(uuid,int)  ab433ed36ceb91e748ddabb252505d14   6cec16401372d08e38d17e74d68ec322   YES (:161-193)
--   game_is_joinable(uuid)            186286ad1e096c062296d0bc1b2f5890   a7245a8bc76da50e56cb011fca0f4797   YES (:195-218)
--
--     Both drifted (live = KAN-772 PRE-image, not its post-image), so both are replaced with the KAN-772 body
--     verbatim under the same guard and assertion as _user_hosted_game.
--
-- Pre-image attributes (baseline 20260829080500:1493-1510, :1715-1727, :6812-6821; KAN-772 guard :83-85):
-- LANGUAGE sql, SECURITY INVOKER (prosecdef false), STABLE (provolatile 's'), search_path=public, pg_temp,
-- owner postgres. The post-image is LANGUAGE plpgsql with the same SECURITY, volatility and search_path
-- (KAN-772 header :32-39 explains the sql -> plpgsql move).
--
-- Guard (section 0) refuses unless every md5(prosrc), prosecdef, provolatile and proconfig equal the live
-- pre-image, and records oid, owner and ACL. Section 2 asserts each md5 = post-image and oid, owner, ACL and
-- attributes unchanged. One transaction, CREATE OR REPLACE only (same signature, so oid, owner and ACL are kept);
-- no DROP, no table, column, grant or policy change and no row written.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Guard. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
begin
  if to_regclass('public.events') is null then
    raise exception 'KAN-888 pre: public.events missing (KAN-710 not applied)';
  end if;

  -- Pre-image pin: md5(prosrc) | SECURITY DEFINER | volatility | proconfig
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|' || p.proconfig::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public._user_hosted_game(uuid,uuid)',         'dc84da3e337f875afecad11c80bf6e2e', false, 's'),
      ('public._recent_activity_score(uuid,integer)', 'ab433ed36ceb91e748ddabb252505d14', false, 's'),
      ('public.game_is_joinable(uuid)',               '186286ad1e096c062296d0bc1b2f5890', false, 's')
    ) t(f, src, secdef, vol)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src or p.prosecdef <> t.secdef or p.provolatile <> t.vol
      or p.proconfig is distinct from array['search_path=public, pg_temp'];
  if v_bad is not null then
    raise exception 'KAN-888 pre: pre-image drift (re-author from pg_get_functiondef on this catalogue): %', v_bad;
  end if;
end
$pre$;

-- Capture oid, owner, ACL and attributes (dropped at commit) for section 2.
create temp table kan888_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, p.proowner, p.proacl,
       concat_ws('|', pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef,
                 p.provolatile, p.proretset, p.proisstrict, p.proparallel, p.proconfig::text) as attr
  from pg_proc p
 where p.oid in (to_regprocedure('public._user_hosted_game(uuid,uuid)'),
                 to_regprocedure('public._recent_activity_score(uuid,integer)'),
                 to_regprocedure('public.game_is_joinable(uuid)'));

-- ---------------------------------------------------------------------------------------------------------
-- 1. Replacements: KAN-772 bodies verbatim (20261104110100:138-159, :161-193, :195-218).
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._user_hosted_game(p_user_id uuid, p_game_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: creator from events for callers that may read events (rpc_rate_venue, SECURITY DEFINER);
-- pre-image read otherwise (INVOKER, granted to clients; events has no client grant -- KAN-727 pattern).
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    RETURN EXISTS (
      SELECT 1 FROM public.games g
        JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       WHERE g.id = p_game_id
         AND e.creator_user_id = p_user_id);
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.games g
     WHERE g.id = p_game_id
       AND g.creator_user_id = p_user_id);
END
$function$;

CREATE OR REPLACE FUNCTION public._recent_activity_score(u uuid, p_recent_days integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: start_at from events for callers that may read events; pre-image read otherwise (INVOKER).
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    IF EXISTS (
      SELECT 1
        FROM public.game_roster gr
        JOIN public.games g ON g.id = gr.game_id
        JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       WHERE gr.user_id = u
         AND gr.status = 'active'
         AND e.start_at >= now() - (p_recent_days || ' days')::interval) THEN
      RETURN 1.0;
    END IF;
    RETURN 0.0;
  END IF;
  IF EXISTS (
    SELECT 1
      FROM public.game_roster gr
      JOIN public.games g ON g.id = gr.game_id
     WHERE gr.user_id = u
       AND gr.status = 'active'
       AND g.start_at >= now() - (p_recent_days || ' days')::interval) THEN
    RETURN 1.0;
  END IF;
  RETURN 0.0;
END
$function$;

CREATE OR REPLACE FUNCTION public.game_is_joinable(p_game uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: cancel state and start from events for callers that may read events; pre-image read otherwise
-- (INVOKER). An unknown game returns NULL, as the pre-image's one-row SQL select did.
DECLARE
  v boolean;
BEGIN
  IF has_table_privilege('public.events', 'SELECT') THEN
    SELECT NOT e.is_cancelled AND e.start_at > now() INTO v
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
     WHERE g.id = p_game;
  ELSE
    SELECT NOT g.is_cancelled AND g.start_at > now() INTO v
      FROM public.games g
     WHERE g.id = p_game;
  END IF;
  RETURN v;
END
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Post-assertion.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  r record;
  n int := 0;
begin
  for r in
    select t.f, t.h, p.oid, p.prosrc, p.proowner, p.proacl,
           concat_ws('|', pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef,
                     p.provolatile, p.proretset, p.proisstrict, p.proparallel, p.proconfig::text) as attr,
           k.oid as pre_oid, k.proowner as pre_owner, k.proacl as pre_acl, k.attr as pre_attr
      from (values
        ('public._user_hosted_game(uuid,uuid)',         '41a0f3b192055a68f7dbaea2807c9933'),
        ('public._recent_activity_score(uuid,integer)', '6cec16401372d08e38d17e74d68ec322'),
        ('public.game_is_joinable(uuid)',               'a7245a8bc76da50e56cb011fca0f4797')
      ) t(f, h)
      left join pg_proc p on p.oid = to_regprocedure(t.f)
      left join kan888_pre k on k.oid = p.oid
  loop
    if r.oid is null then
      raise exception 'KAN-888 post: % absent', r.f;
    end if;
    if md5(r.prosrc) <> r.h then
      raise exception 'KAN-888 post: % md5(prosrc) is %, expected %', r.f, md5(r.prosrc), r.h;
    end if;
    if r.pre_oid is null then
      raise exception 'KAN-888 post: % oid changed (not in pre capture)', r.f;
    end if;
    if r.proowner <> r.pre_owner then
      raise exception 'KAN-888 post: % owner changed (% -> %)', r.f, r.pre_owner::regrole, r.proowner::regrole;
    end if;
    if r.proacl is distinct from r.pre_acl then
      raise exception 'KAN-888 post: % ACL changed (% -> %)', r.f, r.pre_acl, r.proacl;
    end if;
    if r.attr <> r.pre_attr then
      raise exception 'KAN-888 post: % attributes changed (% -> %)', r.f, r.pre_attr, r.attr;
    end if;
    n := n + 1;
  end loop;
  if n <> 3 then
    raise exception 'KAN-888 post: expected 3 functions checked, got %', n;
  end if;
end
$post$;

commit;
