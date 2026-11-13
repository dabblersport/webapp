-- KAN-919 (Epic KAN-708, KAN-714 chain T; KAN-718 phase 2): drop trigger public.games.trg_zz_kan712_games_after_delete.
--
-- Live catalogue, 2026-11-13 (project wtncuzcskpigqpmnxwws):
--   * The only SQL deleter of games, admin_cleanup_user_data, now deletes the events parent and
--     games_event_id_fkey (ON DELETE CASCADE) removes the games row (KAN-718). No FK cascades a delete into
--     games from any other table.
--   * authenticated cannot delete games rows (RLS on, no policy). After this drop a direct postgres /
--     service_role DELETE on games leaves its events parent: delete the events row instead.
--   * The function public.kan712_legacy_after_delete() is KEPT: public.meetups.trg_zz_kan712_meetups_after_delete
--     uses it.
-- No CASCADE. The guard refuses on drift.
-- Test: supabase/tests/events_p4/kan714_t_trg_zz_kan712_games_after_delete_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.kan712_legacy_after_delete()');
begin
  if v_oid is null or md5(pg_get_functiondef(v_oid)) <> '64c28594fc83721edc0b5734c920ec08' then
    raise exception 'KAN-919 pre: kan712_legacy_after_delete() absent or drifted';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.games'::regclass and tgname = 'trg_zz_kan712_games_after_delete'
                 and tgfoid = v_oid and tgenabled = 'O'
                 and pg_get_triggerdef(oid) = 'CREATE TRIGGER trg_zz_kan712_games_after_delete AFTER DELETE ON public.games FOR EACH ROW EXECUTE FUNCTION kan712_legacy_after_delete()') then
    raise exception 'KAN-919 pre: trg_zz_kan712_games_after_delete absent, disabled or drifted';
  end if;
  if exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace
              and prosrc ~* 'delete\s+from\s+(public\.)?games\M') then
    raise exception 'KAN-919 pre: a function still deletes from games directly';
  end if;
end
$guard$;

DROP TRIGGER trg_zz_kan712_games_after_delete ON public.games;

-- ROLLBACK (verbatim from pg_get_triggerdef, 2026-11-13; the function is not dropped):
-- CREATE TRIGGER trg_zz_kan712_games_after_delete AFTER DELETE ON public.games FOR EACH ROW EXECUTE FUNCTION kan712_legacy_after_delete();
