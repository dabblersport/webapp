-- Without these, RLS denies SELECT on game_roster/game_waitlist for every
-- authenticated client. The roster screen reads zero rows back, isOnRoster
-- stays false, the CTA never flips to "Leave game", and tapping the still-
-- visible Join button raises P0001 {message:"joined", detail:"already"} from
-- rpc_join_game's assessor.

DROP POLICY IF EXISTS roster_select_public_or_self ON public.game_roster;
CREATE POLICY roster_select_public_or_self
  ON public.game_roster
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.games g
      WHERE g.id = game_roster.game_id
        AND g.listing_visibility = 'public'
    )
  );

DROP POLICY IF EXISTS waitlist_select_public_or_self ON public.game_waitlist;
CREATE POLICY waitlist_select_public_or_self
  ON public.game_waitlist
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.games g
      WHERE g.id = game_waitlist.game_id
        AND g.listing_visibility = 'public'
    )
  );
