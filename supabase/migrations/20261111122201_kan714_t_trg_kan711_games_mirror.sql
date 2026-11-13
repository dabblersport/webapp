-- KAN-920 (Epic KAN-708, KAN-714 chain T): drop trigger public.games.trg_kan711_games_mirror and its
-- function public.kan711_games_mirror().
--
-- Live catalogue, 2026-11-13 (project wtncuzcskpigqpmnxwws):
--   * trg_kan711_games_mirror is DISABLED (pg_trigger.tgenabled = 'D'); it has fired for nothing since the
--     KAN-712 cutover replaced it with trg_zz_kan712_games_guard. Dropping it changes no write path.
--   * kan711_games_mirror() is used by this one trigger only (pg_depend: one 'n' dependency, pg_trigger 120368)
--     and is named in no other function body (pg_proc.prosrc grep), and no function re-enables the trigger.
--   * Not touched: kan711_events_upsert / kan711_events_map_game (it calls them; they stay), and the meetups
--     counterpart kan711_meetups_mirror().
-- File timestamp: 20261111122200 is already taken by kan714_w_fn_generate_game_series_occurrences_kan712_inner,
-- so this file uses 20261111122201 to avoid a duplicate migration version.
-- No CASCADE. The guard refuses on drift.
-- Test: supabase/tests/events_p4/kan714_t_trg_kan711_games_mirror_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.kan711_games_mirror()');
begin
  if v_oid is null then raise exception 'KAN-920 pre: kan711_games_mirror() absent'; end if;
  if md5(pg_get_functiondef(v_oid)) <> 'b98d5a3316afb6557d6f7f17cbac00c8' then
    raise exception 'KAN-920 pre: functiondef drift on kan711_games_mirror(); re-author from pg_get_functiondef';
  end if;
  if (select count(*) from pg_trigger where tgfoid = v_oid) <> 1
     or not exists (select 1 from pg_trigger where tgfoid = v_oid and tgname = 'trg_kan711_games_mirror'
                    and tgrelid = 'public.games'::regclass and tgenabled = 'D') then
    raise exception 'KAN-920 pre: trg_kan711_games_mirror is not the single, disabled user of kan711_games_mirror()';
  end if;
end
$guard$;

DROP TRIGGER trg_kan711_games_mirror ON public.games;
DROP FUNCTION public.kan711_games_mirror();

-- ROLLBACK (verbatim from pg_get_triggerdef / pg_get_functiondef, 2026-11-13; owner postgres,
-- ACL {postgres=X/postgres}; the trigger was disabled):
-- CREATE OR REPLACE FUNCTION public.kan711_games_mirror()
--  RETURNS trigger
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO ''
-- AS $function$
-- BEGIN
--   IF TG_OP = 'DELETE' THEN
--     DELETE FROM public.events WHERE id = OLD.id AND event_type = 'game';
--     RETURN OLD;
--   END IF;
--   PERFORM public.kan711_events_upsert(public.kan711_events_map_game(NEW));
--   RETURN NEW;
-- END $function$;
-- REVOKE ALL ON FUNCTION public.kan711_games_mirror() FROM PUBLIC, anon, authenticated, service_role;
-- CREATE TRIGGER trg_kan711_games_mirror AFTER INSERT OR DELETE OR UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION kan711_games_mirror();
-- ALTER TABLE public.games DISABLE TRIGGER trg_kan711_games_mirror;
