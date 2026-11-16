-- KAN-963 (vibe pastels) live probe pack. Run as postgres on wtncuzcskpigqpmnxwws after
-- 20261116092057_kan963_vibes_pastel_colors.sql. Read-only except N2, which writes inside BEGIN ... ROLLBACK.
-- Each block prints booleans/counts. Run the helper block first in the same session (pg_temp, nothing persists).
--
-- Run 2026-11-16 by backend-2 after apply: P1..P5 true (119 rows, min L 0.879, max C 0.051, 114 chromatic rows, max
-- hue shift 1.48 deg, 5 near-greys -> #D7D7D7), N1 115 of 119 old rows not pastel, N2 = f, angry back to #F7CBC9.
-- Expected: P1..P5 all true; N1 shows the pre-migration colours FAIL the same pastel predicate (bold rows > 0);
-- N2 shows a bold hex written into one row makes P2 false, then rolls back.

-- helpers (same OKLab conversion as the migration) --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.kan963_s2l(c float8) RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN c <= 0.04045 THEN c / 12.92 ELSE power((c + 0.055) / 1.055, 2.4) END $$;
CREATE OR REPLACE FUNCTION pg_temp.kan963_hex2oklch(h text, OUT l float8, OUT c float8, OUT hue float8) LANGUAGE sql IMMUTABLE AS $$
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

-- P1 backup: exists, one row per vibe, every old hex valid, closed (RLS on, no policy, no client grant).
SELECT (SELECT count(*) FROM public._kan963_vibes_color_backup) = (SELECT count(*) FROM public.vibes)          AS p1_backup_count_matches,
       NOT EXISTS (SELECT 1 FROM public.vibes v LEFT JOIN public._kan963_vibes_color_backup b ON b.vibe_id = v.id
                    WHERE b.vibe_id IS NULL)                                                                     AS p1_every_vibe_backed_up,
       NOT EXISTS (SELECT 1 FROM public._kan963_vibes_color_backup WHERE color_hex !~* '^#[0-9A-F]{6}$')         AS p1_backup_hex_valid,
       (SELECT relrowsecurity FROM pg_class WHERE oid = 'public._kan963_vibes_color_backup'::regclass)          AS p1_backup_rls_on,
       NOT has_table_privilege('anon', 'public._kan963_vibes_color_backup', 'SELECT')
         AND NOT has_table_privilege('authenticated', 'public._kan963_vibes_color_backup', 'SELECT')            AS p1_backup_closed,
       (SELECT color_hex FROM public._kan963_vibes_color_backup WHERE key = 'neutral') = '#000000'              AS p1_neutral_old_black;

-- P2 pastel bounds: every live vibe hex valid, L >= 0.86, C <= 0.08.
SELECT count(*)                                                       AS p2_rows,
       bool_and(v.color_hex ~ '^#[0-9A-F]{6}$')                       AS p2_hex_valid,
       bool_and(o.l >= 0.86 AND o.c <= 0.08)                          AS p2_all_pastel,
       round(min(o.l)::numeric, 3) AS p2_min_l, round(max(o.c)::numeric, 3) AS p2_max_c
  FROM public.vibes v, LATERAL pg_temp.kan963_hex2oklch(v.color_hex) o;

-- P3 hue kept: rows that were chromatic (old C >= 0.02) keep their hue within 3 degrees.
SELECT count(*)                                                                         AS p3_chromatic_rows,
       bool_and(least(abs(o.hue - n.hue), 360 - abs(o.hue - n.hue)) <= 3)                AS p3_hue_within_3deg,
       round(max(least(abs(o.hue - n.hue), 360 - abs(o.hue - n.hue)))::numeric, 2)       AS p3_max_hue_shift
  FROM public.vibes v JOIN public._kan963_vibes_color_backup b ON b.vibe_id = v.id,
       LATERAL pg_temp.kan963_hex2oklch(b.color_hex) o, LATERAL pg_temp.kan963_hex2oklch(v.color_hex) n
 WHERE o.c >= 0.02;

-- P4 near-greys neutral: rows that were C < 0.02 (incl. neutral) are now a grey (C < 0.005) at L >= 0.86.
SELECT count(*) AS p4_grey_rows, bool_and(n.c < 0.005 AND n.l >= 0.86) AS p4_greys_neutral_light,
       (SELECT color_hex FROM public.vibes WHERE key = 'neutral') AS p4_neutral_now
  FROM public.vibes v JOIN public._kan963_vibes_color_backup b ON b.vibe_id = v.id,
       LATERAL pg_temp.kan963_hex2oklch(b.color_hex) o, LATERAL pg_temp.kan963_hex2oklch(v.color_hex) n
 WHERE o.c < 0.02;

-- P5 only color_hex changed: every other column of every row matches its pre-migration fingerprint.
SELECT bool_and(md5((to_jsonb(v) - 'color_hex')::text) = b.other_cols_md5) AS p5_other_columns_untouched,
       count(*) FILTER (WHERE v.is_active) AS p5_active_rows
  FROM public.vibes v JOIN public._kan963_vibes_color_backup b ON b.vibe_id = v.id;

-- N1 negative control (read-only): the SAME pastel predicate on the pre-migration colours must fail.
SELECT count(*) FILTER (WHERE NOT (o.l >= 0.86 AND o.c <= 0.08)) AS n1_old_rows_not_pastel,
       bool_and(o.l >= 0.86 AND o.c <= 0.08)                     AS n1_old_set_passes_expect_false
  FROM public._kan963_vibes_color_backup b, LATERAL pg_temp.kan963_hex2oklch(b.color_hex) o;

-- N2 negative control (write, rolled back): one bold row makes P2 false. The block always RAISEs, so the UPDATE is
-- rolled back whatever the runner does; the result is in the error text. Expect "n2_all_pastel_expect_false=f", then
-- check angry is still its pastel: SELECT color_hex FROM public.vibes WHERE key = 'angry';  -- #F7CBC9
DO $n2$
DECLARE ok boolean;
BEGIN
  UPDATE public.vibes SET color_hex = '#D7263D' WHERE key = 'angry';
  SELECT bool_and(o.l >= 0.86 AND o.c <= 0.08) INTO ok FROM public.vibes v, LATERAL pg_temp.kan963_hex2oklch(v.color_hex) o;
  RAISE EXCEPTION 'N2_RESULT n2_all_pastel_expect_false=% (exception forces rollback)', ok;
END $n2$;
