-- Enable Supabase Realtime for game participation tables.
--
-- The game detail screen subscribes to postgres_changes on roster /
-- waitlist / join-requests to live-update the players list, but none of
-- these tables were in the supabase_realtime publication, so no events
-- were ever emitted. Realtime enforces the tables' SELECT RLS per
-- subscriber (WALRUS), so hosts/participants/followers receive exactly
-- the rows they can already read; strangers to a followers/private game
-- receive nothing.
--
-- games itself is intentionally NOT added: it has RLS with no SELECT
-- policies (reads go through owner views/RPCs), so no subscriber would
-- ever receive its events.

alter publication supabase_realtime add table public.game_roster;
alter publication supabase_realtime add table public.game_waitlist;
alter publication supabase_realtime add table public.game_join_requests;
