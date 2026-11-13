-- KAN-923 (Epic KAN-708, KAN-714 chain T; KAN-718 phase 2): drop trigger public.games.trg_kan713_games_c_venue_geo.
--
-- Live catalogue, 2026-11-13 (project wtncuzcskpigqpmnxwws):
--   * Every SQL writer of public.games now fills venue_id / geo_location_id / area_id from the space itself
--     through public.kan718_game_derive (KAN-718 writers). The equality harness
--     (supabase/tests/events_p4/kan718_writers_equality_live_test.sql) gives the same result for every writer
--     with this trigger enabled and disabled.
--   * The function public.kan713_games_venue_geo() is KEPT (trigger only); after this migration nothing calls it.
-- No CASCADE. The guard refuses on drift.
-- Test: supabase/tests/events_p4/kan714_t_trg_kan713_games_c_venue_geo_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.kan713_games_venue_geo()');
begin
  if v_oid is null or md5(pg_get_functiondef(v_oid)) <> 'f7a275556e781e368451c8aa49c3f220' then
    raise exception 'KAN-923 pre: kan713_games_venue_geo() absent or drifted';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.games'::regclass and tgname = 'trg_kan713_games_c_venue_geo'
                 and tgfoid = v_oid and tgenabled = 'O'
                 and pg_get_triggerdef(oid) = 'CREATE TRIGGER trg_kan713_games_c_venue_geo BEFORE INSERT OR UPDATE OF venue_space_id ON public.games FOR EACH ROW EXECUTE FUNCTION kan713_games_venue_geo()') then
    raise exception 'KAN-923 pre: trg_kan713_games_c_venue_geo absent, disabled or drifted';
  end if;
  if to_regprocedure('public.kan718_game_derive(public.games, public.games)') is null then
    raise exception 'KAN-923 pre: KAN-718 writers not applied (kan718_game_derive missing)';
  end if;
end
$guard$;

DROP TRIGGER trg_kan713_games_c_venue_geo ON public.games;

-- ROLLBACK (verbatim from pg_get_triggerdef, 2026-11-13; the function is not dropped):
-- CREATE TRIGGER trg_kan713_games_c_venue_geo BEFORE INSERT OR UPDATE OF venue_space_id ON public.games FOR EACH ROW EXECUTE FUNCTION kan713_games_venue_geo();
