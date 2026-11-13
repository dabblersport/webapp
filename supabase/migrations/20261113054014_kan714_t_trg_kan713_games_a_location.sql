-- KAN-921 (Epic KAN-708, KAN-714 chain T; KAN-718 phase 2): drop trigger public.games.trg_kan713_games_a_location.
--
-- Live catalogue, 2026-11-13 (project wtncuzcskpigqpmnxwws):
--   * Every SQL writer of public.games now derives venue_id / geo_location_id / area_id itself through
--     public.kan718_game_derive (KAN-718 writers, migrations 20261113052154..20261113052448). The equality
--     harness (supabase/tests/events_p4/kan718_writers_equality_live_test.sql) gives the same result for every
--     writer with this trigger enabled and disabled.
--   * authenticated cannot write public.games rows (RLS on, no policy); only postgres / service_role can.
--   * The function public.kan713_games_location() is KEPT (this ticket drops the trigger only); after this
--     migration nothing calls it.
-- No CASCADE. The guard refuses on drift.
-- Test: supabase/tests/events_p4/kan714_t_trg_kan713_games_a_location_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.kan713_games_location()');
begin
  if v_oid is null or md5(pg_get_functiondef(v_oid)) <> 'c9ba4ff6d0e1ae8be4d1f6a825f86b6e' then
    raise exception 'KAN-921 pre: kan713_games_location() absent or drifted';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.games'::regclass and tgname = 'trg_kan713_games_a_location'
                 and tgfoid = v_oid and tgenabled = 'O'
                 and pg_get_triggerdef(oid) = 'CREATE TRIGGER trg_kan713_games_a_location BEFORE INSERT OR UPDATE OF venue_id, venue_space_id ON public.games FOR EACH ROW EXECUTE FUNCTION kan713_games_location()') then
    raise exception 'KAN-921 pre: trg_kan713_games_a_location absent, disabled or drifted';
  end if;
  if to_regprocedure('public.kan718_game_derive(public.games, public.games)') is null then
    raise exception 'KAN-921 pre: KAN-718 writers not applied (kan718_game_derive missing)';
  end if;
end
$guard$;

DROP TRIGGER trg_kan713_games_a_location ON public.games;

-- ROLLBACK (verbatim from pg_get_triggerdef, 2026-11-13; the function is not dropped):
-- CREATE TRIGGER trg_kan713_games_a_location BEFORE INSERT OR UPDATE OF venue_id, venue_space_id ON public.games FOR EACH ROW EXECUTE FUNCTION kan713_games_location();
