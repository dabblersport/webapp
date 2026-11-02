-- KAN-751 (KAN-716 V03, Epic KAN-708 / Events P3): narrow, explicit Realtime publication for the events
-- subtypes. AUTHORED, NOT APPLIED. Team Karnak.
--
-- WHAT IT DOES
--   Puts public.meetups and public.games into the platform-managed publication `supabase_realtime`
--   with an explicit COLUMN LIST, so a postgres_changes subscriber is sent only list-card columns.
--   Replica identity is left at DEFAULT (primary key): UPDATE/DELETE old-row images carry only `id`,
--   which is the only identity column the list needs; nothing is switched to FULL.
--
-- WHAT IT DELIBERATELY DOES NOT DO
--   * public.events is NOT published. It is closed to the API roles (KAN-710/713: FORCE RLS, zero
--     policies, no grant), so Realtime could deliver nothing from it, and opening it would widen the parent.
--   * No column that identifies or profiles the owner is published: creator_user_id, creator_profile_id,
--     host_actor_id, request_id, event_id (the parent link), description, meta, search_tsv, cost_cover,
--     joining_rule, rsvp_policy, join_policy, location_name, min_skill, max_skill, members_only.
--   * No policy, grant, trigger or RLS change. Realtime still evaluates each subscriber's own SELECT RLS
--     on the published table: meetups keeps meetups_select_visible (can_view_owner AND
--     kan713_meetup_visible), so a private/hidden meetup or a blocked owner's meetup is not delivered.
--     games has RLS enabled and no SELECT policy for the API roles (kan671 header), so no authenticated
--     subscriber receives a games change; publishing it adds no visibility, it only bounds the payload if a
--     policy is added later.
--   * No data is read or written. Counts, ids, nulls and timestamps are untouched.
--
-- PLATFORM NOTE
--   The publication is platform-managed (no publication SQL exists in this repo; the audit found
--   pg_publication_tables returned no games/meetups). This migration therefore does not CREATE it; it
--   refuses (RAISE) if it is missing, and refuses on PostgreSQL < 15 (column lists need 15+).
--   Verify live, read-only, before and after (it is a SELECT):
--     SELECT schemaname, tablename, attnames FROM pg_publication_tables
--      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename IN ('games','meetups');
--
-- IDEMPOTENT: re-running leaves the same column lists. ALLOWLIST COLUMNS THAT DO NOT EXIST ARE SKIPPED
-- (intersected with information_schema), and `id` must exist or the migration aborts.
--
-- ROLLBACK (run only if these two tables were NOT in the publication before; the audit says they were not):
--   ALTER PUBLICATION supabase_realtime DROP TABLE public.meetups, public.games;
-- Executed and verified in supabase/tests/events_p3/kan716_publication_visibility.sql.

DO $kan716$
DECLARE
  v_tbl     text;
  v_allow   text[];
  v_cols    text;
  v_in_pub  boolean;
BEGIN
  IF current_setting('server_version_num')::int < 150000 THEN
    RAISE EXCEPTION 'KAN-716: publication column lists need PostgreSQL 15+ (have %)', current_setting('server_version');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    RAISE EXCEPTION 'KAN-716: publication supabase_realtime does not exist (platform-managed); refusing to create it';
  END IF;
  -- A publication that already publishes ALL TABLES cannot take a per-table list.
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND puballtables) THEN
    RAISE EXCEPTION 'KAN-716: supabase_realtime is FOR ALL TABLES; column lists cannot be applied';
  END IF;

  FOREACH v_tbl IN ARRAY ARRAY['meetups', 'games'] LOOP
    IF to_regclass('public.' || v_tbl) IS NULL THEN
      RAISE EXCEPTION 'KAN-716: public.% does not exist', v_tbl;
    END IF;

    -- List-card columns only. Same allowlist for both subtypes; absent columns are skipped.
    v_allow := ARRAY['id', 'title', 'start_at', 'end_at', 'capacity', 'is_cancelled', 'cancelled_at',
                     'cancelled_reason', 'vibe_key', 'sport_id', 'area_id', 'geo_location_id', 'venue_id',
                     'updated_at'];

    SELECT string_agg(format('%I', c.column_name), ', ' ORDER BY c.ordinal_position)
      INTO v_cols
      FROM information_schema.columns c
     WHERE c.table_schema = 'public' AND c.table_name = v_tbl AND c.column_name = ANY (v_allow);

    IF v_cols IS NULL OR NOT EXISTS (
         SELECT 1 FROM information_schema.columns c
          WHERE c.table_schema = 'public' AND c.table_name = v_tbl AND c.column_name = 'id') THEN
      RAISE EXCEPTION 'KAN-716: public.% has no id column to publish', v_tbl;
    END IF;

    SELECT EXISTS (SELECT 1 FROM pg_publication_tables
                    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = v_tbl)
      INTO v_in_pub;

    -- SET TABLE would replace the WHOLE publication list (other tables!), so re-point one table with
    -- DROP then ADD inside this single transaction; the other published tables are never touched.
    IF v_in_pub THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.%I', v_tbl);
    END IF;
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.%I (%s)', v_tbl, v_cols);
  END LOOP;
END
$kan716$;
