-- KAN-934 item 3: in a casual (player-created) game the host plays, so the host's active roster row counts toward
-- roster_count and against capacity, exactly like a player. A hosted (organiser) game keeps today's rule (host
-- counted). league / training are unchanged (host not counted).
--
-- Before: every count used  role = 'player' OR (role = 'host' AND game_type = 'hosted').  A new casual game showed
-- "0 of N", and because rpc_join_game reads game_slots_left, a casual game admitted capacity players plus the host
-- (overfilled by one; proved live by the KAN-934 test, T10 before: 5 active at capacity 4).
-- After:  role = 'player' OR (role = 'host' AND game_type IN ('hosted', 'casual')).
--
-- Re-authored from the live catalogue: each body is pg_get_functiondef / pg_get_viewdef of the pre-image (md5-pinned
-- below) with exactly one predicate occurrence replaced, so every other attribute (SECURITY, search_path, volatility,
-- column list) is carried verbatim. CREATE OR REPLACE keeps owner and ACL; v_game_card has no reloptions to carry.
-- Callers that follow automatically: rpc_join_game, can_current_user_join_game, rpc_decide_join_request
-- (all read game_slots_left). rpc_get_nearby_games_legacy_v1 counts players only (host never) and is left as is.

DO $kan934$
DECLARE
  r record; d text; n int; after text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.game_slots_left(uuid)', '3fff44caa9de112a54673bc393eb2616',
     $o$(r.role = 'host' AND v_game_type = 'hosted')$o$,
     $n$(r.role = 'host' AND v_game_type IN ('hosted', 'casual'))  /* KAN-934: a casual host plays */$n$),
    ('public.kan714_game_slots_left(uuid)', '99016be8426a08e131512b6f956a5f8d',
     $o$(r.role = 'host' AND v_game_type = 'hosted')$o$,
     $n$(r.role = 'host' AND v_game_type IN ('hosted', 'casual'))  /* KAN-934: a casual host plays */$n$),
    ('public.rpc_game_card_by_link(uuid,uuid)', '47fbf4343b402092fb8ad4fc98ba6cb7',
     $o$gr.role = 'host'::text AND g.game_type = 'hosted'::text$o$,
     $n$gr.role = 'host'::text AND g.game_type = ANY (ARRAY['hosted'::text, 'casual'::text]) /* KAN-934 */$n$),
    ('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', '430b7e48bd4ed1cca4e342dee69e390c',
     $o$(gr.role = 'host' and g.game_type = 'hosted')$o$,
     $n$(gr.role = 'host' and g.game_type in ('hosted', 'casual'))  /* KAN-934: a casual host plays */$n$),
    ('public.rpc_get_nearby_games_legacy_v2(double precision,double precision,integer,uuid,text)', '32016fbef7c97b1dd1873fb1837a3f25',
     $o$(gr.role = 'host' and g.game_type = 'hosted')$o$,
     $n$(gr.role = 'host' and g.game_type in ('hosted', 'casual'))  /* KAN-934: a casual host plays */$n$),
    ('public.rpc_get_nearby_games_legacy_v3(double precision,double precision,integer,uuid,text)', 'b6f72e73fa3f8bd568e900b58f8f0bf3',
     $o$(gr.role = 'host' and g.game_type = 'hosted')$o$,
     $n$(gr.role = 'host' and g.game_type in ('hosted', 'casual'))  /* KAN-934: a casual host plays */$n$)
  ) v(sig, md5_pre, old_pred, new_pred)
  LOOP
    d := pg_get_functiondef(r.sig::regprocedure);
    IF md5(d) <> r.md5_pre THEN
      RAISE EXCEPTION 'KAN-934 pre-image guard: % changed (md5 %)', r.sig, md5(d);
    END IF;
    n := (length(d) - length(replace(d, r.old_pred, ''))) / length(r.old_pred);
    IF n <> 1 THEN
      RAISE EXCEPTION 'KAN-934: % has % occurrences of the predicate, expected 1', r.sig, n;
    END IF;
    EXECUTE replace(d, r.old_pred, r.new_pred);
  END LOOP;

  d := pg_get_viewdef('public.v_game_card'::regclass);
  IF md5(d) <> 'b13dfbc501ce23fcad51af9bc6ad2df7' THEN
    RAISE EXCEPTION 'KAN-934 pre-image guard: v_game_card changed (md5 %)', md5(d);
  END IF;
  IF (SELECT reloptions FROM pg_class WHERE oid = 'public.v_game_card'::regclass) IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-934 pre-image guard: v_game_card has reloptions';
  END IF;
  after := replace(d, $o$((gr.role = 'host'::text) AND (g.game_type = 'hosted'::text))$o$,
                      $n$((gr.role = 'host'::text) AND (g.game_type = ANY (ARRAY['hosted'::text, 'casual'::text])))$n$);
  IF after = d THEN
    RAISE EXCEPTION 'KAN-934: v_game_card predicate not found';
  END IF;
  EXECUTE 'CREATE OR REPLACE VIEW public.v_game_card AS ' || rtrim(after, E'; \n');
END
$kan934$;

-- Post-assert: owner, ACL and security attributes unchanged; no stale predicate remains.
DO $post$
BEGIN
  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('public.game_slots_left(uuid)', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', false),
      ('public.kan714_game_slots_left(uuid)', '{postgres=X/postgres}', false),
      ('public.rpc_game_card_by_link(uuid,uuid)', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', true),
      ('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres,anon=X/postgres}', true),
      ('public.rpc_get_nearby_games_legacy_v2(double precision,double precision,integer,uuid,text)', '{postgres=X/postgres,service_role=X/postgres}', true),
      ('public.rpc_get_nearby_games_legacy_v3(double precision,double precision,integer,uuid,text)', '{postgres=X/postgres,service_role=X/postgres}', true)
    ) v(sig, acl, secdef)
    JOIN pg_proc p ON p.oid = v.sig::regprocedure
    WHERE p.proacl::text <> v.acl OR p.prosecdef <> v.secdef OR p.proowner <> 'postgres'::regrole
       OR pg_get_functiondef(p.oid) LIKE '%game_type = ''hosted'')%'
       OR pg_get_functiondef(p.oid) LIKE '%game_type = ''hosted''::text)%'
  ) THEN
    RAISE EXCEPTION 'KAN-934 post-assert: a function lost its ACL/owner/security or kept the old predicate';
  END IF;
  IF (SELECT relacl::text || pg_get_userbyid(relowner) || COALESCE(reloptions::text, '-')
        FROM pg_class WHERE oid = 'public.v_game_card'::regclass)
     <> '{postgres=arwdDxtm/postgres,anon=rxtm/postgres,authenticated=rxtm/postgres,service_role=arwdDxtm/postgres}postgres-'
     OR pg_get_viewdef('public.v_game_card'::regclass) LIKE '%(g.game_type = ''hosted''::text)%' THEN
    RAISE EXCEPTION 'KAN-934 post-assert: v_game_card ACL/owner/options changed or old predicate kept';
  END IF;
END
$post$;
