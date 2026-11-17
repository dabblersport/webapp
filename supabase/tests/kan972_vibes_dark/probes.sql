-- KAN-972 (vibe dark colours) live probe pack. Run as postgres on wtncuzcskpigqpmnxwws after
-- 20261116182841_kan972_vibes_dark_colors.sql. Read-only except N1/N2, which write inside BEGIN ... ROLLBACK.
-- Run the helper block first in the same session (pg_temp, nothing persists).
-- Expected: P1..P6 all true. N1: a wrong-hue dark_bg_hex in one row makes the P4 predicate false, then rolls back.
-- N2: '#12345' is rejected by vibes_dark_bg_hex_chk (SQLSTATE 23514).
--
-- Run 2026-11-16 by backend-2 after apply: P1 true/true; P2 119 rows, hex valid; P3 bg darker, fixed L, max C
-- 0.046/0.061; P4 114 chromatic rows, max hue shift 1.98 deg; P5 5 greys -> #333333/#4D4D4D; P6 readable, not writable.
-- N1 (calm dark_bg set to #472A3F inside a rolled-back block) -> hue predicate f; N2 -> 23514 vibes_dark_bg_hex_chk;
-- calm after = #1B3647.

-- helpers (same OKLab conversion as the migration) --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.kan972_s2l(c float8) RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN c <= 0.04045 THEN c / 12.92 ELSE power((c + 0.055) / 1.055, 2.4) END $$;
CREATE OR REPLACE FUNCTION pg_temp.kan972_l2s(x float8) RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN x <= 0.0031308 THEN 12.92 * x ELSE 1.055 * power(x, 1 / 2.4) - 0.055 END $$;
CREATE OR REPLACE FUNCTION pg_temp.kan972_hex2oklch(h text, OUT l float8, OUT c float8, OUT hue float8) LANGUAGE sql IMMUTABLE AS $$
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
CREATE OR REPLACE FUNCTION pg_temp.kan972_oklch2hex(ok_l float8, ok_c float8, hue float8) RETURNS text LANGUAGE sql IMMUTABLE AS $$
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

-- P1 schema: both columns exist, nullable text, with their #RRGGBB checks.
SELECT count(*) FILTER (WHERE column_name IN ('dark_bg_hex', 'dark_border_hex') AND data_type = 'text' AND is_nullable = 'YES') = 2 AS p1_columns,
       (SELECT count(*) FROM pg_constraint WHERE conrelid = 'public.vibes'::regclass
         AND conname IN ('vibes_dark_bg_hex_chk', 'vibes_dark_border_hex_chk')) = 2                         AS p1_checks
  FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vibes';

-- P2 filled: 119 rows, every dark hex non-null and valid.
SELECT count(*) AS p2_rows, count(*) = 119 AS p2_row_count,
       bool_and(dark_bg_hex ~ '^#[0-9A-F]{6}$' AND dark_border_hex ~ '^#[0-9A-F]{6}$') AS p2_hex_valid
  FROM public.vibes;

-- P3 fixed L and bg darker than border.
SELECT bool_and(d.l < b.l) AS p3_bg_darker,
       bool_and(abs(d.l - 0.32) < 0.005 AND abs(b.l - 0.42) < 0.005) AS p3_fixed_l,
       round(max(d.c)::numeric, 3) AS p3_max_bg_c, round(max(b.c)::numeric, 3) AS p3_max_border_c
  FROM public.vibes v, LATERAL pg_temp.kan972_hex2oklch(v.dark_bg_hex) d, LATERAL pg_temp.kan972_hex2oklch(v.dark_border_hex) b;

-- P4 hue kept: chromatic rows keep the color_hex hue within 3 degrees in both dark columns.
SELECT count(*) AS p4_chromatic_rows,
       bool_and(least(abs(o.hue - d.hue), 360 - abs(o.hue - d.hue)) <= 3
            AND least(abs(o.hue - b.hue), 360 - abs(o.hue - b.hue)) <= 3) AS p4_hue_within_3deg,
       round(max(greatest(least(abs(o.hue - d.hue), 360 - abs(o.hue - d.hue)),
                          least(abs(o.hue - b.hue), 360 - abs(o.hue - b.hue))))::numeric, 2) AS p4_max_shift
  FROM public.vibes v, LATERAL pg_temp.kan972_hex2oklch(v.color_hex) o,
       LATERAL pg_temp.kan972_hex2oklch(v.dark_bg_hex) d, LATERAL pg_temp.kan972_hex2oklch(v.dark_border_hex) b
 WHERE o.c >= 0.02;

-- P5 near-greys neutral: grey light rows get #333333 / #4D4D4D.
SELECT count(*) AS p5_grey_rows, bool_and(v.dark_bg_hex = '#333333' AND v.dark_border_hex = '#4D4D4D') AS p5_greys_neutral
  FROM public.vibes v, LATERAL pg_temp.kan972_hex2oklch(v.color_hex) o WHERE o.c < 0.02;

-- P6 client access: anon/authenticated can SELECT the new columns and cannot UPDATE them.
SELECT has_column_privilege('authenticated', 'public.vibes', 'dark_bg_hex', 'SELECT')
   AND has_column_privilege('anon', 'public.vibes', 'dark_border_hex', 'SELECT')        AS p6_readable,
       NOT has_column_privilege('authenticated', 'public.vibes', 'dark_bg_hex', 'UPDATE')
   AND NOT has_column_privilege('anon', 'public.vibes', 'dark_bg_hex', 'UPDATE')         AS p6_not_writable;

-- N1 negative control: give `calm` (blue, hue ~240) a red-purple dark_bg_hex; the P4 predicate must go false.
BEGIN;
UPDATE public.vibes SET dark_bg_hex = '#472A3F' WHERE key = 'calm';
SELECT bool_and(least(abs(o.hue - d.hue), 360 - abs(o.hue - d.hue)) <= 3) AS n1_hue_within_3deg_expect_false
  FROM public.vibes v, LATERAL pg_temp.kan972_hex2oklch(v.color_hex) o, LATERAL pg_temp.kan972_hex2oklch(v.dark_bg_hex) d
 WHERE o.c >= 0.02;
ROLLBACK;

-- N2 negative control: an invalid hex is rejected by the check constraint (expect ERROR 23514).
BEGIN;
UPDATE public.vibes SET dark_bg_hex = '#12345' WHERE key = 'calm';
ROLLBACK;

-- after N1/N2: calm still has its migrated value.
SELECT dark_bg_hex = '#1B3647' AS calm_restored FROM public.vibes WHERE key = 'calm';
