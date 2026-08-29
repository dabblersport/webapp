-- Visibility gate on v_game_card.
--
-- The view runs with owner rights over the RLS-locked games table and had
-- no per-viewer filtering, so anyone with a game id could read followers /
-- private games through it (game details screen, feed active-games rail,
-- search). The nearby RPC and join path were already gated via
-- can_view_with_scope — this closes the direct-read hole so listing
-- visibility is enforced everywhere the same way.
--
-- A game row is visible when the caller is:
--   • the creator, or an admin,
--   • an active roster member or waitlisted player (participants keep
--     access even if they later unfollow the host),
--   • or passes can_view_with_scope (public → everyone incl. anonymous,
--     followers → follower of the host, private → creator only).

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
          where ((gr.game_id = g.id) and (gr.status = 'active'::text))) as roster_count
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
