-- KAN-958 live test: profiles are discoverable by default (migrations 20261115214329_kan958_profiles_visible_by_default
-- and 20261115215007_kan958_end_bench_clears_hide_in_search).
-- One DO block. It always ends in RAISE EXCEPTION, so everything it writes (one user_status row, one user_blocks
-- row, and E's bench row) rolls back. Probes run as `authenticated` with a real profile's JWT sub.
-- Expected: ERROR 'KAN-958 PASS ...'. Any failed probe yields 'KAN-958 FAIL ...' with the list.
-- Targets: the three newest active personal profiles (distinct users, not the viewer, no user_status row, no block
-- either way with the viewer). A = no row, H = gets hide_in_search=true, B = blocked by the viewer.
-- E = the fourth newest: as E, rpc_toggle_bench(true, hide_in_search=true), then rpc_end_bench(); E is hidden
-- while benched and visible (helper and stream) after the bench ends.
-- v_neg := true is the negative control: H's opt-out row and B's block are not inserted, rpc_end_bench() is not
-- called for E, and the anon probe runs as authenticated. The H, B, E-after-end and anon probes then FAIL (seen 2026-11-16).
DO $t$
DECLARE
  v_neg     boolean := false;
  v_viewer  uuid;
  v_a       record;
  v_h       record;
  v_b       record;
  v_fail    text[] := '{}';
  v_info    text := '';
  v_vis_a   boolean;
  v_vis_h   boolean;
  v_vis_b   boolean;
  v_pj_all  int;
  v_pj_only int;
  v_a_in    boolean;
  v_h_in    boolean;
  v_b_in    boolean;
  v_e       record;
  v_e_bench boolean;
  v_e_end   boolean;
  v_e_in    boolean;
BEGIN
  SELECT p.user_id INTO v_viewer
    FROM public.profiles p
   WHERE p.profile_type = 'personal' AND p.user_id IS NOT NULL
   ORDER BY p.created_at LIMIT 1;

  CREATE TEMP TABLE _k958_t ON COMMIT DROP AS
    SELECT DISTINCT ON (p.user_id) p.id, p.user_id, p.created_at
      FROM public.profiles p
     WHERE p.profile_type = 'personal' AND p.is_active AND p.user_id IS NOT NULL AND p.created_at IS NOT NULL
       AND p.user_id <> v_viewer
       AND NOT public.is_benched(p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.user_status us WHERE us.user_id = p.user_id)
       AND NOT public.is_blocked(v_viewer, p.user_id)
     ORDER BY p.user_id, p.created_at DESC;
  SELECT * INTO v_a FROM _k958_t ORDER BY created_at DESC, id OFFSET 0 LIMIT 1;
  SELECT * INTO v_h FROM _k958_t ORDER BY created_at DESC, id OFFSET 1 LIMIT 1;
  SELECT * INTO v_b FROM _k958_t ORDER BY created_at DESC, id OFFSET 2 LIMIT 1;
  SELECT * INTO v_e FROM _k958_t ORDER BY created_at DESC, id OFFSET 3 LIMIT 1;
  IF v_e.id IS NULL THEN RAISE EXCEPTION 'KAN-958 SETUP: fewer than 4 target profiles'; END IF;

  IF NOT v_neg THEN
    INSERT INTO public.user_status (user_id, is_benched, hide_in_search) VALUES (v_h.user_id, false, true);
    INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (v_viewer, v_b.user_id);
  END IF;

  -- probes, as authenticated
  -- E benches with "Hide me in search" on, as E; the viewer sees E hidden; E ends the bench, as E.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_e.user_id, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_toggle_bench(true, NULL, NULL, true, true, true, false);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_viewer, 'role', 'authenticated')::text, true);
  v_e_bench := public.is_profile_publicly_visible(v_e.id);
  IF NOT v_neg THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_e.user_id, 'role', 'authenticated')::text, true);
    PERFORM public.rpc_end_bench();
  END IF;
  EXECUTE 'RESET ROLE';

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_viewer, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_e_end := public.is_profile_publicly_visible(v_e.id);
  v_vis_a := public.is_profile_publicly_visible(v_a.id);
  v_vis_h := public.is_profile_publicly_visible(v_h.id);
  v_vis_b := public.is_profile_publicly_visible(v_b.id);
  SELECT count(*) FILTER (WHERE s.event_type = 'player_joined') INTO v_pj_all
    FROM public.active_stream(NULL, NULL, 50, NULL, NULL, NULL) s;
  SELECT count(*),
         bool_or(s.entity_id = v_a.id), bool_or(s.entity_id = v_h.id), bool_or(s.entity_id = v_b.id), bool_or(s.entity_id = v_e.id)
    INTO v_pj_only, v_a_in, v_h_in, v_b_in, v_e_in
    FROM public.active_stream(ARRAY['player_joined'], NULL, 50, NULL, NULL, NULL) s;
  EXECUTE 'RESET ROLE';

  v_info := format('vis a/h/b=%s/%s/%s; player_joined in unfiltered=%s, in player_joined-only=%s; in stream a/h/b=%s/%s/%s; e benched/ended/in stream=%s/%s/%s; visible profiles=%s',
                   v_vis_a, v_vis_h, v_vis_b, v_pj_all, v_pj_only,
                   coalesce(v_a_in, false), coalesce(v_h_in, false), coalesce(v_b_in, false),
                   v_e_bench, v_e_end, coalesce(v_e_in, false),
                   (SELECT count(*) FROM public.profiles p WHERE public.is_profile_publicly_visible(p.id)));

  -- 1. no user_status row => visible, and in the stream
  IF v_vis_a IS NOT TRUE THEN v_fail := v_fail || 'A (no row): is_profile_publicly_visible not true'::text; END IF;
  IF NOT coalesce(v_a_in, false) THEN v_fail := v_fail || 'A (no row): missing from player_joined stream'::text; END IF;
  -- 2. hide_in_search=true => hidden (as authenticated, who cannot read H's user_status row under RLS)
  IF v_vis_h IS NOT FALSE THEN v_fail := v_fail || 'H (hide_in_search=true): is_profile_publicly_visible not false'::text; END IF;
  IF coalesce(v_h_in, false) THEN v_fail := v_fail || 'H (hide_in_search=true): present in player_joined stream'::text; END IF;
  -- 3. blocked => still hidden from the viewer's stream (block is applied by active_stream, not the helper)
  IF coalesce(v_b_in, false) THEN v_fail := v_fail || 'B (blocked): present in player_joined stream'::text; END IF;
  -- 3b. bench with hide, then end bench => visible again
  IF v_e_bench IS NOT FALSE THEN v_fail := v_fail || 'E (benched, hide on): is_profile_publicly_visible not false'::text; END IF;
  IF v_e_end IS NOT TRUE THEN v_fail := v_fail || 'E (bench ended): is_profile_publicly_visible not true'::text; END IF;
  IF NOT coalesce(v_e_in, false) THEN v_fail := v_fail || 'E (bench ended): missing from player_joined stream'::text; END IF;
  -- 4. player_joined rows now appear, unfiltered and filtered
  IF v_pj_all = 0 THEN v_fail := v_fail || 'active_stream(NULL,...): 0 player_joined rows'::text; END IF;
  IF v_pj_only = 0 THEN v_fail := v_fail || 'active_stream(ARRAY[player_joined],...): 0 rows'::text; END IF;

  -- 5. anon cannot execute the helper
  IF NOT v_neg THEN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    EXECUTE 'SET LOCAL ROLE anon';
  ELSE
    EXECUTE 'SET LOCAL ROLE authenticated';
  END IF;
  BEGIN
    PERFORM public.is_profile_publicly_visible(v_a.id);
    v_fail := v_fail || 'anon: call succeeded, expected 42501'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'RESET ROLE';

  IF cardinality(v_fail) = 0 THEN
    RAISE EXCEPTION 'KAN-958 PASS (neg=%): %', v_neg, v_info;
  ELSE
    RAISE EXCEPTION 'KAN-958 FAIL (neg=%) % failures: % | %', v_neg, cardinality(v_fail), array_to_string(v_fail, ' || '), v_info;
  END IF;
END
$t$;
