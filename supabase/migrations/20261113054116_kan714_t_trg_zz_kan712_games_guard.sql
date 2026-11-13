-- KAN-918 (Epic KAN-708, KAN-714 chain T; KAN-718 phase 2): drop trigger public.games.trg_zz_kan712_games_guard.
--
-- Live catalogue, 2026-11-13 (project wtncuzcskpigqpmnxwws):
--   * Every SQL writer of public.games writes its events parent itself (kan718_game_event_sync), so events is
--     authoritative and the guard's routing is no longer needed. pg_proc scan: the only functions that write
--     games without kan718_game_event_sync are kan711_events_backfill_batch (dead) and the compat mirror
--     (dropped by KAN-924).
--   * authenticated cannot write games rows (RLS on, no policy). After this drop a direct postgres /
--     service_role write to games is no longer copied to events: an INSERT without a parent fails at commit on
--     games_event_id_fkey (deferred); an UPDATE leaves events behind. Use the owning RPC.
--   * The function public.kan712_legacy_guard() is KEPT: public.meetups.trg_zz_kan712_meetups_guard uses it.
-- No CASCADE. The guard refuses on drift.
-- Test: supabase/tests/events_p4/kan714_t_trg_zz_kan712_games_guard_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.kan712_legacy_guard()');
begin
  if v_oid is null or md5(pg_get_functiondef(v_oid)) <> 'a0899aa5803480f52ab2993a3a6c2559' then
    raise exception 'KAN-918 pre: kan712_legacy_guard() absent or drifted';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.games'::regclass and tgname = 'trg_zz_kan712_games_guard'
                 and tgfoid = v_oid and tgenabled = 'O'
                 and pg_get_triggerdef(oid) = 'CREATE TRIGGER trg_zz_kan712_games_guard BEFORE INSERT OR UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION kan712_legacy_guard()') then
    raise exception 'KAN-918 pre: trg_zz_kan712_games_guard absent, disabled or drifted';
  end if;
  if exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace
              and prosrc ~* '(update\s+(public\.)?games\M|insert\s+into\s+(public\.)?games\M)'
              and prosrc !~ 'kan718_game_event_sync'
              and proname not in ('kan711_events_backfill_batch')) then
    raise exception 'KAN-918 pre: a games writer without kan718_game_event_sync exists';
  end if;
end
$guard$;

DROP TRIGGER trg_zz_kan712_games_guard ON public.games;

-- ROLLBACK (verbatim from pg_get_triggerdef, 2026-11-13; the function is not dropped):
-- CREATE TRIGGER trg_zz_kan712_games_guard BEFORE INSERT OR UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION kan712_legacy_guard();
