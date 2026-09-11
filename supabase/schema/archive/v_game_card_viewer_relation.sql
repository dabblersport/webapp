-- Per-viewer relation flags on v_game_card: is_creator / is_joined.
--
-- Drives the "My games" pinned section on the Games tab (Created / Joined
-- chips). The view runs with owner rights but auth.uid() resolves to the
-- caller, so the flags are viewer-relative — same mechanism as the
-- visibility gate (v_game_card_visibility_gate.sql), which is kept as-is.
-- Columns are appended at the end (CREATE OR REPLACE VIEW requirement).

create or replace view public.v_game_card as
select g.id,
    g.title,
    g.game_type,
    g.start_at,
    g.end_at,
    g.capacity,
    g.bench_slots,
    (g.capacity + g.bench_slots) as total_slots,
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
    s.name_en as sport_name_en,
    s.name_ar as sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en as variant_name_en,
    sv.name_ar as variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    g.creator_profile_id,
    g.creator_user_id,
    cp.username as creator_username,
    cp.display_name as creator_display_name,
    cp.avatar_url as creator_avatar_url,
    g.geo_location_id,
    g.area_id,
    a.name as area_name,
    g.venue_space_id,
    g.venue_id,
    vs.name_en as venue_space_name,
    v.name_en as venue_name,
    g.joining_rule,
    g.cost_cover,
    ( select count(*) as count
           from game_roster gr
          where ((gr.game_id = g.id) and (gr.status = 'active'::text))) as roster_count,
    (g.creator_user_id = auth.uid()) as is_creator,
    exists (
      select 1 from game_roster grv
      where grv.game_id = g.id
        and grv.user_id = auth.uid()
        and grv.status = 'active'
    ) as is_joined
   from ((((((games g
     left join sports s on ((s.id = g.sport_id)))
     left join sport_variants sv on ((sv.id = g.sport_variant_id)))
     left join profiles cp on ((cp.id = g.creator_profile_id)))
     left join areas a on ((a.id = g.area_id)))
     left join venue_spaces vs on ((vs.id = g.venue_space_id)))
     left join venues v on ((v.id = coalesce(vs.venue_id, g.venue_id))))
  where g.creator_user_id = auth.uid()
     or public.is_admin(auth.uid())
     or exists (
          select 1 from game_roster grm
          where grm.game_id = g.id
            and grm.user_id = auth.uid()
            and grm.status = 'active'
        )
     or exists (
          select 1 from game_waitlist gw
          where gw.game_id = g.id
            and gw.user_id = auth.uid()
        )
     or public.can_view_with_scope(
          auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
        );
