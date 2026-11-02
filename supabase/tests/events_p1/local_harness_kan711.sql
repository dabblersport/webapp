-- KAN-711 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Builds the smallest stand-in for the live surface that the KAN-711 migrations touch, so the
-- migrations and probes can actually execute somewhere. It is NOT the live schema:
--   * games / meetups: column lists, defaults, NOT NULLs and CHECK constraints copied from
--     baseline 20260829080500 (lines 22863-22908, 23084-23120) plus the later columns
--     price_aed, is_indoor (20261008140000), request_id (20261021120000), series_id (20261027120000).
--   * Trigger bodies copied verbatim where they matter for KAN-711 (touch_updated_at, search_tsv,
--     fn_*_activity_sync, trg_game_updated_notify, trg_meetups_cancel_notify, kan611 stamp).
--   * trgfn_meetups_outbox: the repo body reads NEW.owner_user_id, a column meetups does not have,
--     so as written every meetup INSERT would fail. The harness installs it with creator_user_id
--     and records the finding in KAN711_CONTRACT.md; the live body is unknown to this seat.
--   * PostGIS, unaccent, sports/venues validation triggers, persona guards, frozen guard and
--     notification fan-out are stubbed. Anything not listed here is absent.
-- Usage (throwaway cluster, superuser postgres), in this order:
--   createdb -h /tmp -p 54399 -U postgres kan711
--   psql ... -f local_harness_kan711.sql            (this file; replaces KAN-710's local_stub_kan710.sql)
--   psql ... -f local_seed_kan711.sql
--   psql ... -f ../../migrations/20261101140000_kan710_events_parent_schema.sql   (KAN-710, unmodified)
--   psql ... -f ../../migrations/20261102110000_kan711_events_mirror_triggers.sql
--   psql ... -f ../../migrations/20261102120000_kan711_events_backfill.sql

-- Roles as on Supabase.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Supabase-like default privileges: functions get EXECUTE for anon/authenticated BY NAME, tables get
-- ALL for service_role. (KAN-67 revoked the anon/authenticated table default; functions still grant.)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;

CREATE SCHEMA IF NOT EXISTS auth;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;

-- Reference stubs -------------------------------------------------------------------------------
CREATE TABLE public.areas (id uuid PRIMARY KEY DEFAULT gen_random_uuid());
CREATE TABLE public.geo_locations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), area_id uuid NOT NULL REFERENCES public.areas(id));
CREATE TABLE public.profiles (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES auth.users(id));
CREATE TABLE public.sports (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), can_solo boolean, is_challenge_sport boolean, is_active boolean);
CREATE TABLE public.venues (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), geo_location_id uuid);
CREATE TABLE public.venue_spaces (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), venue_id uuid, joining_rule text);
CREATE TABLE public.game_series (id uuid PRIMARY KEY DEFAULT gen_random_uuid());

-- Side-effect sinks the probes count ------------------------------------------------------------
CREATE TABLE public.public_activities (id uuid PRIMARY KEY, activity_type text, source_table text,
  actor_user_id uuid, actor_profile_id uuid, target_profile_id uuid, visibility text, sport_id uuid,
  area_id uuid, geo_location_id uuid, is_deleted boolean, is_hidden_admin boolean, is_pinned boolean,
  occurred_at timestamptz, created_at timestamptz, updated_at timestamptz);
CREATE TABLE public.activity_events (id bigserial PRIMARY KEY, event_type text, actor_user_id uuid, game_id uuid, source_type text, metadata jsonb);
CREATE TABLE public.notifications (id bigserial PRIMARY KEY, user_id uuid, kind text, entity_type text, entity_id uuid, created_at timestamptz DEFAULT now());
CREATE TABLE public.feed_items (id bigserial PRIMARY KEY, ref uuid);
CREATE TABLE public.event_outbox (id bigserial PRIMARY KEY, event_key text, entity_id uuid);
CREATE TABLE public.msg_system_lines (id bigserial PRIMARY KEY, kind text, game_id uuid);
CREATE TABLE public.game_roster (game_id uuid, user_id uuid);
CREATE TABLE public.meetup_rsvps (meetup_id uuid, user_id uuid, status text);

CREATE OR REPLACE FUNCTION public.process_notification_event(p_user uuid, p_kind text, p_entity_type text, p_entity uuid, p_actor uuid, p_title text DEFAULT NULL, p_body text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$ INSERT INTO public.notifications(user_id, kind, entity_type, entity_id) VALUES (p_user, p_kind, p_entity_type, p_entity) $$;
CREATE OR REPLACE FUNCTION public.emit_event(event_key text, entity_type text, entity_id uuid, actor_user_id uuid, payload jsonb)
RETURNS void LANGUAGE sql AS $$ INSERT INTO public.event_outbox(event_key, entity_id) VALUES (event_key, entity_id) $$;
CREATE OR REPLACE FUNCTION public.unaccent(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT $1 $$;
-- KAN-710 (20261101140000) indexes and derives search_tsv through unaccent_immutable; stubbed the same way.
CREATE OR REPLACE FUNCTION public.unaccent_immutable(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT $1 $$;
CREATE OR REPLACE FUNCTION public.can_view_owner(owner_user_id uuid, scope text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT scope = 'public' $$;

-- games (baseline 22863-22908 + later columns) ---------------------------------------------------
CREATE TABLE public.games (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    game_type text DEFAULT 'casual'::text NOT NULL,
    title text,
    creator_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    creator_user_id uuid NOT NULL,
    venue_space_id uuid,
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    capacity integer NOT NULL,
    listing_visibility text DEFAULT 'public'::text NOT NULL,
    join_policy text DEFAULT 'open'::text NOT NULL,
    allow_spectators boolean DEFAULT false NOT NULL,
    min_skill integer,
    max_skill integer,
    rules jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_cancelled boolean DEFAULT false NOT NULL,
    cancelled_at timestamptz,
    cancelled_reason text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    squad_id uuid,
    search_tsv tsvector,
    sport_specific_data jsonb DEFAULT '{}'::jsonb,
    allows_waitlist boolean DEFAULT false,
    sport_id uuid NOT NULL REFERENCES public.sports(id),
    geo_location_id uuid NOT NULL REFERENCES public.geo_locations(id) ON DELETE SET NULL,
    area_id uuid NOT NULL REFERENCES public.areas(id),
    venue_id uuid REFERENCES public.venues(id) ON DELETE SET NULL,
    sport_variant_id uuid,
    bench_slots integer DEFAULT 0 NOT NULL,
    joining_rule text DEFAULT 'free'::text NOT NULL,
    cost_cover text DEFAULT 'free'::text NOT NULL,
    price_aed numeric(10,2) CHECK (price_aed >= 0),
    request_id uuid,
    series_id uuid REFERENCES public.game_series(id) ON DELETE SET NULL,
    CONSTRAINT games_bench_slots_non_negative CHECK ((bench_slots >= 0)),
    CONSTRAINT games_capacity_check CHECK (((capacity >= 2) AND (capacity <= 64))),
    CONSTRAINT games_cost_cover_check CHECK ((cost_cover = ANY (ARRAY['free'::text, 'members_only'::text, 'paid'::text]))),
    CONSTRAINT games_cost_cover_logic CHECK ((((joining_rule = 'free'::text) AND (cost_cover = 'free'::text)) OR ((joining_rule = 'members_only'::text) AND (cost_cover = 'members_only'::text)) OR ((joining_rule = 'paid'::text) AND (cost_cover = ANY (ARRAY['paid'::text, 'free'::text]))))),
    CONSTRAINT games_game_type_check CHECK ((game_type = ANY (ARRAY['pickup'::text, 'training'::text, 'league'::text, 'hosted'::text, 'casual'::text]))),
    CONSTRAINT games_join_policy_check CHECK ((join_policy = ANY (ARRAY['open'::text, 'request'::text, 'invite'::text, 'link'::text]))),
    CONSTRAINT games_join_policy_chk CHECK ((join_policy = ANY (ARRAY['open'::text, 'request'::text, 'invite'::text, 'link'::text, 'circle'::text, 'squad'::text, 'closed'::text]))),
    CONSTRAINT games_joining_rule_check CHECK ((joining_rule = ANY (ARRAY['free'::text, 'members_only'::text, 'paid'::text]))),
    CONSTRAINT games_listing_visibility_check CHECK ((listing_visibility = ANY (ARRAY['public'::text, 'followers'::text, 'private'::text]))),
    CONSTRAINT games_location_required CHECK (((geo_location_id IS NOT NULL) AND (area_id IS NOT NULL))),
    CONSTRAINT games_max_skill_check CHECK (((max_skill >= 1) AND (max_skill <= 10))),
    CONSTRAINT games_min_skill_check CHECK (((min_skill >= 1) AND (min_skill <= 10)))
);
CREATE UNIQUE INDEX games_creator_user_request_id_key ON public.games (creator_user_id, request_id) WHERE request_id IS NOT NULL;
CREATE UNIQUE INDEX games_series_id_start_at_key ON public.games (series_id, start_at) WHERE series_id IS NOT NULL;
ALTER TABLE public.games OWNER TO postgres;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;   -- no policy, as live (20261027120000 header)

-- meetups (baseline 23084-23120 + later columns) -------------------------------------------------
CREATE TABLE public.meetups (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    creator_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    creator_user_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    vibe_key text,
    listing_visibility text DEFAULT 'public'::text NOT NULL,
    rsvp_policy text DEFAULT 'open'::text NOT NULL,
    capacity integer,
    start_at timestamptz NOT NULL,
    end_at timestamptz,
    is_cancelled boolean DEFAULT false NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    host_actor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    search_tsv tsvector,
    geo_location_id uuid REFERENCES public.geo_locations(id),
    sport_id uuid REFERENCES public.sports(id) ON DELETE SET NULL,
    area_id uuid REFERENCES public.areas(id) ON DELETE SET NULL,
    venue_id uuid REFERENCES public.venues(id) ON DELETE SET NULL,
    min_skill integer,
    max_skill integer,
    members_only boolean DEFAULT false NOT NULL,
    joining_rule text DEFAULT 'free'::text NOT NULL,
    cost_cover text DEFAULT 'free'::text NOT NULL,
    location_name text,
    is_indoor boolean,
    request_id uuid,
    CONSTRAINT chk_meetups_title_len CHECK (((char_length(title) >= 3) AND (char_length(title) <= 80))),
    CONSTRAINT meetups_capacity_check CHECK (((capacity IS NULL) OR (capacity > 0))),
    CONSTRAINT meetups_cost_cover_check CHECK ((cost_cover = ANY (ARRAY['free'::text, 'members_only'::text, 'paid'::text]))),
    CONSTRAINT meetups_cost_cover_logic CHECK ((((joining_rule = 'free'::text) AND (cost_cover = 'free'::text)) OR ((joining_rule = 'members_only'::text) AND (cost_cover = 'members_only'::text)) OR ((joining_rule = 'paid'::text) AND (cost_cover = ANY (ARRAY['paid'::text, 'free'::text]))))),
    CONSTRAINT meetups_joining_rule_check CHECK ((joining_rule = ANY (ARRAY['free'::text, 'members_only'::text, 'paid'::text]))),
    CONSTRAINT meetups_listing_visibility_check CHECK ((listing_visibility = ANY (ARRAY['public'::text, 'circle'::text, 'invite'::text, 'link'::text, 'hidden'::text]))),
    CONSTRAINT meetups_rsvp_policy_check CHECK ((rsvp_policy = ANY (ARRAY['open'::text, 'request'::text, 'invite'::text, 'link'::text, 'closed'::text]))),
    CONSTRAINT meetups_title_check CHECK (((char_length(title) >= 3) AND (char_length(title) <= 120)))
);
CREATE UNIQUE INDEX meetups_creator_user_request_id_key ON public.meetups (creator_user_id, request_id) WHERE request_id IS NOT NULL;
ALTER TABLE public.meetups OWNER TO postgres;
ALTER TABLE public.meetups ENABLE ROW LEVEL SECURITY;
ALTER TABLE ONLY public.meetups FORCE ROW LEVEL SECURITY;
CREATE POLICY meetups_no_direct_insert ON public.meetups FOR INSERT WITH CHECK (false);
CREATE POLICY meetups_select_visible ON public.meetups FOR SELECT USING (public.can_view_owner(creator_user_id, listing_visibility));

-- Grants as after KAN-86 (20260901190000): SELECT kept, writes revoked except games for authenticated.
REVOKE ALL ON public.games, public.meetups FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.games, public.meetups TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.games TO authenticated;
GRANT ALL ON public.games, public.meetups TO service_role;

-- Legacy trigger functions (verbatim bodies where noted) ---------------------------------------
CREATE OR REPLACE FUNCTION public.touch_updated_at() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ begin new.updated_at = now(); return new; end$$;                                         -- verbatim 17390
CREATE OR REPLACE FUNCTION public.trg_touch_updated_at() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ begin new.updated_at = now(); return new; end $$;                                         -- verbatim 18623
CREATE OR REPLACE FUNCTION public.trg_games_set_search_tsv() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ declare j jsonb := to_jsonb(NEW); begin NEW.search_tsv := to_tsvector('simple', unaccent(coalesce(j->>'title',''))); return NEW; end$$; -- verbatim 17824
CREATE OR REPLACE FUNCTION public.meetups_search_tsv_trigger() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ BEGIN NEW.search_tsv := setweight(to_tsvector('simple', coalesce(NEW.title,'')), 'A') || setweight(to_tsvector('simple', coalesce(NEW.description,'')), 'B') || setweight(to_tsvector('simple', coalesce(NEW.location_name,'')), 'C'); RETURN NEW; END $$; -- verbatim 8989
CREATE OR REPLACE FUNCTION public.trgfn_games_set_host_user() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ DECLARE uid uuid; BEGIN SELECT user_id INTO uid FROM public.profiles WHERE id = NEW.creator_profile_id;
  IF uid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found'; END IF;
  NEW.creator_user_id := uid; RETURN NEW; END$$;                                                 -- verbatim 18922
CREATE OR REPLACE FUNCTION public.fn_games_activity_sync() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$ BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.public_activities (id, activity_type, source_table, actor_user_id, actor_profile_id, target_profile_id, visibility, sport_id, area_id, geo_location_id, is_deleted, is_hidden_admin, is_pinned, occurred_at, created_at, updated_at)
    VALUES (NEW.id, 'game_create', 'games', NEW.creator_user_id, NEW.creator_profile_id, NEW.creator_profile_id, 'public', NEW.sport_id, NEW.area_id, NEW.geo_location_id, false, false, false, NEW.created_at, NEW.created_at, NEW.updated_at)
    ON CONFLICT (id) DO NOTHING;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.public_activities SET is_deleted = COALESCE(NEW.is_cancelled, false), updated_at = NEW.updated_at WHERE id = NEW.id;
  END IF; RETURN NEW; END; $$;                                                                   -- verbatim 5979
CREATE OR REPLACE FUNCTION public.fn_meetups_activity_sync() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$ BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.public_activities (id, activity_type, source_table, actor_user_id, actor_profile_id, target_profile_id, visibility, sport_id, area_id, geo_location_id, is_deleted, is_hidden_admin, is_pinned, occurred_at, created_at, updated_at)
    VALUES (NEW.id, 'meetup_create', 'meetups', NEW.creator_user_id, NEW.creator_profile_id, NEW.creator_profile_id, 'public', NEW.sport_id, NEW.area_id, NEW.geo_location_id, false, false, false, NEW.created_at, NEW.created_at, NEW.updated_at)
    ON CONFLICT (id) DO NOTHING;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.public_activities SET is_deleted = COALESCE(NEW.is_cancelled, false), updated_at = NEW.updated_at WHERE id = NEW.id;
  END IF; RETURN NEW; END; $$;                                                                   -- verbatim 6251
CREATE OR REPLACE FUNCTION public.handle_game_created() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ BEGIN INSERT INTO activity_events (event_type, actor_user_id, game_id, source_type, metadata) VALUES ('game_created', NEW.creator_profile_id, NEW.id, 'game', jsonb_build_object('start_time', NEW.start_at)); RETURN NEW; END; $$;
CREATE OR REPLACE FUNCTION public.trg_game_updated_notify() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$ DECLARE v_player RECORD; BEGIN
  IF OLD.is_cancelled = false AND NEW.is_cancelled = true THEN
    FOR v_player IN SELECT user_id FROM public.game_roster WHERE game_id = NEW.id AND user_id <> NEW.creator_user_id LOOP
      PERFORM public.process_notification_event(v_player.user_id, 'game.updated', 'game', NEW.id, NEW.creator_user_id);
    END LOOP;
  END IF; RETURN NEW; END; $$;                                                                   -- verbatim 17785
CREATE OR REPLACE FUNCTION public.msg_system_game_trg() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $$ BEGIN INSERT INTO public.msg_system_lines(kind, game_id) VALUES ('cancelled', NEW.id); RETURN NULL; END $$;  -- stub of 20261013160000
CREATE OR REPLACE FUNCTION public.trgfn_meetups_outbox() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ begin
  if tg_op='INSERT' then perform public.emit_event('meetup.created','meetup', new.id, new.creator_user_id, jsonb_build_object('start_at', new.start_at));
  elsif tg_op='UPDATE' then if new.is_cancelled and not old.is_cancelled then perform public.emit_event('meetup.cancelled','meetup', new.id, auth.uid(), '{}'); end if;
  end if; return null; end; $$;   -- repo body uses new.owner_user_id (no such column); see header
CREATE OR REPLACE FUNCTION public.trg_meetups_cancel_notify() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $$ DECLARE r record; BEGIN
  FOR r IN SELECT DISTINCT s.user_id FROM public.meetup_rsvps s WHERE s.meetup_id = NEW.id AND s.status IN ('going','interested','pending') LOOP
    PERFORM public.process_notification_event(r.user_id, 'meetup.cancelled', 'meetup', NEW.id, NEW.creator_user_id);
  END LOOP; RETURN NEW; END; $$;
CREATE OR REPLACE FUNCTION public.kan611_stamp_request_id() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $$ DECLARE v text := nullif(current_setting('thebes.create_request_id', true), ''); BEGIN
  IF v IS NOT NULL AND NEW.request_id IS NULL THEN NEW.request_id := v::uuid; END IF; RETURN NEW; END; $$;

-- Legacy triggers (names and timing as live) -----------------------------------------------------
CREATE TRIGGER tr_games_activity_sync AFTER INSERT OR UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION public.fn_games_activity_sync();
CREATE TRIGGER trg_game_created AFTER INSERT ON public.games FOR EACH ROW EXECUTE FUNCTION public.handle_game_created();
ALTER TABLE public.games DISABLE TRIGGER trg_game_created;   -- disabled in baseline 29815
CREATE TRIGGER trg_game_updated_notify AFTER UPDATE ON public.games FOR EACH ROW WHEN ((old.is_cancelled IS DISTINCT FROM new.is_cancelled)) EXECUTE FUNCTION public.trg_game_updated_notify();
CREATE TRIGGER msg_system_game_cancelled AFTER UPDATE OF is_cancelled ON public.games FOR EACH ROW WHEN (OLD.is_cancelled IS NOT TRUE AND NEW.is_cancelled IS TRUE) EXECUTE FUNCTION public.msg_system_game_trg();
CREATE TRIGGER trg_games_search_tsv BEFORE INSERT OR UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION public.trg_games_set_search_tsv();
CREATE TRIGGER trg_games_set_host BEFORE INSERT OR UPDATE OF creator_profile_id ON public.games FOR EACH ROW EXECUTE FUNCTION public.trgfn_games_set_host_user();
CREATE TRIGGER trg_games_touch BEFORE UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_games_stamp_request_id BEFORE INSERT ON public.games FOR EACH ROW EXECUTE FUNCTION public.kan611_stamp_request_id();

CREATE TRIGGER tr_meetups_activity_sync AFTER INSERT OR UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.fn_meetups_activity_sync();
CREATE TRIGGER trg_meetups_outbox AFTER INSERT OR UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.trgfn_meetups_outbox();
CREATE TRIGGER trg_meetups_cancel_notify AFTER UPDATE OF is_cancelled ON public.meetups FOR EACH ROW WHEN (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE) EXECUTE FUNCTION public.trg_meetups_cancel_notify();
CREATE TRIGGER trg_meetups_search_tsv BEFORE INSERT OR UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.meetups_search_tsv_trigger();
CREATE TRIGGER trg_meetups_touch BEFORE UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.trg_touch_updated_at();
CREATE TRIGGER trg_meetups_updated BEFORE UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_meetups_stamp_request_id BEFORE INSERT ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.kan611_stamp_request_id();

-- Seed reference rows (probes look these up; they never invent ids) ------------------------------
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2');
INSERT INTO public.profiles(id, user_id) VALUES ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a1'),
                                                ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-0000000000a2');
INSERT INTO public.areas(id) VALUES ('00000000-0000-0000-0000-0000000000c1');
INSERT INTO public.geo_locations(id, area_id) VALUES ('00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-0000000000c1');
INSERT INTO public.sports(id, can_solo, is_challenge_sport, is_active) VALUES ('00000000-0000-0000-0000-0000000000e1', true, true, true);
INSERT INTO public.game_series(id) VALUES ('00000000-0000-0000-0000-0000000000f1');
