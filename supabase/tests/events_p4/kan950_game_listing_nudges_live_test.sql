-- KAN-950 live test: the games listing nudge reaches a viewer, and only a viewer.
--
-- Run as postgres (execute_sql). One DO block that ends in RAISE EXCEPTION, so every write rolls
-- back; the message carries the results. A line starting FAIL means an assertion did not hold.
--
-- Delivery is measured with realtime.apply_rls, the function Realtime runs for each WAL record:
-- a fake subscription per role is inserted into realtime.subscription (rolled back), and a WAL
-- record for the change is passed in. A subscription id in the result with no error is a
-- message the client would receive.
--
-- Fixtures are picked live: G_priv is a private game, H its creator (non-admin), W an
-- authenticated non-admin user who cannot see G_priv, G_pub a public game W can see.
do $test$
declare
  r          text[] := '{}';
  g_priv     uuid;
  g_pub      uuid;
  h          uuid;
  w          uuid;
  sub_h      uuid := gen_random_uuid();
  sub_w      uuid := gen_random_uuid();
  sub_anon   uuid := gen_random_uuid();
  gsub_h     uuid := gen_random_uuid();
  n          int;
  d          int;
  t0         timestamptz;
  t1         timestamptz;
  delivered  uuid[];
  errs       text;
begin
  -- ---------- fixtures ----------
  select g.id, e.creator_user_id into g_priv, h
  from public.games g join public.events e on e.id = g.event_id and e.event_type = 'game'
  where e.listing_visibility = 'private' and not public.is_admin(e.creator_user_id)
  order by g.id limit 1;

  select p.user_id into w
  from public.profiles p
  where p.user_id is not null and p.user_id <> h and not public.is_admin(p.user_id)
    and not exists (select 1 from public.game_roster gr where gr.game_id = g_priv and gr.user_id = p.user_id)
    and not exists (select 1 from public.game_waitlist gw where gw.game_id = g_priv and gw.user_id = p.user_id)
    and exists (select 1 from auth.users u where u.id = p.user_id)
  order by p.user_id limit 1;

  select g.id into g_pub
  from public.games g join public.events e on e.id = g.event_id and e.event_type = 'game'
  where e.listing_visibility = 'public' and e.is_cancelled = false
    and e.creator_user_id <> w and e.creator_user_id <> h
    and not public.is_blocked(w, e.creator_user_id) and not public.is_blocked(h, e.creator_user_id)
  order by g.id limit 1;

  if g_priv is null or g_pub is null or h is null or w is null then
    raise exception 'KAN950 SETUP_FAILED g_priv=% g_pub=% h=% w=%', g_priv, g_pub, h, w;
  end if;

  -- ---------- shape: grants, policy, publication ----------
  r := r || format('shape: relrowsecurity=%s policies=%s anon_select=%s auth_select=%s auth_insert=%s auth_update=%s auth_delete=%s published=%s',
    (select relrowsecurity from pg_class where oid = 'public.game_listing_nudges'::regclass),
    (select string_agg(policyname || ' ' || cmd || ' ' || array_to_string(roles, ',') || ' ' || qual, '; ')
       from pg_policies where schemaname = 'public' and tablename = 'game_listing_nudges'),
    has_table_privilege('anon', 'public.game_listing_nudges', 'SELECT'),
    has_table_privilege('authenticated', 'public.game_listing_nudges', 'SELECT'),
    has_table_privilege('authenticated', 'public.game_listing_nudges', 'INSERT'),
    has_table_privilege('authenticated', 'public.game_listing_nudges', 'UPDATE'),
    has_table_privilege('authenticated', 'public.game_listing_nudges', 'DELETE'),
    exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
              and schemaname = 'public' and tablename = 'game_listing_nudges'));

  -- ---------- seed: every game gets a nudge row through the games trigger ----------
  update public.games set event_changed_at = '2000-01-01 00:00:00+00';
  select count(*) into n from public.game_listing_nudges;
  r := r || format('seed: games=%s nudge_rows=%s', (select count(*) from public.games), n);

  -- ---------- viewer H and non-viewer W: nudge rows == v_game_card rows, as each user ----------
  perform set_config('request.jwt.claims', json_build_object('sub', h, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.game_listing_nudges;
  select count(*) into d from (
    (select game_id from public.game_listing_nudges except select id from public.v_game_card)
    union all
    (select id from public.v_game_card except select game_id from public.game_listing_nudges)) x;
  r := r || format('H(viewer): nudge_rows=%s card_rows=%s symmetric_diff=%s sees_g_priv=%s %s',
    n, (select count(*) from public.v_game_card), d,
    exists (select 1 from public.game_listing_nudges where game_id = g_priv),
    case when d = 0 and exists (select 1 from public.game_listing_nudges where game_id = g_priv)
         then 'PASS' else 'FAIL' end);
  reset role;

  perform set_config('request.jwt.claims', json_build_object('sub', w, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.game_listing_nudges;
  select count(*) into d from (
    (select game_id from public.game_listing_nudges except select id from public.v_game_card)
    union all
    (select id from public.v_game_card except select game_id from public.game_listing_nudges)) x;
  r := r || format('W(non-viewer of g_priv): nudge_rows=%s card_rows=%s symmetric_diff=%s sees_g_priv=%s sees_g_pub=%s %s',
    n, (select count(*) from public.v_game_card), d,
    exists (select 1 from public.game_listing_nudges where game_id = g_priv),
    exists (select 1 from public.game_listing_nudges where game_id = g_pub),
    case when d = 0 and not exists (select 1 from public.game_listing_nudges where game_id = g_priv)
         then 'PASS' else 'FAIL' end);
  -- games itself still reads nothing (no policy added there)
  r := r || format('W: public.games rows=%s (expect 0)', (select count(*) from public.games));
  reset role;

  perform set_config('request.jwt.claims', '', true);
  set local role anon;
  begin
    select count(*) into n from public.game_listing_nudges;
    r := r || format('anon: select returned %s rows FAIL', n);
  exception when insufficient_privilege then
    r := r || 'anon: select raised 42501 PASS'::text;
  end;
  reset role;

  -- ---------- edit and cancel through events (KAN-949 bump -> KAN-950 upsert) ----------
  select changed_at into t0 from public.game_listing_nudges where game_id = g_priv;
  update public.events e set title = e.title || ' ' from public.games g
   where g.id = g_priv and e.id = g.event_id;
  select changed_at into t1 from public.game_listing_nudges where game_id = g_priv;
  r := r || format('g_priv title edit: nudge moved=%s %s', t1 is distinct from t0,
                   case when t1 is distinct from t0 then 'PASS' else 'FAIL' end);

  select changed_at into t0 from public.game_listing_nudges where game_id = g_pub;
  update public.events e set is_cancelled = true, cancelled_at = now() from public.games g
   where g.id = g_pub and e.id = g.event_id;
  select changed_at into t1 from public.game_listing_nudges where game_id = g_pub;
  r := r || format('g_pub cancel: nudge moved=%s %s', t1 is distinct from t0,
                   case when t1 is distinct from t0 then 'PASS' else 'FAIL' end);

  select changed_at into t0 from public.game_listing_nudges where game_id = g_pub;
  update public.games set allow_spectators = not coalesce(allow_spectators, false) where id = g_pub;
  select changed_at into t1 from public.game_listing_nudges where game_id = g_pub;
  r := r || format('control: games-only edit (allow_spectators): nudge moved=%s %s', t1 is distinct from t0,
                   case when t1 is not distinct from t0 then 'PASS' else 'FAIL' end);

  -- ---------- Realtime delivery (realtime.apply_rls) ----------
  insert into realtime.subscription (subscription_id, entity, claims) values
    (sub_h,    'public.game_listing_nudges'::regclass, jsonb_build_object('sub', h, 'role', 'authenticated')),
    (sub_w,    'public.game_listing_nudges'::regclass, jsonb_build_object('sub', w, 'role', 'authenticated')),
    (sub_anon, 'public.game_listing_nudges'::regclass, jsonb_build_object('role', 'anon')),
    (gsub_h,   'public.games'::regclass,               jsonb_build_object('sub', h, 'role', 'authenticated'));

  -- g_priv edited: H receives, W and anon do not.
  select coalesce(array_remove(array_agg(s), null), '{}'), string_agg(distinct er, ',') into delivered, errs
  from realtime.apply_rls(jsonb_build_object(
      'schema', 'public', 'table', 'game_listing_nudges', 'action', 'U',
      'columns', jsonb_build_array(
         jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv),
         jsonb_build_object('name', 'changed_at', 'type', 'timestamp with time zone', 'typeoid', 1184,
                            'value', (select changed_at from public.game_listing_nudges where game_id = g_priv))),
      'identity', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv)),
      'pk', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950))), 1048576) x
  left join lateral unnest(case when coalesce(array_length(x.errors, 1), 0) = 0 then x.subscription_ids end) s on true
  left join lateral unnest(x.errors) er on true;
  r := r || format('realtime g_priv edit: H=%s W=%s anon=%s errors=%s %s',
    sub_h = any(delivered), sub_w = any(delivered), sub_anon = any(delivered), coalesce(errs, '-'),
    case when sub_h = any(delivered) and not sub_w = any(delivered) and not sub_anon = any(delivered)
         then 'PASS' else 'FAIL' end);

  -- g_pub cancelled: H and W receive, anon does not.
  select coalesce(array_remove(array_agg(s), null), '{}') into delivered
  from realtime.apply_rls(jsonb_build_object(
      'schema', 'public', 'table', 'game_listing_nudges', 'action', 'U',
      'columns', jsonb_build_array(
         jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_pub),
         jsonb_build_object('name', 'changed_at', 'type', 'timestamp with time zone', 'typeoid', 1184,
                            'value', (select changed_at from public.game_listing_nudges where game_id = g_pub))),
      'identity', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_pub)),
      'pk', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950))), 1048576) x
  left join lateral unnest(case when coalesce(array_length(x.errors, 1), 0) = 0 then x.subscription_ids end) s on true;
  r := r || format('realtime g_pub cancel: H=%s W=%s anon=%s %s',
    sub_h = any(delivered), sub_w = any(delivered), sub_anon = any(delivered),
    case when sub_h = any(delivered) and sub_w = any(delivered) and not sub_anon = any(delivered)
         then 'PASS' else 'FAIL' end);

  -- Before KAN-950: the same edit on public.games reaches even its creator H nowhere.
  select coalesce(array_remove(array_agg(s), null), '{}') into delivered
  from realtime.apply_rls(jsonb_build_object(
      'schema', 'public', 'table', 'games', 'action', 'U',
      'columns', jsonb_build_array(
         jsonb_build_object('name', 'id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv),
         jsonb_build_object('name', 'event_changed_at', 'type', 'timestamp with time zone', 'typeoid', 1184, 'value', now())),
      'identity', jsonb_build_array(jsonb_build_object('name', 'id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv)),
      'pk', jsonb_build_array(jsonb_build_object('name', 'id', 'type', 'uuid', 'typeoid', 2950))), 1048576) x
  left join lateral unnest(case when coalesce(array_length(x.errors, 1), 0) = 0 then x.subscription_ids end) s on true;
  r := r || format('FAILFIRST realtime on public.games (the old channel): H=%s (expect false)', gsub_h = any(delivered));

  -- ---------- the probe discriminates: break the policy and watch the checks fail ----------
  -- (a) no policy: the viewer receives nothing.
  drop policy game_listing_nudges_select_visible on public.game_listing_nudges;
  select coalesce(array_remove(array_agg(s), null), '{}') into delivered
  from realtime.apply_rls(jsonb_build_object(
      'schema', 'public', 'table', 'game_listing_nudges', 'action', 'U',
      'columns', jsonb_build_array(
         jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv),
         jsonb_build_object('name', 'changed_at', 'type', 'timestamp with time zone', 'typeoid', 1184, 'value', now())),
      'identity', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv)),
      'pk', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950))), 1048576) x
  left join lateral unnest(case when coalesce(array_length(x.errors, 1), 0) = 0 then x.subscription_ids end) s on true;
  r := r || format('FAILFIRST no policy: realtime H=%s (expect false)', sub_h = any(delivered));

  -- (b) a widened policy: the non-viewer sees g_priv and receives its nudge.
  create policy kan950_failfirst_wide on public.game_listing_nudges for select to authenticated using (true);
  perform set_config('request.jwt.claims', json_build_object('sub', w, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into d from (
    (select game_id from public.game_listing_nudges except select id from public.v_game_card)
    union all
    (select id from public.v_game_card except select game_id from public.game_listing_nudges)) x;
  r := r || format('FAILFIRST wide policy: W symmetric_diff=%s sees_g_priv=%s (expect >0, true)', d,
    exists (select 1 from public.game_listing_nudges where game_id = g_priv));
  reset role;
  select coalesce(array_remove(array_agg(s), null), '{}') into delivered
  from realtime.apply_rls(jsonb_build_object(
      'schema', 'public', 'table', 'game_listing_nudges', 'action', 'U',
      'columns', jsonb_build_array(
         jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv),
         jsonb_build_object('name', 'changed_at', 'type', 'timestamp with time zone', 'typeoid', 1184, 'value', now())),
      'identity', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950, 'value', g_priv)),
      'pk', jsonb_build_array(jsonb_build_object('name', 'game_id', 'type', 'uuid', 'typeoid', 2950))), 1048576) x
  left join lateral unnest(case when coalesce(array_length(x.errors, 1), 0) = 0 then x.subscription_ids end) s on true;
  r := r || format('FAILFIRST wide policy: realtime W=%s (expect true)', sub_w = any(delivered));

  raise exception E'KAN950_RESULT (rolled back)\n%', array_to_string(r, E'\n');
end
$test$;
