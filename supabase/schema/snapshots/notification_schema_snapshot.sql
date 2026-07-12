-- ============================================================================
-- DABBLER — NOTIFICATION DOMAIN SCHEMA SNAPSHOT (READ-ONLY)
-- ============================================================================
-- Generated: 2026-07-11 from the LIVE Supabase project via introspection
-- (pg_catalog / information_schema / pg_get_*def).
--
-- The remote database is the source of truth. This file is documentation of
-- what exists in production; it is NOT a migration and is NOT meant to be
-- applied blindly. Object order is for readability, not dependency-safe
-- execution (cross-domain tables such as profiles, posts, games, auth.users,
-- subscription_plans, vault secrets, pg_net and pg_cron must already exist).
--
-- Contents:
--   1. Enum types
--   2. Tables (reconstructed CREATE TABLE DDL)
--   3. Indexes (non-PK/unique-constraint indexes)
--   4. Row Level Security (enable statements + policies)
--   5. Views
--   6. Functions
--   7. Triggers
--   8. pg_cron jobs
-- ============================================================================


-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

CREATE TYPE public.notify_priority AS ENUM ('low', 'normal', 'high', 'urgent');

CREATE TYPE public.notify_channel AS ENUM ('inapp', 'push', 'email', 'sms');


-- ============================================================================
-- 2. TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 notification_kinds — catalog of notification types
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_kinds (
    key              text NOT NULL,
    label_en         text NOT NULL,
    label_ar         text NOT NULL,
    default_priority public.notify_priority NOT NULL DEFAULT 'normal'::notify_priority,
    default_channels public.notify_channel[] NOT NULL DEFAULT '{inapp}'::notify_channel[],
    route_template   text,
    timing           jsonb,
    is_active        boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notification_kinds_pkey PRIMARY KEY (key)
);

-- ----------------------------------------------------------------------------
-- 2.2 notifications — the in-app notification feed
-- ----------------------------------------------------------------------------
CREATE TABLE public.notifications (
    id                uuid NOT NULL DEFAULT gen_random_uuid(),
    to_user_id        uuid NOT NULL,
    kind_key          text NOT NULL,
    title             text NOT NULL,
    body              text,
    action_route      text,
    context           jsonb NOT NULL DEFAULT '{}'::jsonb,
    priority          public.notify_priority NOT NULL DEFAULT 'normal'::notify_priority,
    created_at        timestamptz NOT NULL DEFAULT now(),
    is_read           boolean NOT NULL DEFAULT false,
    read_at           timestamptz,
    ai_score          numeric DEFAULT 1,
    rank_score        numeric,
    clicked_at        timestamptz,
    interaction_count integer DEFAULT 0,
    CONSTRAINT notifications_pkey PRIMARY KEY (id),
    CONSTRAINT notifications_kind_key_fkey FOREIGN KEY (kind_key)
        REFERENCES public.notification_kinds(key) ON UPDATE CASCADE,
    CONSTRAINT notifications_to_user_id_fkey FOREIGN KEY (to_user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 2.3 notification_settings — per-user delivery preferences / quiet hours
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_settings (
    user_id                      uuid NOT NULL,
    tz                           text NOT NULL DEFAULT 'Asia/Dubai'::text,
    quiet_start_min              integer,
    quiet_end_min                integer,
    push_enabled                 boolean NOT NULL DEFAULT true,
    email_enabled                boolean NOT NULL DEFAULT false,
    sms_enabled                  boolean NOT NULL DEFAULT false,
    muted_kinds                  text[] NOT NULL DEFAULT '{}'::text[],
    created_at                   timestamptz NOT NULL DEFAULT now(),
    updated_at                   timestamptz NOT NULL DEFAULT now(),
    allow_high_priority_override boolean DEFAULT false,
    allow_all_override           boolean DEFAULT false,
    CONSTRAINT notification_settings_pkey PRIMARY KEY (user_id),
    CONSTRAINT notification_settings_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT chk_qh_bounds CHECK (
        ((quiet_start_min IS NULL) AND (quiet_end_min IS NULL))
        OR (((quiet_start_min >= 0) AND (quiet_start_min <= 1439))
            AND ((quiet_end_min >= 0) AND (quiet_end_min <= 1439)))
    )
);

-- ----------------------------------------------------------------------------
-- 2.4 notification_deliveries — per-channel delivery audit trail
-- Note: live column default is nextval('notification_deliveries_id_seq').
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_deliveries (
    id              bigint NOT NULL DEFAULT nextval('notification_deliveries_id_seq'::regclass),
    notification_id uuid NOT NULL,
    channel         public.notify_channel NOT NULL,
    status          text NOT NULL DEFAULT 'queued'::text,
    provider_id     text,
    error           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notification_deliveries_pkey PRIMARY KEY (id),
    CONSTRAINT notification_deliveries_notification_id_fkey FOREIGN KEY (notification_id)
        REFERENCES public.notifications(id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 2.5 notification_aggregates — pending aggregation windows ("X and N others")
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_aggregates (
    id                uuid NOT NULL DEFAULT gen_random_uuid(),
    to_user_id        uuid NOT NULL,
    kind_key          text NOT NULL,
    entity_type       text NOT NULL,
    entity_id         uuid NOT NULL,
    actors            uuid[] NOT NULL DEFAULT '{}'::uuid[],
    total_count       integer NOT NULL DEFAULT 1,
    window_started_at timestamptz NOT NULL DEFAULT now(),
    window_expires_at timestamptz NOT NULL,
    is_flushed        boolean NOT NULL DEFAULT false,
    created_at        timestamptz DEFAULT now(),
    updated_at        timestamptz DEFAULT now(),
    CONSTRAINT notification_aggregates_pkey PRIMARY KEY (id),
    CONSTRAINT notification_aggregates_kind_key_fkey FOREIGN KEY (kind_key)
        REFERENCES public.notification_kinds(key),
    CONSTRAINT notification_aggregates_to_user_id_fkey FOREIGN KEY (to_user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 2.6 notification_aggregation_rules — per-kind aggregation configuration
-- NOTE: evaluate_notification_strategy() references a `force_instant` column
-- that does NOT exist on this table in the live DB (would error at runtime
-- if that code path is exercised).
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_aggregation_rules (
    kind_key                   text NOT NULL,
    aggregation_window_seconds integer NOT NULL DEFAULT 300,
    min_actors_to_aggregate    integer NOT NULL DEFAULT 2,
    enabled                    boolean NOT NULL DEFAULT true,
    CONSTRAINT notification_aggregation_rules_pkey PRIMARY KEY (kind_key),
    CONSTRAINT notification_aggregation_rules_kind_key_fkey FOREIGN KEY (kind_key)
        REFERENCES public.notification_kinds(key)
);

-- ----------------------------------------------------------------------------
-- 2.7 notification_scores — per-kind AI scoring weights
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_scores (
    id                  uuid NOT NULL DEFAULT gen_random_uuid(),
    kind_key            text NOT NULL,
    base_weight         numeric NOT NULL DEFAULT 1.0,
    actor_weight        numeric NOT NULL DEFAULT 0.5,
    relationship_weight numeric NOT NULL DEFAULT 1.0,
    engagement_weight   numeric NOT NULL DEFAULT 0.5,
    plan_boost_weight   numeric NOT NULL DEFAULT 1.0,
    recency_weight      numeric NOT NULL DEFAULT 0.3,
    is_enabled          boolean NOT NULL DEFAULT true,
    created_at          timestamptz DEFAULT now(),
    CONSTRAINT notification_scores_pkey PRIMARY KEY (id),
    CONSTRAINT notification_scores_kind_key_fkey FOREIGN KEY (kind_key)
        REFERENCES public.notification_kinds(key)
);

-- ----------------------------------------------------------------------------
-- 2.8 notification_hourly_caps — plan-based hourly rate limits per priority
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_hourly_caps (
    plan_key     text NOT NULL,
    priority     public.notify_priority NOT NULL,
    max_per_hour integer NOT NULL,
    CONSTRAINT notification_hourly_caps_pkey PRIMARY KEY (plan_key, priority),
    CONSTRAINT notification_hourly_caps_plan_key_fkey FOREIGN KEY (plan_key)
        REFERENCES public.subscription_plans(key) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 2.9 notification_user_preferences — adaptive per-kind engagement scores
-- ----------------------------------------------------------------------------
CREATE TABLE public.notification_user_preferences (
    user_id          uuid NOT NULL,
    kind_key         text NOT NULL,
    engagement_score numeric DEFAULT 1,
    CONSTRAINT notification_user_preferences_pkey PRIMARY KEY (user_id, kind_key),
    CONSTRAINT notification_user_preferences_kind_key_fkey FOREIGN KEY (kind_key)
        REFERENCES public.notification_kinds(key),
    CONSTRAINT notification_user_preferences_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 2.10 fcm_tokens — Firebase Cloud Messaging device tokens
-- ----------------------------------------------------------------------------
CREATE TABLE public.fcm_tokens (
    id         uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL,
    token      text NOT NULL,
    platform   text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fcm_tokens_pkey PRIMARY KEY (id),
    CONSTRAINT unique_user_platform UNIQUE (user_id, platform),
    CONSTRAINT fcm_tokens_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT fcm_tokens_platform_check CHECK (
        platform = ANY (ARRAY['android'::text, 'iOS'::text, 'macOS'::text,
                              'web'::text, 'linux'::text, 'windows'::text,
                              'fuchsia'::text])
    )
);


-- ============================================================================
-- 3. INDEXES
-- (PK / unique-constraint indexes are implied by section 2 and omitted here.)
-- ============================================================================

-- fcm_tokens
CREATE INDEX idx_fcm_tokens_token ON public.fcm_tokens USING btree (token);
CREATE INDEX idx_fcm_tokens_user_id ON public.fcm_tokens USING btree (user_id);

-- notification_aggregates
CREATE INDEX idx_notification_agg_user ON public.notification_aggregates USING btree (to_user_id, is_flushed);
CREATE INDEX idx_notification_agg_window ON public.notification_aggregates USING btree (window_expires_at);

-- notifications
CREATE UNIQUE INDEX idx_notifications_post_like_unique ON public.notifications
    USING btree (to_user_id, kind_key, ((context ->> 'liker_user_id'::text)), ((context ->> 'post_id'::text)))
    WHERE (kind_key = 'social.post_liked'::text);
CREATE INDEX idx_notifications_unread ON public.notifications
    USING btree (to_user_id, is_read) WHERE (is_read = false);
CREATE INDEX idx_notifications_user_time ON public.notifications
    USING btree (to_user_id, created_at DESC);


-- ============================================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.notifications                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_kinds             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_settings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_aggregates        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_aggregation_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_scores            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_hourly_caps       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_user_preferences  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fcm_tokens                     ENABLE ROW LEVEL SECURITY;

-- --- notifications (4 policies) ---------------------------------------------
CREATE POLICY n_self_read ON public.notifications
    FOR SELECT TO public
    USING (auth.uid() = to_user_id);

CREATE POLICY n_self_update ON public.notifications
    FOR UPDATE TO public
    USING (auth.uid() = to_user_id)
    WITH CHECK (auth.uid() = to_user_id);

CREATE POLICY n_self_delete ON public.notifications
    FOR DELETE TO public
    USING (auth.uid() = to_user_id);

CREATE POLICY n_block_insert ON public.notifications
    FOR INSERT TO public
    WITH CHECK (false);

-- --- notification_kinds (1 policy) ------------------------------------------
CREATE POLICY notification_kinds_read ON public.notification_kinds
    FOR SELECT TO anon, authenticated
    USING (true);

-- --- notification_settings (3 policies) --------------------------------------
CREATE POLICY ns_self_rw ON public.notification_settings
    FOR SELECT TO public
    USING (auth.uid() = user_id);

CREATE POLICY ns_self_ins ON public.notification_settings
    FOR INSERT TO public
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY ns_self_upd ON public.notification_settings
    FOR UPDATE TO public
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- --- notification_deliveries (2 policies) ------------------------------------
CREATE POLICY nd_self_read ON public.notification_deliveries
    FOR SELECT TO public
    USING (EXISTS (
        SELECT 1
        FROM notifications n
        WHERE n.id = notification_deliveries.notification_id
          AND n.to_user_id = auth.uid()
    ));

CREATE POLICY nd_block_dml ON public.notification_deliveries
    FOR ALL TO public
    USING (false)
    WITH CHECK (false);

-- --- notification_aggregates (1 policy) --------------------------------------
CREATE POLICY nagg_select ON public.notification_aggregates
    FOR SELECT TO authenticated
    USING (to_user_id = (SELECT auth.uid() AS uid));

-- --- notification_aggregation_rules (1 policy) --------------------------------
CREATE POLICY notification_aggregation_rules_read ON public.notification_aggregation_rules
    FOR SELECT TO anon, authenticated
    USING (true);

-- --- notification_scores (1 policy) -------------------------------------------
CREATE POLICY notification_scores_read ON public.notification_scores
    FOR SELECT TO anon, authenticated
    USING (true);

-- --- notification_hourly_caps (1 policy) --------------------------------------
CREATE POLICY notification_hourly_caps_read ON public.notification_hourly_caps
    FOR SELECT TO anon, authenticated
    USING (true);

-- --- notification_user_preferences (2 policies) --------------------------------
CREATE POLICY nup_select ON public.notification_user_preferences
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid() AS uid));

CREATE POLICY nup_write ON public.notification_user_preferences
    FOR ALL TO authenticated
    USING (user_id = (SELECT auth.uid() AS uid))
    WITH CHECK (user_id = (SELECT auth.uid() AS uid));

-- --- fcm_tokens (4 policies) ---------------------------------------------------
CREATE POLICY "Users can view their own FCM tokens" ON public.fcm_tokens
    FOR SELECT TO public
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own FCM tokens" ON public.fcm_tokens
    FOR INSERT TO public
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own FCM tokens" ON public.fcm_tokens
    FOR UPDATE TO public
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own FCM tokens" ON public.fcm_tokens
    FOR DELETE TO public
    USING (auth.uid() = user_id);


-- ============================================================================
-- 5. VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW public.v_notifications_feed AS
 SELECT id,
    to_user_id,
    kind_key,
    title,
    body,
    action_route,
    context,
    priority,
    created_at,
    is_read,
    read_at,
    ai_score,
    rank_score,
    clicked_at,
    interaction_count
   FROM notifications
  ORDER BY created_at DESC;

CREATE OR REPLACE VIEW public.v_notifications_ranked AS
 SELECT id,
    to_user_id,
    kind_key,
    title,
    body,
    action_route,
    context,
    priority,
    created_at,
    is_read,
    read_at,
    ai_score,
    rank_score,
    clicked_at,
    interaction_count,
    COALESCE(ai_score, 1::numeric) +
        CASE
            WHEN is_read = false THEN 2
            ELSE 0
        END::numeric + interaction_count::numeric * 1.5 - EXTRACT(epoch FROM now() - created_at) / 3600::numeric * 0.1 AS computed_rank
   FROM notifications n
  ORDER BY (COALESCE(ai_score, 1::numeric) +
        CASE
            WHEN is_read = false THEN 2
            ELSE 0
        END::numeric + interaction_count::numeric * 1.5 - EXTRACT(epoch FROM now() - created_at) / 3600::numeric * 0.1) DESC;

CREATE OR REPLACE VIEW public.v_unread_counts AS
 SELECT auth.uid() AS user_id,
    ( SELECT count(*) AS count
           FROM notifications n
          WHERE n.to_user_id = auth.uid() AND n.is_read = false) AS unread_total;

CREATE OR REPLACE VIEW public.v_activity_inbox AS
 WITH me AS (
         SELECT auth.uid() AS user_id
        ), nn AS (
         SELECT 'notification'::text AS item_type,
            n.title,
            COALESCE(n.action_route, '/inbox'::text) AS action_route,
            n.created_at,
            n.context
           FROM me
             JOIN notifications n ON n.to_user_id = me.user_id AND n.is_read = false
        )
 SELECT item_type,
    title,
    action_route,
    created_at,
    context
   FROM nn
  ORDER BY created_at DESC;


-- ============================================================================
-- 6. FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1 Core pipeline: event intake, aggregation, flushing
-- ----------------------------------------------------------------------------

-- [UPDATED 2026-07-12 after this snapshot — missing title branches + catalog-label
--  fallbacks replaced generic "New notification"/"New Activity"; see
--  supabase/schema/migrations/proper_notification_titles.sql]
CREATE OR REPLACE FUNCTION public.process_notification_event(p_to_user_id uuid, p_kind_key text, p_entity_type text, p_entity_id uuid, p_actor_user_id uuid, p_title text DEFAULT NULL::text, p_body text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_rule RECORD;
    v_existing RECORD;
    v_last_event timestamptz;
    v_new_actors uuid[];
    v_display_name text;
    v_final_title text;
BEGIN

    -- Prevent rapid duplicate spam (10 sec window)
    SELECT updated_at
    INTO v_last_event
    FROM public.notification_aggregates
    WHERE to_user_id = p_to_user_id
      AND kind_key = p_kind_key
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND is_flushed = false
      AND p_actor_user_id = ANY(actors)
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_last_event IS NOT NULL
       AND v_last_event > now() - interval '10 seconds'
    THEN
        RETURN;
    END IF;

    -- Look up actor display name for title generation
    SELECT display_name INTO v_display_name
    FROM public.profiles
    WHERE user_id = p_actor_user_id AND is_active = true
    LIMIT 1;

    v_display_name := COALESCE(v_display_name, 'Someone');

    -- Generate title if not provided
    IF p_title IS NOT NULL THEN
        v_final_title := p_title;
    ELSE
        v_final_title := CASE p_kind_key
            WHEN 'social.post_liked'           THEN v_display_name || ' liked your post'
            WHEN 'social.post_commented'       THEN v_display_name || ' commented on your post'
            WHEN 'social.post_reacted'         THEN v_display_name || ' reacted to your post'
            WHEN 'social.comment_liked'        THEN v_display_name || ' liked your comment'
            WHEN 'social.followed'             THEN v_display_name || ' started following you'
            WHEN 'social.circle_joined'        THEN v_display_name || ' joined your circle'
            WHEN 'social.mentioned_in_post'    THEN v_display_name || ' mentioned you in a post'
            WHEN 'social.mentioned_in_comment' THEN v_display_name || ' mentioned you in a comment'
            WHEN 'friend.requested'            THEN v_display_name || ' sent you a friend request'
            WHEN 'friend.accepted'             THEN v_display_name || ' accepted your friend request'
            WHEN 'game.invited'                THEN v_display_name || ' invited you to a game'
            WHEN 'game.join_request'           THEN v_display_name || ' wants to join your game'
            WHEN 'game.updated'                THEN 'A game you joined was updated'
            WHEN 'game.waitlist_promoted'      THEN 'You''ve been promoted from the waitlist'
            WHEN 'meetup.invited'              THEN v_display_name || ' invited you to a meetup'
            WHEN 'squad.invited'               THEN v_display_name || ' invited you to a squad'
            WHEN 'arena.payment_required'      THEN 'Payment required for your booking'
            WHEN 'reward.badge_awarded'        THEN 'You earned a new badge!'
            ELSE 'New notification'
        END;
    END IF;

    -- Try to get aggregation rule
    SELECT *
    INTO v_rule
    FROM public.notification_aggregation_rules
    WHERE kind_key = p_kind_key
      AND enabled = true;

    -- If NO aggregation rule → instant insert
    IF NOT FOUND THEN
        INSERT INTO public.notifications (
            to_user_id,
            kind_key,
            title,
            body,
            context,
            priority,
            is_read,
            created_at
        )
        VALUES (
            p_to_user_id,
            p_kind_key,
            v_final_title,
            p_body,
            jsonb_build_object(
                'entity_type', p_entity_type,
                'entity_id', p_entity_id,
                'actor_user_id', p_actor_user_id,
                'actor_display_name', v_display_name
            ),
            'normal',
            false,
            now()
        );

        RETURN;
    END IF;

    -- Aggregated path
    SELECT *
    INTO v_existing
    FROM public.notification_aggregates
    WHERE to_user_id = p_to_user_id
      AND kind_key = p_kind_key
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND is_flushed = false
      AND window_expires_at > now()
    LIMIT 1;

    IF FOUND THEN

        SELECT ARRAY(
            SELECT DISTINCT x
            FROM unnest(v_existing.actors || p_actor_user_id) AS t(x)
        )
        INTO v_new_actors;

        UPDATE public.notification_aggregates
        SET actors = v_new_actors,
            total_count = array_length(v_new_actors, 1),
            updated_at = now()
        WHERE id = v_existing.id;

    ELSE

        INSERT INTO public.notification_aggregates (
            to_user_id,
            kind_key,
            entity_type,
            entity_id,
            actors,
            total_count,
            window_started_at,
            window_expires_at
        )
        VALUES (
            p_to_user_id,
            p_kind_key,
            p_entity_type,
            p_entity_id,
            ARRAY[p_actor_user_id],
            1,
            now(),
            now() + make_interval(secs => v_rule.aggregation_window_seconds)
        );

    END IF;

END;
$function$;

-- [UPDATED 2026-07-12 after this snapshot — missing title branches + catalog-label
--  fallbacks replaced generic "New notification"/"New Activity"; see
--  supabase/schema/migrations/proper_notification_titles.sql]
CREATE OR REPLACE FUNCTION public.flush_notification_aggregates()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_record RECORD;
    v_count integer := 0;
    v_title text;
    v_body text;
    v_route text;
    v_context jsonb;
    v_display_name text;
BEGIN

FOR v_record IN
    SELECT *
    FROM public.notification_aggregates
    WHERE is_flushed = false
      AND window_expires_at <= now()
LOOP

    -- Look up the first actor's display name
    SELECT display_name INTO v_display_name
    FROM public.profiles
    WHERE user_id = v_record.actors[1] AND is_active = true
    LIMIT 1;

    v_display_name := COALESCE(v_display_name, 'Someone');
    v_body := NULL;

    -- ==============================
    -- SOCIAL: POST LIKED
    -- ==============================
    IF v_record.kind_key = 'social.post_liked' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' liked your post';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others liked your post';
        END IF;

        v_route := '/social-post-detail/' || v_record.entity_id::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'post_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: POST COMMENTED
    -- ==============================
    ELSIF v_record.kind_key = 'social.post_commented' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' commented on your post';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others commented on your post';
        END IF;

        v_route := '/social-post-detail/' || v_record.entity_id::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'post_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: POST REACTED
    -- ==============================
    ELSIF v_record.kind_key = 'social.post_reacted' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' reacted to your post';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others reacted to your post';
        END IF;

        v_route := '/social-post-detail/' || v_record.entity_id::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'post_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: FOLLOWED
    -- ==============================
    ELSIF v_record.kind_key = 'social.followed' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' started following you';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others started following you';
        END IF;

        v_route := '/user-profile/' || v_record.actors[1]::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'follower_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- SOCIAL: CIRCLE JOINED
    -- ==============================
    ELSIF v_record.kind_key = 'social.circle_joined' THEN

        IF v_record.total_count = 1 THEN
            v_title := v_display_name || ' joined your circle';
        ELSE
            v_title := v_display_name || ' and ' || (v_record.total_count - 1) || ' others joined your circle';
        END IF;

        v_route := '/user-profile/' || v_record.actors[1]::text;

        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id,
            'actor_user_id', v_record.actors[1],
            'actor_display_name', v_display_name,
            'actor_user_ids', to_jsonb(v_record.actors),
            'total_count', v_record.total_count
        );

    -- ==============================
    -- DEFAULT FALLBACK
    -- ==============================
    ELSE
        v_title := 'New Activity';
        v_route := null;
        v_context := jsonb_build_object(
            'entity_type', v_record.entity_type,
            'entity_id', v_record.entity_id
        );
    END IF;

    -- ==============================
    -- INSERT FINAL NOTIFICATION
    -- ==============================

    INSERT INTO public.notifications (
        to_user_id,
        kind_key,
        title,
        body,
        action_route,
        context,
        priority,
        ai_score,
        interaction_count,
        created_at
    )
    VALUES (
        v_record.to_user_id,
        v_record.kind_key,
        v_title,
        v_body,
        v_route,
        v_context,
        'normal',
        1,
        0,
        now()
    );

    -- mark as flushed
    UPDATE public.notification_aggregates
    SET is_flushed = true
    WHERE id = v_record.id;

    v_count := v_count + 1;

END LOOP;

RETURN v_count;

END;
$function$;

-- NOTE: references notification_aggregation_rules.force_instant, a column
-- that does not exist in the live table — likely stale/broken.
-- [DROPPED 2026-07-11 after this snapshot was generated — broken + zero callers;
--  see migrations drop_broken_dead_notification_functions.sql]
CREATE OR REPLACE FUNCTION public.evaluate_notification_strategy(p_to_user_id uuid, p_kind_key text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_rule RECORD;
    v_is_prime boolean;
BEGIN

    SELECT *
    INTO v_rule
    FROM public.notification_aggregation_rules
    WHERE kind_key = p_kind_key;

    IF v_rule.force_instant = true THEN
        RETURN true;
    END IF;

    -- Prime users get instant push
    SELECT public.user_has_feature(p_to_user_id, 'ai_priority')
    INTO v_is_prime;

    IF v_is_prime THEN
        RETURN true;
    END IF;

    RETURN false;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6.2 Scoring / ranking / rate limiting
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.calculate_notification_score(p_to_user uuid, p_kind_key text, p_actor_user uuid, p_entity_id uuid, p_total_count integer)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_rule RECORD;
    v_score numeric := 0;
    v_is_prime boolean := false;
    v_relationship numeric := 0;
BEGIN

    SELECT *
    INTO v_rule
    FROM public.notification_scores
    WHERE kind_key = p_kind_key
      AND is_enabled = true;

    IF NOT FOUND THEN
        RETURN 1;
    END IF;

    -- Base
    v_score := v_score + v_rule.base_weight;

    -- Actor count boost (scaled)
    v_score := v_score + (p_total_count * v_rule.actor_weight);

    -- Relationship boost (follower example)
    IF EXISTS (
        SELECT 1
        FROM public.profile_follows pf
        JOIN public.profiles p ON p.user_id = p_to_user
        WHERE pf.following_profile_id = p.id
    ) THEN
        v_relationship := 1;
    END IF;

    v_score := v_score + (v_relationship * v_rule.relationship_weight);

    -- Prime boost
    SELECT (plan_key = 'prime')
    INTO v_is_prime
    FROM public.user_subscriptions
    WHERE user_id = p_to_user
      AND is_active = true;

    IF v_is_prime THEN
        v_score := v_score + v_rule.plan_boost_weight;
    END IF;

    -- Recency boost
    v_score := v_score + v_rule.recency_weight;

    RETURN v_score;

END;
$function$;

CREATE OR REPLACE FUNCTION public.calculate_notification_rank(p_notification_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_record RECORD;
    v_rank numeric := 0;
    v_hours_since numeric;
BEGIN

    SELECT *
    INTO v_record
    FROM public.notifications
    WHERE id = p_notification_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Base AI score
    v_rank := COALESCE(v_record.ai_score, 1);

    -- Unread boost
    IF v_record.is_read = false THEN
        v_rank := v_rank + 2;
    END IF;

    -- Recency decay (hours)
    v_hours_since := EXTRACT(EPOCH FROM (now() - v_record.created_at)) / 3600;

    -- Apply decay
    v_rank := v_rank - (v_hours_since * 0.1);

    IF v_rank < 0 THEN
        v_rank := 0;
    END IF;

    RETURN v_rank;

END;
$function$;

CREATE OR REPLACE FUNCTION public.can_send_notification_now(p_user_id uuid, p_priority notify_priority)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_plan text;
    v_cap integer;
    v_sent_count integer;
BEGIN

    -- Get active plan
    SELECT plan_key
    INTO v_plan
    FROM public.user_subscriptions
    WHERE user_id = p_user_id
      AND is_active = true
    LIMIT 1;

    IF v_plan IS NULL THEN
        v_plan := 'kickoff';
    END IF;

    -- Get cap
    SELECT max_per_hour
    INTO v_cap
    FROM public.notification_hourly_caps
    WHERE plan_key = v_plan
      AND priority = p_priority;

    IF v_cap IS NULL THEN
        RETURN true; -- no cap rule = allow
    END IF;

    -- Count last hour notifications
    SELECT count(*)
    INTO v_sent_count
    FROM public.notifications
    WHERE to_user_id = p_user_id
      AND priority = p_priority
      AND created_at >= now() - interval '1 hour';

    RETURN v_sent_count < v_cap;

END;
$function$;

CREATE OR REPLACE FUNCTION public.allow_social_notifications(p_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select case
           when public.is_benched(p_user) then not coalesce(us.suppress_social_notifications, false)
           else true
         end
  from public.user_status us
  where us.user_id = p_user
  union all
  select true
  where not exists (select 1 from public.user_status where user_id = p_user)
  limit 1
$function$;

-- ----------------------------------------------------------------------------
-- 6.3 Read / interaction RPCs
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
begin
  update public.notifications
  set is_read = true,
      read_at = now()
  where id = p_id
    and to_user_id = me;
end;
$function$;

-- NOTE: references notifications.user_id, which does not exist (the column is
-- to_user_id) — this legacy RPC would fail at runtime if called.
-- [DROPPED 2026-07-11 after this snapshot was generated — broken + zero callers;
--  see migrations drop_broken_dead_notification_functions.sql]
CREATE OR REPLACE FUNCTION public.rpc_mark_notification_read(p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.notifications
  set is_read = true, read_at = now()
  where id = p_id and user_id = auth.uid();

  if not found then
    raise exception using errcode='P0001', message='not_found_or_not_owner';
  end if;

  return 'ok';
end;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_notification_clicked(p_notification_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_kind text;
    v_user uuid;
BEGIN

    -- Update notification
    UPDATE public.notifications
    SET clicked_at = now(),
        interaction_count = interaction_count + 1,
        is_read = true,
        read_at = now()
    WHERE id = p_notification_id
      AND to_user_id = auth.uid()
    RETURNING kind_key, to_user_id
    INTO v_kind, v_user;

    IF NOT FOUND THEN
        RETURN 'not_found';
    END IF;

    -- Adaptive engagement learning
    INSERT INTO public.notification_user_preferences
    (user_id, kind_key, engagement_score)
    VALUES
    (v_user, v_kind, 1.1)
    ON CONFLICT (user_id, kind_key)
    DO UPDATE
    SET engagement_score =
        notification_user_preferences.engagement_score + 0.1;

    RETURN 'ok';

END;
$function$;

CREATE OR REPLACE FUNCTION public.increment_notification_interaction(p_id uuid)
 RETURNS void
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  UPDATE public.notifications
     SET clicked_at = now(),
         interaction_count = COALESCE(interaction_count, 0) + 1
   WHERE id = p_id
     AND to_user_id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.rpc_broadcast_inapp_notification(p_title text, p_body text, p_route text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inserted integer;
BEGIN
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title is required';
  END IF;

  INSERT INTO public.notifications (to_user_id, kind_key, title, body, action_route, context, priority)
  SELECT p.user_id,
         'system.announcement',
         p_title,
         p_body,
         p_route,
         jsonb_build_object('broadcast', true),
         'normal'
  FROM public.profiles p
  WHERE p.is_active = true;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6.4 Rendering / templates
-- NOTE: depends on a notification_templates table (outside snapshot scope)
-- and public.user_settings.locale.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.render_notification(p_type_key text, p_user uuid, p_context jsonb)
 RETURNS TABLE(title text, body text, action_route text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  loc text := coalesce((select locale from public.user_settings where user_id=p_user),'en');
  tt text; bt text; aroute text;
begin
  select title_template, body_template, action_route
  into tt, bt, aroute
  from public.notification_templates
  where key = p_type_key and locale = loc
  order by version desc
  limit 1;

  if tt is null then
    -- Fallback EN
    select title_template, body_template, action_route
    into tt, bt, aroute
    from public.notification_templates
    where key = p_type_key and locale = 'en'
    order by version desc
    limit 1;
  end if;

  -- VERY basic rendering: replace {{key}} with context->>key
  -- For anything complex, do it in the edge worker.
  title := coalesce(tt,'Notification');
  body  := coalesce(bt,'You have an update');
  action_route := coalesce(aroute,'/inbox');

  -- Replace {{..}} tokens present in title/body/route
  -- token list from keys in p_context
  perform 1; -- no-op

  -- simple replace loop in SQL:
  declare k text; v text;
  begin
    for k, v in
      select key, value from json_each_text(coalesce(p_context,'{}'::jsonb))
    loop
      title := replace(title, '{{'||k||'}}', v);
      body  := replace(body,  '{{'||k||'}}', v);
      action_route := replace(action_route, '{{'||k||'}}', v);
    end loop;
  end;

  return next;
end;
$function$;

-- ----------------------------------------------------------------------------
-- 6.5 Push delivery helpers (FCM / edge-function trigger secret)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_user_fcm_tokens(target_user_id uuid)
 RETURNS TABLE(token text, platform text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN QUERY
    SELECT fcm_tokens.token, fcm_tokens.platform
    FROM public.fcm_tokens
    WHERE fcm_tokens.user_id = target_user_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_push_trigger_secret()
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'push_trigger_secret' LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION public.update_fcm_tokens_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$;

-- Fires the send-push-notification edge function (via pg_net) on every
-- notifications insert whose kind's default_channels includes 'push',
-- honoring per-user push_enabled / muted_kinds / quiet hours.
CREATE OR REPLACE FUNCTION public.trg_push_on_notification_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  _channels text[];
  _anon_key text;
  _trigger_secret text;
  _settings public.notification_settings%ROWTYPE;
  _has_settings boolean := false;
  _tz text;
  _now_min int;
  _in_quiet boolean;
  _is_high boolean;
BEGIN
  -- Only proceed for kinds whose default channels include push.
  SELECT default_channels INTO _channels
  FROM public.notification_kinds
  WHERE key = NEW.kind_key;

  IF _channels IS NULL OR NOT ('push' = ANY(_channels)) THEN
    RETURN NEW;
  END IF;

  -- Per-user preference enforcement. The in-app notification row is left
  -- untouched (this trigger only gates the push); we just decide whether to
  -- fire the HTTP call.
  SELECT * INTO _settings
  FROM public.notification_settings
  WHERE user_id = NEW.to_user_id;
  _has_settings := FOUND;

  IF _has_settings THEN
    -- Hard off: user disabled push entirely.
    IF NOT COALESCE(_settings.push_enabled, true) THEN
      RETURN NEW;
    END IF;

    -- Kind muted by the user.
    IF NEW.kind_key = ANY(COALESCE(_settings.muted_kinds, '{}')) THEN
      RETURN NEW;
    END IF;

    -- Quiet hours (minutes-since-midnight in the user's tz, wraps midnight).
    IF _settings.quiet_start_min IS NOT NULL
       AND _settings.quiet_end_min IS NOT NULL THEN
      _tz := COALESCE(_settings.tz, 'Asia/Dubai');
      _now_min := EXTRACT(hour FROM (now() AT TIME ZONE _tz))::int * 60
                + EXTRACT(minute FROM (now() AT TIME ZONE _tz))::int;

      IF _settings.quiet_start_min <= _settings.quiet_end_min THEN
        _in_quiet := _now_min >= _settings.quiet_start_min
                 AND _now_min <  _settings.quiet_end_min;
      ELSE
        _in_quiet := _now_min >= _settings.quiet_start_min
                  OR _now_min <  _settings.quiet_end_min;
      END IF;

      IF _in_quiet THEN
        _is_high := NEW.priority::text IN ('high', 'urgent');
        -- allow_all_override sends everything; allow_high_priority_override
        -- sends only high/urgent. Otherwise suppress during quiet hours.
        IF COALESCE(_settings.allow_all_override, false) THEN
          NULL; -- send
        ELSIF COALESCE(_settings.allow_high_priority_override, false)
              AND _is_high THEN
          NULL; -- send
        ELSE
          RETURN NEW; -- suppress
        END IF;
      END IF;
    END IF;
  END IF;

  SELECT decrypted_secret INTO _anon_key
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_anon_key'
  LIMIT 1;

  IF _anon_key IS NULL THEN
    RAISE WARNING 'trg_push_on_notification_insert: supabase_anon_key not found in vault';
    RETURN NEW;
  END IF;

  SELECT decrypted_secret INTO _trigger_secret
  FROM vault.decrypted_secrets
  WHERE name = 'push_trigger_secret'
  LIMIT 1;

  IF _trigger_secret IS NULL THEN
    RAISE WARNING 'trg_push_on_notification_insert: push_trigger_secret not found in vault';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url    := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-push-notification',
    body   := jsonb_build_object(
      'user_id', NEW.to_user_id,
      'title',   COALESCE(NEW.title, ''),
      'body',    COALESCE(NEW.body, ''),
      'data',    jsonb_build_object(
        'kind_key',     NEW.kind_key,
        'action_route', COALESCE(NEW.action_route, ''),
        'entity_id',    COALESCE(NEW.id::text, '')
      )
    ),
    headers := jsonb_build_object(
      'Content-Type',     'application/json',
      'Authorization',    'Bearer ' || _anon_key,
      'x-trigger-secret', _trigger_secret
    )
  );

  RETURN NEW;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6.6 Domain event trigger functions (feed process_notification_event)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_likes_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_target_uid   uuid;
  v_activity_type text;
BEGIN
  IF TG_OP != 'INSERT' THEN RETURN NEW; END IF;

  SELECT pa.actor_user_id, pa.activity_type
    INTO v_target_uid, v_activity_type
  FROM public.public_activities pa
  WHERE pa.id = NEW.parent_activity_id;

  -- Don't notify if liking your own content
  IF v_target_uid IS NULL OR v_target_uid = NEW.actor_user_id THEN RETURN NEW; END IF;

  PERFORM public.process_notification_event(
    v_target_uid,
    CASE v_activity_type
      WHEN 'comment' THEN 'social.comment_liked'
      ELSE 'social.post_liked'
    END,
    v_activity_type,
    NEW.parent_activity_id,
    NEW.actor_user_id,
    NULL,
    NULL
  );
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_public_activities_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_target_user_id uuid;
  v_kind_key       text;
BEGIN
  -- Only act on INSERT of non-deleted activities that have a target
  IF TG_OP <> 'INSERT' THEN RETURN NEW; END IF;
  IF NEW.is_deleted THEN RETURN NEW; END IF;
  IF NEW.target_profile_id IS NULL THEN RETURN NEW; END IF;

  -- Skip self-actions
  IF NEW.target_profile_id = NEW.actor_profile_id THEN RETURN NEW; END IF;

  -- Only handle types NOT already covered by per-domain notification triggers
  -- (comment → trg_post_comment_notify, reaction → trg_post_reaction_notify,
  --  follow → trg_profile_follow_notify, badge → trg_badge_awarded_notify)
  IF NEW.activity_type NOT IN ('game_join', 'meetup_join') THEN
    RETURN NEW;
  END IF;

  -- Resolve target profile → user_id
  SELECT user_id INTO v_target_user_id
  FROM public.profiles WHERE id = NEW.target_profile_id;

  IF v_target_user_id IS NULL THEN RETURN NEW; END IF;
  IF v_target_user_id = NEW.actor_user_id THEN RETURN NEW; END IF;

  v_kind_key := CASE NEW.activity_type
    WHEN 'game_join'   THEN 'game.player_joined'
    WHEN 'meetup_join' THEN 'meetup.player_joined'
    ELSE NULL
  END;

  IF v_kind_key IS NULL THEN RETURN NEW; END IF;

  PERFORM public.process_notification_event(
    v_target_user_id,
    v_kind_key,
    NEW.activity_type,
    NEW.id,
    NEW.actor_user_id
  );

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_post_comment_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_post_author uuid;
BEGIN
    SELECT author_user_id INTO v_post_author
    FROM public.posts WHERE id = NEW.parent_activity_id;

    IF v_post_author IS NULL OR v_post_author = NEW.author_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_post_author,
        'social.post_commented',
        'post',
        NEW.parent_activity_id,
        NEW.author_user_id,
        NULL,
        left(NEW.body, 200)
    );
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_post_reaction_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_post_author uuid;
BEGIN
    SELECT author_user_id INTO v_post_author
    FROM public.posts WHERE id = NEW.parent_activity_id;

    IF v_post_author IS NULL OR v_post_author = NEW.actor_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_post_author,
        'social.post_reacted',
        'post',
        NEW.parent_activity_id,
        NEW.actor_user_id
    );
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_post_mention_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_mentioned_uid uuid;
    v_post_author_uid uuid;
    v_post_body text;
BEGIN
    SELECT user_id INTO v_mentioned_uid
    FROM public.profiles
    WHERE id = NEW.mentioned_profile_id;

    SELECT p.author_user_id, left(p.body, 200)
    INTO v_post_author_uid, v_post_body
    FROM public.posts p
    WHERE p.id = NEW.post_id;

    IF v_mentioned_uid IS NULL
       OR v_post_author_uid IS NULL
       OR v_mentioned_uid = v_post_author_uid THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_mentioned_uid,
        'social.mentioned_in_post',
        'post',
        NEW.post_id,
        v_post_author_uid,
        NULL,
        v_post_body
    );

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_comment_mention_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_mentioned_uid      uuid;
  v_comment_author_uid uuid;
  v_comment_body       text;
BEGIN
  SELECT user_id INTO v_mentioned_uid FROM public.profiles WHERE id = NEW.mentioned_profile_id;
  SELECT pc.author_user_id, left(pc.body, 200) INTO v_comment_author_uid, v_comment_body
    FROM public.comments pc WHERE pc.id = NEW.comment_id;
  IF v_mentioned_uid IS NULL OR v_comment_author_uid IS NULL
     OR v_mentioned_uid = v_comment_author_uid THEN RETURN NEW; END IF;
  PERFORM public.process_notification_event(
    v_mentioned_uid, 'social.mentioned_in_comment', 'comment',
    NEW.comment_id, v_comment_author_uid, NULL, v_comment_body);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_profile_follow_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_followed_user uuid;
    v_follower_user uuid;
BEGIN

    -- Get followed user_id
    SELECT user_id
    INTO v_followed_user
    FROM public.profiles
    WHERE id = NEW.following_profile_id;

    -- Get follower user_id
    SELECT user_id
    INTO v_follower_user
    FROM public.profiles
    WHERE id = NEW.follower_profile_id;

    -- Prevent self notification
    IF v_followed_user IS NULL OR v_followed_user = v_follower_user THEN
        RETURN NEW;
    END IF;

    -- Route to AI engine
    PERFORM public.process_notification_event(
        v_followed_user,
        'social.followed',
        'profile',
        NEW.following_profile_id,
        v_follower_user
    );

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_circle_join_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_circle_owner uuid;
BEGIN

    SELECT p.user_id
    INTO v_circle_owner
    FROM public.circles c
    JOIN public.profiles p ON p.id = c.owner_profile_id
    WHERE c.id = NEW.circle_id;

    IF v_circle_owner IS NULL THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        v_circle_owner,
        'social.circle_joined',
        'circle',
        NEW.circle_id,
        (
            SELECT user_id
            FROM public.profiles
            WHERE id = NEW.member_profile_id
        )
    );

    RETURN NEW;

END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_friend_request_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    IF NEW.from_user = NEW.to_user THEN
        RETURN NEW;
    END IF;

    IF NEW.action = 'requested' THEN
        PERFORM public.process_notification_event(
            NEW.to_user,
            'friend.requested',
            'friend_request',
            NEW.id,
            NEW.from_user
        );
    ELSIF NEW.action = 'accepted' THEN
        PERFORM public.process_notification_event(
            NEW.from_user,
            'friend.accepted',
            'friend_request',
            NEW.id,
            NEW.to_user
        );
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_game_invite_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_inviter_uid uuid;
BEGIN
    SELECT user_id INTO v_inviter_uid
    FROM public.profiles
    WHERE id = NEW.invited_by_profile_id;

    IF v_inviter_uid IS NULL OR v_inviter_uid = NEW.to_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        NEW.to_user_id,
        'game.invited',
        'game',
        NEW.game_id,
        v_inviter_uid
    );

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_game_join_request_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_host_uid uuid;
BEGIN
  SELECT creator_user_id INTO v_host_uid FROM public.games WHERE id = NEW.game_id;
  IF v_host_uid IS NULL OR v_host_uid = NEW.from_user_id THEN RETURN NEW; END IF;
  PERFORM public.process_notification_event(v_host_uid, 'game.join_request', 'game', NEW.game_id, NEW.from_user_id);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_game_updated_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_player RECORD;
BEGIN
  IF OLD.is_cancelled = false AND NEW.is_cancelled = true THEN
    FOR v_player IN
      SELECT user_id FROM public.game_roster WHERE game_id = NEW.id AND user_id <> NEW.creator_user_id
    LOOP
      PERFORM public.process_notification_event(v_player.user_id, 'game.updated', 'game', NEW.id, NEW.creator_user_id);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_game_waitlist_promoted_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_host_uid uuid; v_in_roster boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM public.game_roster WHERE game_id = OLD.game_id AND user_id = OLD.user_id) INTO v_in_roster;
  IF NOT v_in_roster THEN RETURN OLD; END IF;
  SELECT creator_user_id INTO v_host_uid FROM public.games WHERE id = OLD.game_id;
  PERFORM public.process_notification_event(OLD.user_id, 'game.waitlist_promoted', 'game', OLD.game_id, COALESCE(v_host_uid, OLD.user_id));
  RETURN OLD;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_meetup_invite_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    IF NEW.created_by = NEW.to_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        NEW.to_user_id,
        'meetup.invited',
        'meetup',
        NEW.meetup_id,
        NEW.created_by
    );

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_squad_invite_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_inviter_uid uuid;
BEGIN
    SELECT user_id INTO v_inviter_uid
    FROM public.profiles
    WHERE id = NEW.created_by_profile_id;

    IF v_inviter_uid IS NULL OR v_inviter_uid = NEW.to_user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.process_notification_event(
        NEW.to_user_id,
        'squad.invited',
        'squad',
        NEW.squad_id,
        v_inviter_uid
    );

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_badge_awarded_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.process_notification_event(
        NEW.user_id,
        'reward.badge_awarded',
        'badge',
        NEW.badge_id,
        NEW.user_id
    );

    RETURN NEW;
END;
$function$;

-- NOTE: function exists but no trigger is currently attached to any table
-- (no bookings trigger found in pg_trigger).
CREATE OR REPLACE FUNCTION public.trg_booking_payment_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.process_notification_event(
        NEW.user_id,
        'arena.payment_required',
        'booking',
        NEW.id,
        NEW.user_id
    );

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_welcome_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Once per user: a user may have multiple profiles, and we never re-welcome.
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE to_user_id = NEW.user_id AND kind_key = 'auth.welcome'
  ) THEN
    BEGIN
      INSERT INTO public.notifications (
        to_user_id, kind_key, title, body, action_route, context, created_at
      )
      VALUES (
        NEW.user_id,
        'auth.welcome',
        'Welcome to Dabbler! 🎉',
        'Find games, join events, and connect with players near you.',
        '/home',
        '{}'::jsonb,
        now()
      );
    EXCEPTION WHEN OTHERS THEN
      -- Never let a welcome failure break user creation.
      RAISE WARNING 'trg_welcome_notify failed for user %: %', NEW.user_id, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6.7 Moderation admin notifications
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_admins_of_report()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications (to_user_id, kind_key, title, body, context, priority)
  SELECT
    a.user_id,
    'moderation.report_submitted',
    'New content report',
    format('%s reported for %s', NEW.target_type::text, NEW.reason::text),
    jsonb_build_object(
      'report_id', NEW.id,
      'target_type', NEW.target_type,
      'target_id', NEW.target_id,
      'reason', NEW.reason
    ),
    'high'
  FROM public.app_admins a;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_admins_of_block()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications (to_user_id, kind_key, title, body, context, priority)
  SELECT
    a.user_id,
    'moderation.user_blocked',
    'User block recorded',
    'A user blocked another user.',
    jsonb_build_object(
      'blocker_user_id', NEW.blocker_user_id,
      'blocked_user_id', NEW.blocked_user_id
    ),
    'low'
  FROM public.app_admins a;
  RETURN NEW;
END;
$function$;


-- ============================================================================
-- 7. TRIGGERS
-- (All non-internal triggers whose function matches %notif% / %push%,
--  plus the fcm_tokens updated_at trigger.)
-- ============================================================================

-- On the notifications table itself: push fan-out
CREATE TRIGGER trg_push_on_notification_insert AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION trg_push_on_notification_insert();

-- Social domain
CREATE TRIGGER tr_likes_notify AFTER INSERT ON public.likes FOR EACH ROW EXECUTE FUNCTION fn_likes_notify();
CREATE TRIGGER tr_public_activities_notify AFTER INSERT ON public.public_activities FOR EACH ROW EXECUTE FUNCTION fn_public_activities_notify();
CREATE TRIGGER trg_post_comment_notify AFTER INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION trg_post_comment_notify();
CREATE TRIGGER trg_post_reaction_notify AFTER INSERT ON public.reactions FOR EACH ROW EXECUTE FUNCTION trg_post_reaction_notify();
CREATE TRIGGER trg_post_mention_notify AFTER INSERT ON public.post_mentions FOR EACH ROW EXECUTE FUNCTION trg_post_mention_notify();
CREATE TRIGGER trg_comment_mention_notify AFTER INSERT ON public.comment_mentions FOR EACH ROW EXECUTE FUNCTION trg_comment_mention_notify();
CREATE TRIGGER trg_profile_follow_notify AFTER INSERT ON public.profile_follows FOR EACH ROW EXECUTE FUNCTION trg_profile_follow_notify();
CREATE TRIGGER trg_circle_join_notify AFTER INSERT ON public.circle_members FOR EACH ROW EXECUTE FUNCTION trg_circle_join_notify();

-- Friends
CREATE TRIGGER trg_friend_request_notify AFTER INSERT ON public.friend_requests_audit FOR EACH ROW EXECUTE FUNCTION trg_friend_request_notify();

-- Games / meetups / squads
CREATE TRIGGER trg_game_invite_notify AFTER INSERT ON public.game_invites FOR EACH ROW EXECUTE FUNCTION trg_game_invite_notify();
CREATE TRIGGER trg_game_join_request_notify AFTER INSERT ON public.game_join_requests FOR EACH ROW EXECUTE FUNCTION trg_game_join_request_notify();
CREATE TRIGGER trg_game_updated_notify AFTER UPDATE ON public.games FOR EACH ROW WHEN ((old.is_cancelled IS DISTINCT FROM new.is_cancelled)) EXECUTE FUNCTION trg_game_updated_notify();
CREATE TRIGGER trg_game_waitlist_promoted_notify AFTER DELETE ON public.game_waitlist FOR EACH ROW EXECUTE FUNCTION trg_game_waitlist_promoted_notify();
CREATE TRIGGER trg_meetup_invite_notify AFTER INSERT ON public.meetup_invites FOR EACH ROW EXECUTE FUNCTION trg_meetup_invite_notify();
CREATE TRIGGER trg_squad_invite_notify AFTER INSERT ON public.squad_invites FOR EACH ROW EXECUTE FUNCTION trg_squad_invite_notify();

-- Rewards / onboarding
CREATE TRIGGER trg_badge_awarded_notify AFTER INSERT ON public.user_badges FOR EACH ROW EXECUTE FUNCTION trg_badge_awarded_notify();
CREATE TRIGGER trg_welcome_notify AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION trg_welcome_notify();

-- Moderation (admin notifications)
CREATE TRIGGER trg_notify_admins_of_report AFTER INSERT ON public.moderation_reports FOR EACH ROW EXECUTE FUNCTION notify_admins_of_report();
CREATE TRIGGER trg_notify_admins_of_block AFTER INSERT ON public.user_blocks FOR EACH ROW EXECUTE FUNCTION notify_admins_of_block();

-- FCM token bookkeeping
CREATE TRIGGER update_fcm_tokens_timestamp BEFORE UPDATE ON public.fcm_tokens FOR EACH ROW EXECUTE FUNCTION update_fcm_tokens_updated_at();


-- ============================================================================
-- 8. PG_CRON JOBS
-- ============================================================================
-- Live cron.job entry (jobid 2, active = true, nodename = localhost):
--
--   jobname:  flush_notifications_every_10_seconds
--   schedule: 10 seconds
--   command:  SELECT public.flush_notification_aggregates();
--
-- Recreate with:
-- SELECT cron.schedule(
--   'flush_notifications_every_10_seconds',
--   '10 seconds',
--   'SELECT public.flush_notification_aggregates();'
-- );


-- ============================================================================
-- END OF SNAPSHOT
-- ============================================================================
