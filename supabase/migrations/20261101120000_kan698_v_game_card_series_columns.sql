-- KAN-698 (read-path support): v_game_card gains series_id, series_frequency, series_ends_on.
-- CTO ruling dreq-933fc018. Additive: CREATE OR REPLACE VIEW appends three columns at the END;
-- every existing column, its order, the view options and the GRANTs are unchanged (no DROP, no
-- RLS change, no GRANT change, no security_invoker change). Body copied from
-- 20261008140000_game_price_meetup_setting.sql Step 3 (verified identical to the live definition).
-- game_series has no `frequency` column (its recurrence is `rrule`, weekly/biweekly only per the
-- KAN-671 CHECK), so series_frequency is derived: 'biweekly' when rrule has INTERVAL=2, else 'weekly';
-- NULL for one-off games. The view runs as its owner, so game_series stays owner-only for clients.

CREATE OR REPLACE VIEW public.v_game_card AS
 SELECT g.id,
    g.title,
    g.game_type,
    g.start_at,
    g.end_at,
    g.capacity,
    g.bench_slots,
    g.capacity + g.bench_slots AS total_slots,
    g.min_skill,
    g.max_skill,
    g.listing_visibility,
    g.join_policy,
    g.allow_spectators,
    g.allows_waitlist,
    g.is_cancelled,
    g.rules,
    g.created_at,
    g.updated_at,
    g.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en AS variant_name_en,
    sv.name_ar AS variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    g.creator_profile_id,
    cp.username AS creator_username,
    cp.display_name AS creator_display_name,
    cp.avatar_url AS creator_avatar_url,
    g.geo_location_id,
    g.area_id,
    a.name AS area_name,
    g.venue_space_id,
    g.venue_id,
    vs.name_en AS venue_space_name,
    v.name_en AS venue_name,
    g.joining_rule,
    g.cost_cover,
    ( SELECT count(*) AS count
           FROM game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text AND (gr.role = 'player'::text OR gr.role = 'host'::text AND g.game_type = 'hosted'::text)) AS roster_count,
    g.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
    COALESCE(( SELECT pv.verified
           FROM profile_verifications pv
          WHERE pv.profile_id = g.creator_profile_id), false) OR (EXISTS ( SELECT 1
           FROM organiser o
          WHERE o.profile_id = g.creator_profile_id AND o.sport = s.sport_key AND o.is_verified AND o.is_active)) AS host_verified,
    (EXISTS ( SELECT 1
           FROM likes lk
          WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
    st_y(gl.location::geometry) AS latitude,
    st_x(gl.location::geometry) AS longitude,
    (( SELECT count(*) AS count
           FROM favorites f
          WHERE f.game_id = g.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM favorites f
          WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
    g.price_aed,
    g.series_id,
    CASE WHEN s2.id IS NULL THEN NULL WHEN s2.rrule LIKE '%INTERVAL=2%' THEN 'biweekly' ELSE 'weekly' END AS series_frequency,
    s2.ends_on AS series_ends_on
   FROM games g
     LEFT JOIN sports s ON s.id = g.sport_id
     LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN profiles cp ON cp.id = g.creator_profile_id
     LEFT JOIN areas a ON a.id = g.area_id
     LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, g.venue_id)
     LEFT JOIN geo_locations gl ON gl.id = g.geo_location_id
     LEFT JOIN game_series s2 ON s2.id = g.series_id
  WHERE g.creator_user_id = auth.uid() OR is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id);
