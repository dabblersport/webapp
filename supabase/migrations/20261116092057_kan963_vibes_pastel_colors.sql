-- KAN-963 follow-up (CEO 2026-11-16): vibe chip colours are pastels only.
--
-- What it does, in order (one transaction):
--   1. pre:    public._kan963_vibes_color_backup must not exist yet (the migration runs once).
--   2. backup: public._kan963_vibes_color_backup (vibe_id, key, color_hex, other_cols_md5) for EVERY row of public.vibes.
--              other_cols_md5 = md5 of the row as jsonb without color_hex, so step 5 can prove nothing else changed.
--              RLS on, no policy, nothing granted (T-020: a backup is read only by postgres).
--   3. colour: every vibe's color_hex becomes a pastel computed in OKLCH:
--                L = 0.88, C = 0.05, hue = the vibe's current OKLCH hue.
--              A near-grey (current chroma < 0.02, which includes `neutral` #000000 with C = 0) becomes the neutral grey
--              at the same L: oklch(0.88 0 0) = #D7D7D7.
--   4. gamut:  L = 0.88 / C = 0.05 is the one point of the briefed band (L 0.88-0.92, C 0.05-0.07) where all 360 hues are
--              inside sRGB (measured live 2026-11-16: 0 of 360 out of gamut; C 0.06 at L 0.88 already loses hues 254-281,
--              and every L >= 0.90 loses blue at C 0.05). So no clipping happens; the clamp in oklch2hex is a safety net.
--   5. post:   row count unchanged; every hex matches ^#[0-9A-F]{6}$; every row re-measured at L >= 0.86 and C <= 0.08;
--              chromatic rows keep their hue within 3 degrees; other_cols_md5 unchanged for every row.
--
-- Conversion (Bjorn Ottosson's OKLab, the CSS Color 4 matrices): sRGB hex -> linear sRGB -> LMS -> cube root -> OKLab ->
-- OKLCH, and the inverse. The helpers are pg_temp functions: they vanish with the session and leave nothing in the catalogue.
--
-- Rollback: supabase/schema/rollback/kan963_ROLLBACK_vibes_pastel_colors.sql (restores color_hex from the backup).
-- Live test: supabase/tests/kan963_vibes_pastel/probes.sql.

-- helpers ------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.kan963_s2l(c float8) RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN c <= 0.04045 THEN c / 12.92 ELSE power((c + 0.055) / 1.055, 2.4) END $$;

CREATE FUNCTION pg_temp.kan963_l2s(x float8) RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN x <= 0.0031308 THEN 12.92 * x ELSE 1.055 * power(x, 1 / 2.4) - 0.055 END $$;

CREATE FUNCTION pg_temp.kan963_hex2oklch(h text, OUT l float8, OUT c float8, OUT hue float8) LANGUAGE sql IMMUTABLE AS $$
  SELECT ok_l, sqrt(ok_a * ok_a + ok_b * ok_b), mod((degrees(atan2(ok_b, ok_a)) + 360)::numeric, 360)::float8
    FROM (SELECT 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_ AS ok_l,
                 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_ AS ok_a,
                 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_ AS ok_b
            FROM (SELECT cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) AS l_,
                         cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) AS m_,
                         cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) AS s_
                    FROM (SELECT pg_temp.kan963_s2l(('x' || substr(h, 2, 2))::bit(8)::int / 255.0) AS r,
                                 pg_temp.kan963_s2l(('x' || substr(h, 4, 2))::bit(8)::int / 255.0) AS g,
                                 pg_temp.kan963_s2l(('x' || substr(h, 6, 2))::bit(8)::int / 255.0) AS b) rgb) lms) lab $$;

CREATE FUNCTION pg_temp.kan963_oklch2hex(ok_l float8, ok_c float8, hue float8) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT '#' || upper(
           lpad(to_hex(round(255 * greatest(0, least(1, pg_temp.kan963_l2s(greatest(0, least(1, r))))))::int), 2, '0') ||
           lpad(to_hex(round(255 * greatest(0, least(1, pg_temp.kan963_l2s(greatest(0, least(1, g))))))::int), 2, '0') ||
           lpad(to_hex(round(255 * greatest(0, least(1, pg_temp.kan963_l2s(greatest(0, least(1, b))))))::int), 2, '0'))
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
  IF to_regclass('public._kan963_vibes_color_backup') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-963 pre: public._kan963_vibes_color_backup already exists';
  END IF;
END
$pre$;

-- 2. backup ----------------------------------------------------------------------------------------------------------
CREATE TABLE public._kan963_vibes_color_backup AS
SELECT v.id AS vibe_id, v.key, v.color_hex, md5((to_jsonb(v) - 'color_hex')::text) AS other_cols_md5, now() AS backed_up_at
  FROM public.vibes v;
ALTER TABLE public._kan963_vibes_color_backup ADD PRIMARY KEY (vibe_id);
ALTER TABLE public._kan963_vibes_color_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public._kan963_vibes_color_backup FROM PUBLIC, anon, authenticated, service_role;
COMMENT ON TABLE public._kan963_vibes_color_backup IS
  'KAN-963 2026-11-16: public.vibes.color_hex before the pastel migration (key -> old hex). Read by '
  'supabase/schema/rollback/kan963_ROLLBACK_vibes_pastel_colors.sql. RLS on, no policy, no grants.';

-- 3. colour ----------------------------------------------------------------------------------------------------------
UPDATE public.vibes v
   SET color_hex = CASE WHEN o.c < 0.02 THEN pg_temp.kan963_oklch2hex(0.88, 0, 0)
                        ELSE pg_temp.kan963_oklch2hex(0.88, 0.05, o.hue) END
  FROM public._kan963_vibes_color_backup b, LATERAL pg_temp.kan963_hex2oklch(b.color_hex) o
 WHERE b.vibe_id = v.id;

-- 5. post ------------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  n_vibes int; n_backup int; n_bad_hex int; n_not_pastel int; n_hue_moved int; n_other_changed int; n_unbacked int;
BEGIN
  SELECT count(*) INTO n_vibes FROM public.vibes;
  SELECT count(*) INTO n_backup FROM public._kan963_vibes_color_backup;
  SELECT count(*) INTO n_unbacked FROM public.vibes v
   WHERE NOT EXISTS (SELECT 1 FROM public._kan963_vibes_color_backup b WHERE b.vibe_id = v.id);
  SELECT count(*) INTO n_bad_hex FROM public.vibes WHERE color_hex IS NULL OR color_hex !~ '^#[0-9A-F]{6}$';
  SELECT count(*) INTO n_not_pastel FROM public.vibes v, LATERAL pg_temp.kan963_hex2oklch(v.color_hex) n
   WHERE n.l < 0.86 OR n.c > 0.08;
  SELECT count(*) INTO n_hue_moved
    FROM public.vibes v JOIN public._kan963_vibes_color_backup b ON b.vibe_id = v.id,
         LATERAL pg_temp.kan963_hex2oklch(b.color_hex) o, LATERAL pg_temp.kan963_hex2oklch(v.color_hex) n
   WHERE o.c >= 0.02 AND least(abs(o.hue - n.hue), 360 - abs(o.hue - n.hue)) > 3;
  SELECT count(*) INTO n_other_changed
    FROM public.vibes v JOIN public._kan963_vibes_color_backup b ON b.vibe_id = v.id
   WHERE md5((to_jsonb(v) - 'color_hex')::text) <> b.other_cols_md5;

  IF n_vibes <> n_backup OR n_unbacked <> 0 OR n_bad_hex <> 0 OR n_not_pastel <> 0 OR n_hue_moved <> 0
     OR n_other_changed <> 0 THEN
    RAISE EXCEPTION 'KAN-963 post failed: vibes=% backup=% unbacked=% bad_hex=% not_pastel=% hue_moved=% other_changed=%',
      n_vibes, n_backup, n_unbacked, n_bad_hex, n_not_pastel, n_hue_moved, n_other_changed;
  END IF;
END
$post$;

DROP FUNCTION pg_temp.kan963_oklch2hex(float8, float8, float8);
DROP FUNCTION pg_temp.kan963_hex2oklch(text);
DROP FUNCTION pg_temp.kan963_l2s(float8);
DROP FUNCTION pg_temp.kan963_s2l(float8);
