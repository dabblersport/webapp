-- KAN-950: the games listing refresh nudge reaches a client.
--
-- The app's games listing subscribes to Realtime postgres_changes (KAN-755). Realtime checks
-- the subscriber's SELECT RLS per change. public.games has RLS on and no policy by design (the
-- definer funnel, docs/SCHEMA.md T-024), so no games change ever reached a client.
--
-- Not done: a SELECT policy on public.games. Several invoker gates use "the caller sees no games
-- row" as their deny signal: trgfn_joinreq_block_frozen_guard (KAN-862 P1b) is what stops a
-- direct client insert into game_join_requests, whose INSERT policy is only from_user_id =
-- auth.uid(). The roster, waitlist and invite guards, trgfn_posts_set_geo, _user_hosted_game,
-- game_is_joinable and _recent_activity_score all branch on it too. A policy would flip all of
-- them, and it would also put squad_id, sport_specific_data and event_id on PostgREST, which
-- v_game_card does not return. Column grants would not help: the gates read only games.id.
--
-- Done instead: a dedicated nudge table that carries nothing but (game_id, changed_at). It is
-- readable through one SELECT policy that uses _can_view_game, the same predicate as
-- v_game_card, and it is published for Realtime. A SECURITY DEFINER trigger on games upserts
-- it on insert and whenever games.event_changed_at moves (KAN-949 bumps that on every listing
-- edit of the events row: title, time, cancel, place, ...). The trigger never deletes. Realtime
-- does not apply RLS to DELETE, so a deleted nudge row would broadcast its game_id to every
-- subscriber; no client role holds DELETE either.
--
-- App change needed (not in this migration): the games listing subscribes to
-- 'game_listing_nudges' instead of 'games' (listing_refresh.dart, listingChangeFeedProvider),
-- with a SupabaseConfig constant for the table name.

create table public.game_listing_nudges (
  game_id    uuid        primary key,
  changed_at timestamptz not null default now()
);

comment on table public.game_listing_nudges is
  'KAN-950: Realtime refresh nudge for the games listing. One row per game, upserted by '
  'the trg_kan950_games_listing_nudge_* triggers on games. No FK and never deleted: Realtime does not apply RLS to '
  'DELETE. Readable only where _can_view_game(game_id).';

alter table public.game_listing_nudges enable row level security;

-- pg_default_acl hands postgres-owned tables to anon and authenticated (rxtm). Take it all back,
-- then grant exactly the read Realtime needs.
revoke all on table public.game_listing_nudges from public, anon, authenticated;
grant select on table public.game_listing_nudges to authenticated;
grant all on table public.game_listing_nudges to service_role;

create policy game_listing_nudges_select_visible
  on public.game_listing_nudges
  for select
  to authenticated
  using (public._can_view_game(game_id));

create function public.kan950_games_listing_nudge()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $function$
begin
  insert into public.game_listing_nudges as n (game_id, changed_at)
  values (new.id, coalesce(new.event_changed_at, now()))
  on conflict (game_id) do update set changed_at = excluded.changed_at;
  return null;
end
$function$;

revoke all on function public.kan950_games_listing_nudge() from public, anon, authenticated;

-- Two triggers because Postgres forbids OLD in an INSERT trigger's WHEN: a new game nudges, and
-- an update nudges only when event_changed_at actually moved.
create trigger trg_kan950_games_listing_nudge_ins
  after insert on public.games
  for each row
  execute function public.kan950_games_listing_nudge();

create trigger trg_kan950_games_listing_nudge_upd
  after update of event_changed_at on public.games
  for each row
  when (new.event_changed_at is distinct from old.event_changed_at)
  execute function public.kan950_games_listing_nudge();

alter publication supabase_realtime add table public.game_listing_nudges;
