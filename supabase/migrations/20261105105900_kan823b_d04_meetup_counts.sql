-- KAN-885 (KAN-823 supplement "823b"; supports KAN-871 / KAN-718 D04, Epic KAN-708): deliver the KAN-772 D04 body
-- of public.meetup_counts(uuid), which no file in the release chain delivers to production.
--
-- AUTHORED, NOT APPLIED. needs-ops: applied by the applying seat under G-002 after PEER review (schema_change).
-- Release order: step 29a of the KAN-811 order -- after KAN-870 (step 29), before KAN-871 (step 30,
-- 20261105110000_kan714_events_parent_reads_2.sql, applied unchanged). Ruling: CTO dreq-85666936 (dec-871).
--
-- WHY. 20261105110000 pins public.meetup_counts(uuid) at the KAN-772 post-image (e5982fbd...). Production runs the
-- KAN-772 PRE-image (ec29fe4c..., = 20261104110100_kan718_d04_last_shared_field_reads.sql:88), because KAN-772's
-- file fails closed on production (rpc_create_* pre-image drift) and KAN-823 (20261105120000:33-35) excludes
-- meetup_counts. This file applies KAN-772's meetup_counts body VERBATIM (20261104110100:308-324, the text between
-- the dollar-quote tags) and nothing else. Signature, RETURNS TABLE, LANGUAGE sql, SECURITY DEFINER, VOLATILE and
-- search_path are the live function's (pg_get_functiondef on wtncuzcskpigqpmnxwws, read-only, 2026-11-05; its
-- prosrc md5 recomputed = ec29fe4c662d0c6fbe1117a5d01a7652).
--
--   function              pre-image md5(prosrc)              post-image md5(prosrc)
--   meetup_counts(uuid)   ec29fe4c662d0c6fbe1117a5d01a7652   e5982fbdee8d94c8de2c827a370038c5
--
-- Guard (section 0) refuses unless md5(prosrc) = pre-image, SECURITY DEFINER, volatility 'v', search_path pinned;
-- it records owner and ACL. Section 2 asserts md5 = post-image and oid/owner/ACL/attributes unchanged. One
-- transaction, CREATE OR REPLACE only (same signature, so oid, owner and ACL are kept); no table, column, grant or
-- policy change and no row written. Class A.
--
-- READ-ONLY CHECK OF THE OTHER TWO UN-DELIVERED KAN-772 FUNCTIONS (not changed here):
--   function                            KAN-772 pre-image (:84/:85)         KAN-772 post-image (body md5)
--   _recent_activity_score(uuid,int)    ab433ed36ceb91e748ddabb252505d14   6cec16401372d08e38d17e74d68ec322 (:161-193)
--   game_is_joinable(uuid)              186286ad1e096c062296d0bc1b2f5890   a7245a8bc76da50e56cb011fca0f4797 (:195-219)
--   Live production md5: NOT OBTAINED. The read-only SELECT on pg_proc was refused by the ops guard (D-042,
--   execute_sql reserved to Memphis); only pg_get_functiondef(meetup_counts) returned. Result per function:
--   UNKNOWN -- the applying seat must read md5(prosrc) for both before step 29a.
--   Later pins (grep of supabase/migrations): 20261104112100_kan834_d04_residual_c.sql:69/:71 pins BOTH, accepting
--   only the KAN-772 post-image (6cec1640 / a7245a8b) or its own post-image (2202f744 / 7075cd9e), else RAISE. If
--   production still runs the KAN-772 PRE-images, KAN-834 fails closed and the two functions must join this step
--   (ruling: "if either is pinned later, it joins 29a") -- that needs a CTO/PO decision, not made here. No other
--   file after 20261105105900 pins either (only a comment in 20261105120000:34); z05 (20261105100100) lists them
--   without an md5 pin. _user_hosted_game: untouched (KAN-871 part 2 check passed).

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
    raise exception 'KAN-885 pre: public.events missing (KAN-710 not applied)';
  end if;
  if to_regprocedure('public.can_view_owner(uuid,text)') is null then
    raise exception 'KAN-885 pre: public.can_view_owner(uuid,text) missing';
  end if;

  -- Pre-image pin: md5(prosrc) | SECURITY DEFINER | volatility | proconfig (same measure as KAN-772 / KAN-823)
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|' || p.proconfig::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public.meetup_counts(uuid)', 'ec29fe4c662d0c6fbe1117a5d01a7652', true, 'v')
    ) t(f, src, secdef, vol)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src or p.prosecdef <> t.secdef or p.provolatile <> t.vol
      or p.proconfig is distinct from array['search_path=public, pg_temp'];
  if v_bad is not null then
    raise exception 'KAN-885 pre: pre-image drift (re-author from pg_get_functiondef on this catalogue): %', v_bad;
  end if;

  -- Capture oid, owner and ACL (transaction-local) for section 2.
  perform set_config('kan885.pre_oid',   p.oid::text, true),
          set_config('kan885.pre_owner', p.proowner::text, true),
          set_config('kan885.pre_acl',   coalesce(p.proacl::text, '<null>'), true),
          set_config('kan885.pre_attr',  concat_ws('|', pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                                   p.prolang, p.proretset, p.proisstrict, p.proparallel, p.proconfig::text), true)
     from pg_proc p
    where p.oid = to_regprocedure('public.meetup_counts(uuid)');
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Replacement: KAN-772 body verbatim (20261104110100:308-324).
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.meetup_counts(p_meetup_id uuid)
 RETURNS TABLE(going integer, interested integer, declined integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-772: visibility gate from events (as KAN-721 B02's v_meetup_counts).
  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  left join public.meetup_rsvps r on r.meetup_id = m.id
  where m.id = p_meetup_id
    and public.can_view_owner(e.creator_user_id, e.listing_visibility)
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Post-assertion.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  p record;
begin
  select * into p from pg_proc where oid = to_regprocedure('public.meetup_counts(uuid)');
  if p.oid is null then
    raise exception 'KAN-885 post: public.meetup_counts(uuid) absent';
  end if;
  if md5(p.prosrc) <> 'e5982fbdee8d94c8de2c827a370038c5' then
    raise exception 'KAN-885 post: md5(prosrc) is %, expected e5982fbdee8d94c8de2c827a370038c5', md5(p.prosrc);
  end if;
  if p.oid::text <> current_setting('kan885.pre_oid') then
    raise exception 'KAN-885 post: oid changed (% -> %)', current_setting('kan885.pre_oid'), p.oid;
  end if;
  if p.proowner::text <> current_setting('kan885.pre_owner') then
    raise exception 'KAN-885 post: owner changed (% -> %)', current_setting('kan885.pre_owner'), p.proowner;
  end if;
  if coalesce(p.proacl::text, '<null>') <> current_setting('kan885.pre_acl') then
    raise exception 'KAN-885 post: ACL changed (% -> %)', current_setting('kan885.pre_acl'), p.proacl;
  end if;
  if not p.prosecdef or p.provolatile <> 'v'
     or concat_ws('|', pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prolang, p.proretset,
                  p.proisstrict, p.proparallel, p.proconfig::text) <> current_setting('kan885.pre_attr') then
    raise exception 'KAN-885 post: attributes changed';
  end if;
end
$post$;

commit;
