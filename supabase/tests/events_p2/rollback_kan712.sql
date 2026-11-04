-- KAN-712 ROLLBACK of the cutover (20261103110000). One transaction. Lossless: it changes no row.
--
-- STATUS: authored, NOT applied to any Supabase project. Exercised on a local throwaway PG 16 only.
--
-- What it restores: the phase-1 (KAN-711) write direction. legacy -> events mirrors back ON, the five
-- KAN-712 triggers gone, every wrapped RPC back to its original function under its original name, owner
-- and ACL. What it deliberately leaves: stage 1 (20261103100000) -- six kan712_* functions and the empty
-- kan712_wrapped_rpcs bookkeeping table. Stage 1 is inert without the cutover (its own post-condition
-- asserts no kan712 trigger exists), none of it is executable by anon/authenticated, and the brief
-- forbids DROP TABLE. Re-running the cutover after this rollback needs only 20261103110000 again.
--
-- Data: rows written while KAN-712 was live are already identical in events and legacy (the compat
-- mirror keeps them equal; parity is asserted below), so nothing needs copying back. The three tables
-- are hashed before and after under SHARE ROW EXCLUSIVE locks and must be byte-identical.
-- Fails closed (whole transaction rolls back) if: the cutover is not applied, parity is not 0, any
-- hash differs, any ACL/owner differs from the recorded original, or the trigger shape is not phase 1.
\set ON_ERROR_STOP 1
BEGIN;
SET LOCAL lock_timeout = '10s';
LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMP TABLE kan712_rb_hash (stage text, tbl text, n bigint, h text) ON COMMIT DROP;
INSERT INTO kan712_rb_hash
  SELECT 'before', 'events',  count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) FROM public.events t
  UNION ALL
  SELECT 'before', 'games',   count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) FROM public.games t
  UNION ALL
  SELECT 'before', 'meetups', count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) FROM public.meetups t;
-- The records unwrap deletes; kept here so the restored ACL/owner can be asserted afterwards.
CREATE TEMP TABLE kan712_rb_wrapped ON COMMIT DROP AS SELECT * FROM public.kan712_wrapped_rpcs;

-- 1. Preconditions ---------------------------------------------------------------------------------
DO $$
DECLARE v_n bigint;
BEGIN
  IF (SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg\_zz\_kan712\_%') <> 5 THEN
    RAISE EXCEPTION 'KAN-712 rollback: the cutover is not applied (expected 5 trg_zz_kan712_* triggers)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs) THEN
    RAISE EXCEPTION 'KAN-712 rollback: no wrapped RPC recorded';
  END IF;
  SELECT count(*) INTO v_n FROM public.kan711_events_parity;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'KAN-712 rollback: kan711_events_parity has % rows; reconcile before rolling back', v_n;
  END IF;
END $$;

-- 2. Unwrap every RPC (inverse of kan712_wrap_rpc: drop wrapper, rename inner back, restore owner+ACL) --
DO $$
DECLARE w record;
BEGIN
  FOR w IN SELECT name, identity_args FROM public.kan712_wrapped_rpcs ORDER BY name, identity_args LOOP
    PERFORM public.kan712_unwrap_rpc(w.name, w.identity_args);
  END LOOP;
END $$;

-- 3. Detach KAN-712, restore the KAN-711 direction ----------------------------------------------------
DROP TRIGGER trg_zz_kan712_games_guard          ON public.games;
DROP TRIGGER trg_zz_kan712_meetups_guard        ON public.meetups;
DROP TRIGGER trg_zz_kan712_games_after_delete   ON public.games;
DROP TRIGGER trg_zz_kan712_meetups_after_delete ON public.meetups;
DROP TRIGGER trg_zz_kan712_events_compat_mirror ON public.events;
ALTER TABLE public.games   ENABLE TRIGGER trg_kan711_games_mirror;
ALTER TABLE public.meetups ENABLE TRIGGER trg_kan711_meetups_mirror;

-- 4. Post-conditions ---------------------------------------------------------------------------------
INSERT INTO kan712_rb_hash
  SELECT 'after', 'events',  count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) FROM public.events t
  UNION ALL
  SELECT 'after', 'games',   count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) FROM public.games t
  UNION ALL
  SELECT 'after', 'meetups', count(*), md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) FROM public.meetups t;

DO $$
DECLARE r record; v_n bigint;
BEGIN
  -- 4a. Lossless.
  FOR r IN SELECT b.tbl, b.n AS bn, b.h AS bh, a.n AS an, a.h AS ah
             FROM kan712_rb_hash b JOIN kan712_rb_hash a ON a.tbl = b.tbl AND a.stage = 'after' WHERE b.stage = 'before' LOOP
    IF r.bh <> r.ah OR r.bn <> r.an THEN
      RAISE EXCEPTION 'KAN-712 rollback: % changed (% rows % -> % rows %)', r.tbl, r.bn, r.bh, r.an, r.ah;
    END IF;
    RAISE NOTICE 'KAN-712 rollback hash % rows=% before=% after=%', r.tbl, r.bn, r.bh, r.ah;
  END LOOP;
  SELECT count(*) INTO v_n FROM public.kan711_events_parity;
  IF v_n <> 0 THEN RAISE EXCEPTION 'KAN-712 rollback: parity % rows after rollback', v_n; END IF;

  -- 4b. Every RPC is back: original name, no inner left, owner and ACL equal to the recorded original.
  IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs) THEN
    RAISE EXCEPTION 'KAN-712 rollback: kan712_wrapped_rpcs is not empty';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname LIKE '%\_kan712\_inner') THEN
    RAISE EXCEPTION 'KAN-712 rollback: a *_kan712_inner function remains';
  END IF;
  FOR r IN SELECT w.*, (SELECT x.oid FROM pg_proc x WHERE x.pronamespace = 'public'::regnamespace AND x.proname = w.name
                           AND pg_get_function_identity_arguments(x.oid) = w.identity_args) AS f
             FROM kan712_rb_wrapped w LOOP
    IF r.f IS NULL THEN RAISE EXCEPTION 'KAN-712 rollback: %(%) missing', r.name, r.identity_args; END IF;
    IF (SELECT proowner FROM pg_proc WHERE oid = r.f) <> r.original_owner THEN
      RAISE EXCEPTION 'KAN-712 rollback: owner of %(%) not restored', r.name, r.identity_args;
    END IF;
    IF EXISTS (
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM pg_proc p,
                 aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = r.f AND a.grantee <> p.proowner)
         EXCEPT
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM aclexplode(coalesce(r.original_acl, acldefault('f', r.original_owner))) a
           WHERE a.grantee <> r.original_owner))
       OR EXISTS (
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM aclexplode(coalesce(r.original_acl, acldefault('f', r.original_owner))) a
           WHERE a.grantee <> r.original_owner)
         EXCEPT
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM pg_proc p,
                 aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = r.f AND a.grantee <> p.proowner)) THEN
      RAISE EXCEPTION 'KAN-712 rollback: ACL of %(%) not restored', r.name, r.identity_args;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = r.f AND ('kan712.contract=on' = ANY  -- pre-KAN-850 wrapper shape (history)
                  (coalesce(proconfig, '{}'))
                 OR position('set_config(''kan712.contract'', ''on'', true)' IN prosrc) > 0)) THEN  -- KAN-850 wrapper shape
      RAISE EXCEPTION 'KAN-712 rollback: %(%) is still a wrapper', r.name, r.identity_args;
    END IF;
  END LOOP;

  -- 4c. Phase-1 trigger shape.
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE '%kan712%') THEN
    RAISE EXCEPTION 'KAN-712 rollback: a kan712 trigger remains';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_kan711_games_assign_event_id', 'trg_kan711_meetups_assign_event_id',
        'trg_kan711_events_keep_updated_at', 'trg_kan711_games_mirror', 'trg_kan711_meetups_mirror') AND tgenabled = 'O') <> 5 THEN
    RAISE EXCEPTION 'KAN-712 rollback: the five KAN-711 triggers are not all present and enabled';
  END IF;
  IF (SELECT array_agg(tgname::text ORDER BY tgname::text COLLATE "C") FROM pg_trigger
       WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal)
     IS DISTINCT FROM ARRAY['trg_events_exclusive_check', 'trg_events_search_tsv', 'trg_events_series_start_check',
                            'trg_events_touch', 'trg_events_type_immutable', 'trg_kan711_events_keep_updated_at'] THEN
    RAISE EXCEPTION 'KAN-712 rollback: events trigger set is not KAN-710 five + KAN-711 keeper';
  END IF;

  -- 4d. The stage-1 ops path that stays behind is closed (it refuses without the compat mirror).
  v_n := 0;
  BEGIN
    PERFORM public.kan712_update_event_shared((SELECT id FROM public.events LIMIT 1), '{}'::jsonb);
    v_n := 1;
  EXCEPTION WHEN SQLSTATE '55000' THEN v_n := 0;
  END;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'KAN-712 rollback: kan712_update_event_shared still writes after rollback';
  END IF;
END $$;

SELECT stage || '|' || tbl || '|rows=' || n || '|md5=' || h FROM kan712_rb_hash ORDER BY tbl, stage DESC;
COMMIT;
