-- ROLLBACK ARTIFACT for KAN-963 (vibe pastels). NOT a migration - do not apply in sequence.
--
-- Undoes 20261116092057_kan963_vibes_pastel_colors.sql: puts every public.vibes.color_hex back to the value held in
-- public._kan963_vibes_color_backup (key -> old hex, 119 rows at the backup). Touches no other column. A vibe created
-- after the migration has no backup row and keeps its colour. The backup table is kept; drop it by hand once the
-- rollback is confirmed and nobody needs the pastel set back.
--
-- Run as postgres on wtncuzcskpigqpmnxwws in one transaction. It refuses to run if the backup table is missing.

BEGIN;

DO $chk$
BEGIN
  IF to_regclass('public._kan963_vibes_color_backup') IS NULL THEN
    RAISE EXCEPTION 'KAN-963 rollback: public._kan963_vibes_color_backup is missing';
  END IF;
END
$chk$;

UPDATE public.vibes v
   SET color_hex = b.color_hex
  FROM public._kan963_vibes_color_backup b
 WHERE b.vibe_id = v.id
   AND v.color_hex IS DISTINCT FROM b.color_hex;

DO $post$
DECLARE n_diff int;
BEGIN
  SELECT count(*) INTO n_diff
    FROM public.vibes v JOIN public._kan963_vibes_color_backup b ON b.vibe_id = v.id
   WHERE v.color_hex IS DISTINCT FROM b.color_hex;
  IF n_diff <> 0 THEN
    RAISE EXCEPTION 'KAN-963 rollback: % rows still differ from the backup', n_diff;
  END IF;
END
$post$;

COMMIT;
