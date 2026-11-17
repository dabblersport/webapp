-- KAN-972 ROLLBACK: undo 20261116182841_kan972_vibes_dark_colors.sql.
-- The migration only added public.vibes.dark_bg_hex / dark_border_hex (with their checks) and filled them; no other
-- column was touched (asserted in-migration by md5 fingerprint), so dropping the two columns restores the prior state.
-- Run as postgres on wtncuzcskpigqpmnxwws only. Roll the client back first (Vibe.fromMap must tolerate absence).
BEGIN;
ALTER TABLE public.vibes
  DROP CONSTRAINT IF EXISTS vibes_dark_bg_hex_chk,
  DROP CONSTRAINT IF EXISTS vibes_dark_border_hex_chk,
  DROP COLUMN IF EXISTS dark_bg_hex,
  DROP COLUMN IF EXISTS dark_border_hex;
DO $chk$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vibes'
                AND column_name IN ('dark_bg_hex', 'dark_border_hex')) THEN
    RAISE EXCEPTION 'KAN-972 rollback: dark colour column still present';
  END IF;
END
$chk$;
COMMIT;
