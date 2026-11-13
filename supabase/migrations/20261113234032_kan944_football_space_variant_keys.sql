-- KAN-944 item 3: Football venue_spaces whose sport_variant_keys name a key that is not a Football variant.
-- Only the unambiguous fix is applied: 'football_11s' -> 'football_standard' (Football "Standard", 11 per side,
-- surface football_11s_grass; both rows are 11s grass, capacity 22 = football_standard.required_players, so
-- trg_set_venue_space_capacity leaves capacity at 22).
-- Old values (reverse: set sport_variant_keys back to these, guarded on '{football_standard}'):
--   8a4dc7ed-a2e1-4b1b-8bb6-1823eea17624  Al Forsan International Sports Resort / Football Field 1  {football_11s}
--   4ba70538-c436-46a0-a133-beebad264018  Al Forsan International Sports Resort / Football Field 2  {football_11s}
-- Ambiguous rows (football_touch, empty array, NULL) are left untouched for a product decision (see KAN-944).
-- Applied live 2026-11-14 (recorded version 20261113234032).

DO $mig$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.venue_spaces
   WHERE id IN ('8a4dc7ed-a2e1-4b1b-8bb6-1823eea17624', '4ba70538-c436-46a0-a133-beebad264018')
     AND sport_variant_keys = ARRAY['football_11s']::text[];
  IF n <> 2 THEN
    RAISE EXCEPTION 'KAN-944: venue_spaces pre-guard failed: % of 2 rows still carry {football_11s}', n;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sport_variants v JOIN public.sports s ON s.id = v.sport_id
                  WHERE v.variant_key = 'football_standard' AND s.sport_key = 'football' AND v.is_active) THEN
    RAISE EXCEPTION 'KAN-944: football_standard is not an active Football variant';
  END IF;

  UPDATE public.venue_spaces
     SET sport_variant_keys = ARRAY['football_standard']::text[]
   WHERE id IN ('8a4dc7ed-a2e1-4b1b-8bb6-1823eea17624', '4ba70538-c436-46a0-a133-beebad264018')
     AND sport_variant_keys = ARRAY['football_11s']::text[];
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 2 THEN
    RAISE EXCEPTION 'KAN-944: expected 2 rows updated, got %', n;
  END IF;

  IF EXISTS (SELECT 1 FROM public.venue_spaces WHERE 'football_11s' = ANY (sport_variant_keys))
     OR (SELECT count(*) FROM public.venue_spaces
          WHERE id IN ('8a4dc7ed-a2e1-4b1b-8bb6-1823eea17624', '4ba70538-c436-46a0-a133-beebad264018')
            AND sport_variant_keys = ARRAY['football_standard']::text[] AND capacity = 22) <> 2 THEN
    RAISE EXCEPTION 'KAN-944: venue_spaces post-assert failed';
  END IF;
END $mig$;
