-- KAN-972 (CEO 2026-11-16): dark-mode colours for vibe chips.
--
-- Adds two nullable columns to public.vibes and fills them for every row:
--   dark_bg_hex     the chip ground in dark mode   = oklch(0.32 0.045 hue)
--   dark_border_hex the chip border in dark mode   = oklch(0.42 0.060 hue)
-- hue = the OKLCH hue of the row's current color_hex (the KAN-963 pastel, migration 20261116092057), so the dark pair is
-- the same hue family as the light chip. A near-grey (current chroma < 0.02; today the 5 rows KAN-963 set to #D7D7D7,
-- incl. `neutral`) gets the neutral grey at the same L: oklch(0.32 0 0) and oklch(0.42 0 0).
--
-- Why these numbers (design system 752cbad, lib/src/tokens/dabbler_dark_provisional.dart):
--   dark bgPrimary #141414 (OKLCH L ~0.20), surfaceCard = bgSecondary #1C1C1C (L ~0.23), bgTertiary #262626 (L ~0.28).
--   L 0.32 sits one clear step above the card so the chip reads as a tinted surface, not a hole; the border at L 0.42
--   is one step lighter again. Text ink in dark is textPrimary #F5F0E6 (L ~0.96), well above AA on L 0.32.
-- Gamut (measured live 2026-11-16 over hues 0..359): L 0.32 is in sRGB for every hue up to C 0.05 (C 0.055 loses 16);
--   L 0.42 is in sRGB for every hue up to C 0.07. So C 0.045 / 0.06 never clips; the clamp in oklch2hex is a safety net.
--
-- Steps (one transaction): 1 pre (columns absent, 119 rows) -> 2 fingerprint every row -> 3 add columns + checks
-- -> 4 fill -> 5 post asserts -> drop pg_temp helpers.
-- Post asserts: row count unchanged; every new hex non-null and ^#[0-9A-F]{6}$; per row dark_bg L < dark_border L;
--   chromatic rows: both dark hexes keep the color_hex hue within 3 deg; near-grey rows: both dark hexes C < 0.005;
--   every other column of every row byte-identical (md5 of the row jsonb without the two new keys).
-- Conversion: Bjorn Ottosson's OKLab (CSS Color 4 matrices), same helpers as KAN-963; pg_temp, nothing persists.
-- Grants: vibes has table-level SELECT for anon/authenticated (no column grants), so the new columns are readable by
--   the same rows the policy vibes_select_all already exposes. Nothing new is writable by a client.
-- Rollback: supabase/schema/rollback/kan972_ROLLBACK_vibes_dark_colors.sql (drops the two columns; nothing else moved).
-- Live test: supabase/tests/kan972_vibes_dark/probes.sql.

-- helpers ------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.kan972_s2l(c float8) RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN c <= 0.04045 THEN c / 12.92 ELSE power((c + 0.055) / 1.055, 2.4) END $$;

CREATE FUNCTION pg_temp.kan972_l2s(x float8) RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN x <= 0.0031308 THEN 12.92 * x ELSE 1.055 * power(x, 1 / 2.4) - 0.055 END $$;

CREATE FUNCTION pg_temp.kan972_hex2oklch(h text, OUT l float8, OUT c float8, OUT hue float8) LANGUAGE sql IMMUTABLE AS $$
  SELECT ok_l, sqrt(ok_a * ok_a + ok_b * ok_b), mod((degrees(atan2(ok_b, ok_a)) + 360)::numeric, 360)::float8
    FROM (SELECT 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_ AS ok_l,
                 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_ AS ok_a,
                 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_ AS ok_b
            FROM (SELECT cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) AS l_,
                         cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) AS m_,
                         cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) AS s_
                    FROM (SELECT pg_temp.kan972_s2l(('x' || substr(h, 2, 2))::bit(8)::int / 255.0) AS r,
                                 pg_temp.kan972_s2l(('x' || substr(h, 4, 2))::bit(8)::int / 255.0) AS g,
                                 pg_temp.kan972_s2l(('x' || substr(h, 6, 2))::bit(8)::int / 255.0) AS b) rgb) lms) lab $$;

CREATE FUNCTION pg_temp.kan972_oklch2hex(ok_l float8, ok_c float8, hue float8) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT '#' || upper(
           lpad(to_hex(round(255 * greatest(0, least(1, pg_temp.kan972_l2s(greatest(0, least(1, r))))))::int), 2, '0') ||
           lpad(to_hex(round(255 * greatest(0, least(1, pg_temp.kan972_l2s(greatest(0, least(1, g))))))::int), 2, '0') ||
           lpad(to_hex(round(255 * greatest(0, least(1, pg_temp.kan972_l2s(greatest(0, least(1, b))))))::int), 2, '0'))
    FROM (SELECT  4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_ AS r,
                 -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_ AS g,
                 -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_ AS b
            FROM (SELECT power(ok_l + 0.3963377774 * a + 0.2158037573 * bb, 3) AS l_,
                         power(ok_l - 0.1055613458 * a - 0.0638541728 * bb, 3) AS m_,
                         power(ok_l - 0.0894841775 * a - 1.2914855480 * bb, 3) AS s_
                    FROM (SELECT ok_c * cos(radians(hue)) AS a, ok_c * sin(radians(hue)) AS bb) ab) lms) rgb $$;

-- 1. pre -------------------------------------------------------------------------------------------------------------
DO $pre$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vibes'
                AND column_name IN ('dark_bg_hex', 'dark_border_hex')) THEN
    RAISE EXCEPTION 'KAN-972 pre: public.vibes already has a dark colour column';
  END IF;
END
$pre$;

-- 2. fingerprint -----------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan972_before ON COMMIT DROP AS
SELECT v.id, md5(to_jsonb(v)::text) AS row_md5 FROM public.vibes v;

-- 3. columns ---------------------------------------------------------------------------------------------------------
ALTER TABLE public.vibes
  ADD COLUMN dark_bg_hex text,
  ADD COLUMN dark_border_hex text,
  ADD CONSTRAINT vibes_dark_bg_hex_chk     CHECK (dark_bg_hex     ~* '^#[0-9A-F]{6}$'),
  ADD CONSTRAINT vibes_dark_border_hex_chk CHECK (dark_border_hex ~* '^#[0-9A-F]{6}$');

COMMENT ON COLUMN public.vibes.dark_bg_hex IS
  'KAN-972: vibe chip ground in dark mode, oklch(0.32 0.045 <hue of color_hex>); near-greys oklch(0.32 0 0). '
  'Null = client derives it from the hue.';
COMMENT ON COLUMN public.vibes.dark_border_hex IS
  'KAN-972: vibe chip border in dark mode, oklch(0.42 0.06 <hue of color_hex>); near-greys oklch(0.42 0 0). '
  'Null = client derives it from the hue.';

-- 4. fill ------------------------------------------------------------------------------------------------------------
UPDATE public.vibes v
   SET dark_bg_hex     = CASE WHEN o.c < 0.02 THEN pg_temp.kan972_oklch2hex(0.32, 0, 0)
                              ELSE pg_temp.kan972_oklch2hex(0.32, 0.045, o.hue) END,
       dark_border_hex = CASE WHEN o.c < 0.02 THEN pg_temp.kan972_oklch2hex(0.42, 0, 0)
                              ELSE pg_temp.kan972_oklch2hex(0.42, 0.06, o.hue) END
  FROM (SELECT s.id, h.c, h.hue FROM public.vibes s, LATERAL pg_temp.kan972_hex2oklch(s.color_hex) h) o
 WHERE o.id = v.id;

-- 5. post ------------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  n_vibes int; n_before int; n_bad_hex int; n_not_darker int; n_hue_moved int; n_grey_tinted int; n_other_changed int;
BEGIN
  SELECT count(*) INTO n_vibes FROM public.vibes;
  SELECT count(*) INTO n_before FROM kan972_before;
  SELECT count(*) INTO n_bad_hex FROM public.vibes
   WHERE dark_bg_hex IS NULL OR dark_bg_hex !~ '^#[0-9A-F]{6}$'
      OR dark_border_hex IS NULL OR dark_border_hex !~ '^#[0-9A-F]{6}$';
  SELECT count(*) INTO n_not_darker
    FROM public.vibes v, LATERAL pg_temp.kan972_hex2oklch(v.dark_bg_hex) d, LATERAL pg_temp.kan972_hex2oklch(v.dark_border_hex) b
   WHERE NOT (d.l < b.l);
  SELECT count(*) INTO n_hue_moved
    FROM public.vibes v, LATERAL pg_temp.kan972_hex2oklch(v.color_hex) o,
         LATERAL pg_temp.kan972_hex2oklch(v.dark_bg_hex) d, LATERAL pg_temp.kan972_hex2oklch(v.dark_border_hex) b
   WHERE o.c >= 0.02
     AND (least(abs(o.hue - d.hue), 360 - abs(o.hue - d.hue)) > 3 OR least(abs(o.hue - b.hue), 360 - abs(o.hue - b.hue)) > 3);
  SELECT count(*) INTO n_grey_tinted
    FROM public.vibes v, LATERAL pg_temp.kan972_hex2oklch(v.color_hex) o,
         LATERAL pg_temp.kan972_hex2oklch(v.dark_bg_hex) d, LATERAL pg_temp.kan972_hex2oklch(v.dark_border_hex) b
   WHERE o.c < 0.02 AND (d.c >= 0.005 OR b.c >= 0.005);
  SELECT count(*) INTO n_other_changed
    FROM public.vibes v FULL JOIN kan972_before f ON f.id = v.id
   WHERE f.id IS NULL OR v.id IS NULL
      OR md5((to_jsonb(v) - 'dark_bg_hex' - 'dark_border_hex')::text) <> f.row_md5;

  IF n_vibes <> n_before OR n_bad_hex <> 0 OR n_not_darker <> 0 OR n_hue_moved <> 0 OR n_grey_tinted <> 0
     OR n_other_changed <> 0 THEN
    RAISE EXCEPTION 'KAN-972 post failed: vibes=% before=% bad_hex=% not_darker=% hue_moved=% grey_tinted=% other_changed=%',
      n_vibes, n_before, n_bad_hex, n_not_darker, n_hue_moved, n_grey_tinted, n_other_changed;
  END IF;
END
$post$;

DROP FUNCTION pg_temp.kan972_oklch2hex(float8, float8, float8);
DROP FUNCTION pg_temp.kan972_hex2oklch(text);
DROP FUNCTION pg_temp.kan972_l2s(float8);
DROP FUNCTION pg_temp.kan972_s2l(float8);
