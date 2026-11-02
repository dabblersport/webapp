-- KAN-711 (Events P1) stage 1 of 3: the events parent table and the legacy link columns.
-- STATUS: authored only, not applied. needs-ops. PEER route (backend-N reviewer).
-- Every column decision below is PROVISIONAL (E1 / KAN-710 absent from Alpha). See
-- supabase/tests/events_p1/KAN711_CONTRACT.md for the full classification table.
--
-- Additive only. No legacy column or table is dropped or altered in type. games and meetups keep
-- their ids and remain AUTHORITATIVE; public.events is a transactional mirror (stage 2) filled by a
-- separately authorised backfill (stage 3).
--
-- Locks taken on live tables: ADD COLUMN (nullable, no default) is catalogue-only but takes ACCESS
-- EXCLUSIVE briefly; CREATE UNIQUE INDEX (non-concurrent, migrations run in a transaction) takes
-- SHARE on games and meetups for the duration of the build; ADD FOREIGN KEY ... NOT VALID takes
-- SHARE ROW EXCLUSIVE and scans nothing.

BEGIN;

-- Precondition: the objects this migration creates are read by SECURITY DEFINER functions (stage 2/3)
-- that must see every legacy row. meetups has FORCE ROW LEVEL SECURITY, so the owning role must
-- bypass RLS or the integrity check would treat invisible meetups as missing and abort user writes.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-711: applying role % must be superuser or BYPASSRLS (meetups is FORCE RLS)', current_user;
  END IF;
  IF to_regclass('public.events') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-711: public.events already exists; refusing to guess its shape';
  END IF;
END $$;

CREATE TABLE public.events (
    id                 uuid        NOT NULL,                 -- = games.id / meetups.id (deterministic, no new ids)
    event_type         text        NOT NULL,
    title              text,                                 -- games.title nullable; meetups.title NOT NULL
    description        text,                                 -- meetups only
    creator_profile_id uuid        NOT NULL,
    creator_user_id    uuid        NOT NULL,
    sport_id           uuid,                                 -- games NOT NULL; meetups nullable
    start_at           timestamptz NOT NULL,
    end_at             timestamptz,                          -- games NOT NULL; meetups nullable; never inferred
    capacity           integer,                              -- games 2..64 NOT NULL; meetups null or > 0
    venue_id           uuid,
    geo_location_id    uuid,
    area_id            uuid,
    location_name      text,                                 -- meetups only
    is_indoor          boolean,                              -- meetups only
    listing_visibility text        NOT NULL,                 -- raw legacy value, union domain, NOT normalised
    join_policy        text        NOT NULL,                 -- games.join_policy / meetups.rsvp_policy (alias)
    min_skill          integer,
    max_skill          integer,
    joining_rule       text        NOT NULL,
    cost_cover         text        NOT NULL,
    is_cancelled       boolean     NOT NULL,
    cancelled_at       timestamptz,                          -- games only; never inferred for meetups
    cancelled_reason   text,                                 -- games only
    request_id         uuid,
    created_at         timestamptz NOT NULL,                 -- copied, never defaulted
    updated_at         timestamptz NOT NULL,                 -- copied, never defaulted
    search_tsv         tsvector,                             -- copied verbatim from legacy
    CONSTRAINT events_pkey PRIMARY KEY (id),
    CONSTRAINT events_event_type_check CHECK (event_type IN ('game', 'meetup')),
    -- Union of the legacy domains, so the mirror can never refuse a row the legacy table accepted.
    CONSTRAINT events_listing_visibility_check CHECK (listing_visibility IN
        ('public', 'followers', 'private', 'circle', 'invite', 'link', 'hidden')),
    CONSTRAINT events_join_policy_check CHECK (join_policy IN
        ('open', 'request', 'invite', 'link', 'circle', 'squad', 'closed')),
    CONSTRAINT events_capacity_check CHECK (capacity IS NULL OR capacity > 0),
    CONSTRAINT events_joining_rule_check CHECK (joining_rule IN ('free', 'members_only', 'paid')),
    CONSTRAINT events_cost_cover_check CHECK (cost_cover IN ('free', 'members_only', 'paid')),
    CONSTRAINT events_cost_cover_logic CHECK (
        (joining_rule = 'free' AND cost_cover = 'free')
     OR (joining_rule = 'members_only' AND cost_cover = 'members_only')
     OR (joining_rule = 'paid' AND cost_cover IN ('paid', 'free')))
);
-- Deliberately NO foreign keys from events reference columns (profiles, sports, venues, geo, areas):
-- the legacy tables have differing ON DELETE actions (RESTRICT / SET NULL / CASCADE) and an events FK
-- would change what a legacy delete does. Legacy FKs stay the enforcement in phase 1.

COMMENT ON TABLE public.events IS
  'KAN-711 Events P1: transactional mirror of public.games and public.meetups. Legacy tables are authoritative in phase 1. Written only by SECURITY DEFINER mirror/backfill functions.';

-- Request idempotency, per the product contract. Legacy enforcement (creator_user_id, request_id)
-- stays in place on both tables (20261021120000).
CREATE UNIQUE INDEX events_type_profile_request_key
    ON public.events (event_type, creator_profile_id, request_id) WHERE request_id IS NOT NULL;
CREATE INDEX events_start_at_idx ON public.events (start_at);
CREATE INDEX events_creator_profile_idx ON public.events (creator_profile_id);
CREATE INDEX events_search_tsv_idx ON public.events USING gin (search_tsv);
-- Series occurrence uniqueness: events carries no series_id in phase 1, so games_series_id_start_at_key
-- (20261030120000) remains the enforcement. start_at is mirrored in the same transaction, so the two
-- cannot diverge; parity_kan711.sql re-checks it. Phase 2 must add series_id and an equivalent index.

-- Deny by default. RLS on, no policy, no grants to anon/authenticated. service_role read-only.
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.events FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.events TO service_role;

-- Legacy link columns. Nullable until stage 3 proves parity. event_id is always equal to id
-- (enforced by trg_kan711_*_assign_event_id in stage 2).
ALTER TABLE public.games   ADD COLUMN event_id uuid;
ALTER TABLE public.meetups ADD COLUMN event_id uuid;
CREATE UNIQUE INDEX games_event_id_key   ON public.games   (event_id) WHERE event_id IS NOT NULL;
CREATE UNIQUE INDEX meetups_event_id_key ON public.meetups (event_id) WHERE event_id IS NOT NULL;

-- NOT VALID: existing rows are not scanned; every new or changed row is checked. DEFERRABLE INITIALLY
-- DEFERRED because the events row is written by an AFTER trigger in the same transaction.
-- NO ACTION on delete: an events row cannot be removed while a legacy row still points at it.
ALTER TABLE public.games ADD CONSTRAINT games_event_id_fkey
    FOREIGN KEY (event_id) REFERENCES public.events (id) DEFERRABLE INITIALLY DEFERRED NOT VALID;
ALTER TABLE public.meetups ADD CONSTRAINT meetups_event_id_fkey
    FOREIGN KEY (event_id) REFERENCES public.events (id) DEFERRABLE INITIALLY DEFERRED NOT VALID;

-- Post-conditions: assert the resulting state, not that the statements ran.
DO $$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass) THEN
    RAISE EXCEPTION 'KAN-711 post: RLS not enabled on events';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'events') THEN
    RAISE EXCEPTION 'KAN-711 post: events must have no policy in phase 1';
  END IF;
  IF has_table_privilege('anon', 'public.events', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN
    RAISE EXCEPTION 'KAN-711 post: anon/authenticated hold a privilege on events';
  END IF;
  IF has_table_privilege('service_role', 'public.events', 'INSERT,UPDATE,DELETE,TRUNCATE') THEN
    RAISE EXCEPTION 'KAN-711 post: service_role may write events';
  END IF;
  IF (SELECT count(*) FROM pg_constraint
       WHERE conname IN ('games_event_id_fkey', 'meetups_event_id_fkey')
         AND condeferrable AND condeferred AND NOT convalidated) <> 2 THEN
    RAISE EXCEPTION 'KAN-711 post: link FKs not NOT VALID DEFERRABLE INITIALLY DEFERRED';
  END IF;
END $$;

COMMIT;
