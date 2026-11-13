-- KAN-872 (supports KAN-865, Events Epic KAN-708): F12 owner-scoped retention cleanup and export over public.events.
-- CTO ruling dreq-9da13118 option (a): server-side SECURITY DEFINER retention, no client DELETE on events.
--
-- AUTHORED, NOT APPLIED BY THIS TICKET. Local proof only (throwaway PG16, events chain from
-- supabase/tests/events_p2/build_kan788.sh). Additive: two new functions, no DROP, no table/column/view change,
-- no grant on public.events (it stays RLS FORCED, zero policies, zero client grants: kan710:98-102).
--
-- Why SECURITY DEFINER: anon/authenticated hold no privilege on public.events, so an INVOKER function could not
-- read or delete it. Both functions are owned by postgres (BYPASSRLS), pin search_path to '' and schema-qualify
-- every object (auth.uid(), public.*, pg_catalog.now()).
--
-- OWNER RULE (both functions): public.events.creator_user_id = auth.uid(). Never creator_profile_id. A null
-- auth.uid() raises 28000 and touches nothing.
--
-- retention_cleanup_own_events(p_cutoff timestamptz) RETURNS integer (rows of public.events deleted)
--   FLOOR: CLAMP, not reject. effective cutoff = least(p_cutoff, now() - interval '2 years'). A caller asking for
--     a newer cutoff silently gets the 2-year floor, so nothing younger than 2 years is ever deleted. A null
--     p_cutoff raises 22004 (least() ignores NULL, which would otherwise mean "use the floor" by accident).
--   AGE: an event is older than the cutoff only when BOTH created_at < cutoff AND coalesce(end_at, start_at) <
--     cutoff. created_at alone would delete an event created long ago but scheduled for the future (and series
--     occurrences are created ahead of time); start/end alone would delete a row created recently with a past
--     date. Requiring both is the conservative reading. end_at is null only for some meetups (games require it:
--     events_game_end_required), so start_at stands in. KAN-711 backfill copied created_at from the legacy rows
--     (parity-checked, kan711_events_backfill.sql:127), so it is the real creation time.
--   DEPENDENT ROWS: public.events is referenced only by games.event_id / meetups.event_id, both ON DELETE CASCADE
--     (kan710:281-284). Deleting the parent removes the subtype row, which cascades on the production schema to
--     game_roster, game_invites, game_join_requests, game_link_tokens, game_waitlist, game_rating_*,
--     activity_events, user_reputation_events, venue_rating_events, meetup_rsvps, meetup_attendees,
--     meetup_invites, meetup_link_tokens, favorites (baseline FKs, all CASCADE). The KAN-712 AFTER DELETE triggers
--     on games/meetups then match 0 events rows (kan712_events_write_contract.sql:32-33). Two exceptions, decided:
--     (1) MONEY: an event whose game has a public.game_settlements row is SKIPPED, never deleted.
--         game_settlements_game_id_fkey is ON DELETE CASCADE, so deleting the game would silently destroy a
--         settlement record; retention of a user's own events must not erase financial history.
--     (2) NON-CASCADING REFERENCES: posts.game_id, msg_conversations.game_id and the meetup chat registry are
--         plain (NO ACTION) FKs. Each event is deleted in its own subtransaction; a foreign_key_violation or
--         restrict_violation skips THAT event (it is kept, with everything under it) and the loop continues, so
--         one referenced event never blocks the rest. Any other error aborts the whole call (atomic).
--   The count returned is the number of public.events rows deleted (skipped events are not counted).
--
-- export_own_events() RETURNS TABLE(...) — the caller's own events, read-only (STABLE).
--   event_id, event_type, title, description, start_at, end_at, created_at, is_cancelled, cancelled_at,
--   cancelled_reason, request_id are public.events columns, EXCEPT description: events has no description
--   column (kan710:22-47) and games never had one; it lives on the meetups subtype (meetups.description).
--   It is read as to_jsonb(m) ->> 'description' so the function keeps working (returning NULL) if KAN-719 Z01
--   (20261105100000, seq 704, gated) ever drops that column. Games return NULL description.
--   Note: meetups never carry cancelled_at / cancelled_reason (events_meetup_cancel_null), so those are NULL for
--   meetups by schema.
--   roster: jsonb array, one element per subtype roster row, to_jsonb(row) of every column (so the export is not
--   pinned to a column list): public.game_roster for games (game_id = event id), public.meetup_rsvps for meetups
--   (meetup_id = event id). games.id / meetups.id equal events.id (events_check_subtype_link). '[]' when empty.
--
-- Grants: REVOKE ALL FROM PUBLIC, anon (pg_default_acl grants anon by name, so PUBLIC alone is not enough);
-- GRANT EXECUTE TO authenticated. Probes at the bottom read catalogs only.

BEGIN;

CREATE FUNCTION public.retention_cleanup_own_events(p_cutoff timestamptz)
  RETURNS integer
  LANGUAGE plpgsql
  VOLATILE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_uid     uuid := auth.uid();
  v_cutoff  timestamptz;
  v_deleted integer := 0;
  v_n       integer;
  r         record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'retention_cleanup_own_events: not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_cutoff IS NULL THEN
    RAISE EXCEPTION 'retention_cleanup_own_events: p_cutoff is required' USING ERRCODE = '22004';
  END IF;

  -- Server floor (clamp): never newer than now() - 2 years.
  v_cutoff := least(p_cutoff, pg_catalog.now() - interval '2 years');

  FOR r IN
    SELECT e.id
      FROM public.events e
     WHERE e.creator_user_id = v_uid
       AND e.created_at < v_cutoff
       AND coalesce(e.end_at, e.start_at) < v_cutoff
       AND NOT EXISTS (SELECT 1 FROM public.game_settlements s WHERE s.game_id = e.id)
     ORDER BY e.id
  LOOP
    BEGIN
      DELETE FROM public.events e
       WHERE e.id = r.id
         AND e.creator_user_id = v_uid;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_deleted := v_deleted + v_n;
    EXCEPTION
      WHEN foreign_key_violation OR restrict_violation THEN
        NULL;  -- referenced by a non-cascading FK (posts, chat registry): keep this event, continue
    END;
  END LOOP;

  RETURN v_deleted;
END
$function$;

ALTER FUNCTION public.retention_cleanup_own_events(timestamptz) OWNER TO postgres;
COMMENT ON FUNCTION public.retention_cleanup_own_events(timestamptz) IS
  'KAN-872/KAN-865: deletes the caller''s own events (creator_user_id = auth.uid()) created AND ended before '
  'least(p_cutoff, now() - 2 years). Skips events with a game_settlements row or a non-cascading reference. '
  'Returns the number of events deleted.';

CREATE FUNCTION public.export_own_events()
  RETURNS TABLE (
    event_id         uuid,
    event_type       text,
    title            text,
    description      text,
    start_at         timestamptz,
    end_at           timestamptz,
    created_at       timestamptz,
    is_cancelled     boolean,
    cancelled_at     timestamptz,
    cancelled_reason text,
    request_id       uuid,
    roster           jsonb
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'export_own_events: not authenticated' USING ERRCODE = '28000';
  END IF;

  RETURN QUERY
  SELECT e.id,
         e.event_type,
         e.title,
         (SELECT pg_catalog.to_jsonb(m) ->> 'description' FROM public.meetups m WHERE m.id = e.id),
         e.start_at,
         e.end_at,
         e.created_at,
         e.is_cancelled,
         e.cancelled_at,
         e.cancelled_reason,
         e.request_id,
         CASE e.event_type
           WHEN 'game' THEN
             coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(gr) ORDER BY gr.user_id)
                         FROM public.game_roster gr WHERE gr.game_id = e.id), '[]'::jsonb)
           WHEN 'meetup' THEN
             coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(mr) ORDER BY mr.user_id)
                         FROM public.meetup_rsvps mr WHERE mr.meetup_id = e.id), '[]'::jsonb)
           ELSE '[]'::jsonb
         END
    FROM public.events e
   WHERE e.creator_user_id = v_uid
   ORDER BY e.start_at DESC, e.id;
END
$function$;

ALTER FUNCTION public.export_own_events() OWNER TO postgres;
COMMENT ON FUNCTION public.export_own_events() IS
  'KAN-872/KAN-865: the caller''s own events (creator_user_id = auth.uid()) with description (meetups subtype), '
  'cancellation fields, request_id and roster rows (game_roster / meetup_rsvps) as a jsonb array.';

REVOKE ALL ON FUNCTION public.retention_cleanup_own_events(timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.export_own_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retention_cleanup_own_events(timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.export_own_events() TO authenticated;

-- Post-conditions (catalog reads only): fail the migration if any attribute or grant is not as authored.
DO $post$
DECLARE
  f regprocedure;
  r record;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.retention_cleanup_own_events(timestamptz)'::regprocedure,
                           'public.export_own_events()'::regprocedure]
  LOOP
    SELECT p.prosecdef, p.proconfig, pg_catalog.pg_get_userbyid(p.proowner) AS owner INTO r
      FROM pg_catalog.pg_proc p WHERE p.oid = f;
    IF NOT r.prosecdef THEN
      RAISE EXCEPTION 'KAN-872 post: % is not SECURITY DEFINER', f;
    END IF;
    IF r.proconfig IS DISTINCT FROM ARRAY['search_path=""'] THEN
      RAISE EXCEPTION 'KAN-872 post: % proconfig is %, expected {search_path=""}', f, r.proconfig;
    END IF;
    IF r.owner <> 'postgres' THEN
      RAISE EXCEPTION 'KAN-872 post: % owned by %, expected postgres', f, r.owner;
    END IF;
    IF pg_catalog.has_function_privilege('anon', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'KAN-872 post: anon can execute %', f;
    END IF;
    IF NOT pg_catalog.has_function_privilege('authenticated', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'KAN-872 post: authenticated cannot execute %', f;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p, pg_catalog.aclexplode(p.proacl) a
                WHERE p.oid = f AND a.grantee = 0) THEN
      RAISE EXCEPTION 'KAN-872 post: PUBLIC holds a privilege on %', f;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid = 'public.events'::regclass)
     OR pg_catalog.has_table_privilege('anon', 'public.events', 'SELECT')
     OR pg_catalog.has_table_privilege('authenticated', 'public.events', 'SELECT,DELETE') THEN
    RAISE EXCEPTION 'KAN-872 post: public.events is no longer closed to the API';
  END IF;
END
$post$;

COMMIT;

-- Probes (catalog reads only; run after apply):
-- SELECT p.oid::regprocedure, p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl
--   FROM pg_proc p
--  WHERE p.oid IN ('public.retention_cleanup_own_events(timestamptz)'::regprocedure,
--                  'public.export_own_events()'::regprocedure);
--   expect: prosecdef = t, proconfig = {search_path=""}, owner = postgres,
--           proacl without "=X/" (PUBLIC) and without "anon=", with "authenticated=X/postgres".
-- SELECT r AS role, f AS fn, has_function_privilege(r, f, 'EXECUTE') AS can_execute
--   FROM unnest(ARRAY['anon', 'authenticated']) r,
--        unnest(ARRAY['public.retention_cleanup_own_events(timestamptz)', 'public.export_own_events()']) f;
--   expect: anon false, authenticated true.
