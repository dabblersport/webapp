-- KAN-951 option (b): drop both get_nearby_games overloads.
-- 20261114124807 re-authored them to read lat / lng from geo_locations, but they are SECURITY INVOKER and
-- public.events grants nothing to anon or authenticated, so every client call raises 42501. No screen reaches
-- them: the nearby list is rpc_get_nearby_games, and frontend-2 is deleting the dead Dart callers
-- (nearby_games_repository_impl, the explore nearbyGamesProvider chain, supabase_games_datasource.getNearbyGames).
-- Pre-image (functiondef md5, the 20261114124807 bodies):
--   get_nearby_games(f8,f8,int)   28c7135a05ab7cf6cab5e2113ed0bd4b
--   get_nearby_games(f8,f8,f8)    08849b7336df48cf71d76a638a9c7cf8
-- Test: supabase/tests/events_p4/kan951_953_broken_readers_live_test.sql.

do $pre$
declare
  k record;
begin
  for k in select * from (values
    ('public.get_nearby_games(double precision,double precision,integer)', '28c7135a05ab7cf6cab5e2113ed0bd4b'),
    ('public.get_nearby_games(double precision,double precision,double precision)', '08849b7336df48cf71d76a638a9c7cf8')) v(fn, pre)
  loop
    if md5(pg_get_functiondef(to_regprocedure(k.fn))) is distinct from k.pre then
      raise exception 'KAN-951 drop pre: % absent or drifted', k.fn;
    end if;
  end loop;
  if exists (select 1 from pg_proc p where p.pronamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace)
              and p.proname <> 'get_nearby_games' and p.prosrc ~ '(^|[^_])get_nearby_games') then
    raise exception 'KAN-951 drop pre: another function names get_nearby_games';
  end if;
end
$pre$;

DROP FUNCTION public.get_nearby_games(double precision, double precision, integer);
DROP FUNCTION public.get_nearby_games(double precision, double precision, double precision);

do $post$
begin
  if exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace and proname = 'get_nearby_games') then
    raise exception 'KAN-951 drop post: a get_nearby_games overload is still present';
  end if;
  if to_regprocedure('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)') is null then
    raise exception 'KAN-951 drop post: rpc_get_nearby_games missing';
  end if;
end
$post$;
