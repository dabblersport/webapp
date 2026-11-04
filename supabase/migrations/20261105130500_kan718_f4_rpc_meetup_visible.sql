-- KAN-857 (KAN-718 follow-up F4, CTO ruling dreq-8ae9bcfa; Epic KAN-708): CONVERT public.rpc_meetup_visible()
-- (D01/D04 inventory #25) so it reads no public.meetups column that Z01 (20261105100000) drops.
--
-- PRE-IMAGE (baseline 20260829080500:14040-14047, never redefined since):
--   select m.id, m.title, m.starts_at, m.visibility, m.owner_user_id from public.meetups m order by m.starts_at
--   LANGUAGE sql STABLE, SECURITY INVOKER, search_path public, pg_temp.
--   meetups has NO starts_at / visibility / owner_user_id column (they are start_at / listing_visibility /
--   creator_user_id; KAN718_D04_DISPOSITION.md #25, meetups_hardening 20260915120000 header). The pre-image
--   therefore raises 42703 on every call, for every role, on every chain. Its INTENT is unambiguous: one row per
--   meetup the caller may see under meetups RLS, with title, start time, listing visibility and owner.
--
-- NEW BODY. Same signature, OUT names, LANGUAGE, volatility, SECURITY INVOKER and search_path. CREATE OR REPLACE
-- keeps the owner and the ACL (no GRANT/REVOKE here). Values and visibility come from public.kan718_meetups_compat
-- (D05, 20261104110200): title, start_at, listing_visibility and creator_user_id are taken from public.events
-- there, and its row filter is the meetups SELECT policy itself, i.e. the KAN-713 helper
-- public.kan713_meetup_visible(event_id) (plus can_view_owner on the events values, which is the same predicate),
-- or every row when the caller bypasses RLS, exactly as the table. A SECURITY INVOKER body cannot read
-- public.events directly: events is closed to anon/authenticated (KAN-710), so the D05 projection is the only
-- event-backed read path an invoker has without a new definer surface or a new grant.
-- The body references no public.meetups / public.games relation at all.
--
-- DEPENDENCY NOT IN THE CATALOGUE: a LANGUAGE sql body with $$ text records no pg_depend on the view. Retiring or
-- reshaping kan718_meetups_compat (columns id, title, start_at, listing_visibility, creator_user_id) must convert
-- this function first. The guard below refuses if the view is absent.
--
-- Proof (local throwaway PG16 only): supabase/tests/events_p4/kan718_f4_rpc_meetup_visible_test.sql.

DO $guard$
DECLARE v_missing text;
BEGIN
  IF to_regprocedure('public.rpc_meetup_visible()') IS NULL THEN
    RAISE EXCEPTION 'KAN-857: public.rpc_meetup_visible() is absent; nothing to convert';
  END IF;
  IF (SELECT prosecdef OR proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] OR prolang <> (SELECT oid FROM pg_language WHERE lanname = 'sql')
             OR provolatile <> 's' OR NOT proretset
        FROM pg_proc WHERE oid = 'public.rpc_meetup_visible()'::regprocedure) THEN
    RAISE EXCEPTION 'KAN-857: live rpc_meetup_visible() attributes differ from the pre-image (sql, STABLE, INVOKER, search_path public, pg_temp); re-derive';
  END IF;
  IF to_regclass('public.kan718_meetups_compat') IS NULL THEN
    RAISE EXCEPTION 'KAN-857: public.kan718_meetups_compat (D05, 20261104110200) is absent; apply it first';
  END IF;
  SELECT string_agg(c, ', ') INTO v_missing
    FROM unnest(ARRAY['id', 'title', 'start_at', 'listing_visibility', 'creator_user_id']) c
   WHERE NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.kan718_meetups_compat'::regclass AND attname = c AND NOT attisdropped);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-857: public.kan718_meetups_compat lacks %', v_missing;
  END IF;
END $guard$;

CREATE OR REPLACE FUNCTION public.rpc_meetup_visible()
 RETURNS TABLE(id uuid, title text, starts_at timestamp with time zone, visibility text, owner_user_id uuid)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $$
  select c.id, c.title, c.start_at, c.listing_visibility, c.creator_user_id
  from public.kan718_meetups_compat c
  order by c.start_at
$$;

DO $post$
BEGIN
  IF (SELECT prosecdef OR proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] OR provolatile <> 's'
        FROM pg_proc WHERE oid = 'public.rpc_meetup_visible()'::regprocedure) THEN
    RAISE EXCEPTION 'KAN-857 post: SECURITY mode / search_path / volatility changed';
  END IF;
  IF (SELECT prosrc ~ '(public\.meetups|public\.games|\mm\.)' FROM pg_proc WHERE oid = 'public.rpc_meetup_visible()'::regprocedure) THEN
    RAISE EXCEPTION 'KAN-857 post: body still reads public.meetups / public.games';
  END IF;
END $post$;
