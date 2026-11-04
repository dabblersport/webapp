#!/usr/bin/env bash
# KAN-808 test: rpc_join_game must refuse a join that races a cancel (KAN-761 scenario S5, cancel vs join).
#
# LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE. It writes fixture rows (games, roster, requests).
#
# Usage: bash kan808_join_recheck_cancelled.sh <socket-dir|localhost> <port> <db>
#   <db> must be a local disposable k* database built from the events chain (KAN-710..714, KAN-772 D04/D05, KAN-801).
#   Exit 0 = every check PASS; exit 1 = a check FAILED; exit 2 = refused / could not run.
#
# Two REAL sessions, both as role authenticated with a JWT subject (request.jwt.claims + request.jwt.claim.sub; the
# local auth.uid() stub reads claim.sub, Supabase's reads either):
#   session A (host a1):  BEGIN; SELECT rpc_cancel_game(G, 'kan808'); SELECT pg_sleep(3); COMMIT;   (background)
#   session B (user a2):  started 1 s later; SELECT * FROM rpc_join_game('player', G);
# A third (postgres) session samples pg_stat_activity 0.5 s into B, to show B really waits on a lock held by A.
#
# Checks (want = the KAN-808 post-image; on the pre-image R1/R2 FAIL, everything else PASSES both ways):
#   R1  F1 open game:    B waits on A's games row lock, then is refused P0001 cancelled/cancelled; no roster row.
#   R2  F2 request game: same wait and refusal; no pending game_join_requests row on the cancelled game.
#   E1  join after the cancel COMMITTED (open game):    P0001 cancelled / detail cancelled (the refusal R1/R2 match).
#   E2  join after the cancel COMMITTED (request game): P0001 cancelled / detail cancelled.
#   E3  live open game:              joined|active|-
#   E4  live request game:           request_submitted|-|-  and one pending request row
#   E5  full game (capacity 2, two active), allows_waitlist = true:  waitlisted|-|1
#   E6  full game, allows_waitlist = false: waitlisted|-|1  (O1, KAN-757 J6.a3: kept open, NOT changed by KAN-808)
#
# Fixture (local only): the harness game_join_requests has no baseline trg_joinreq_set_user, so the request branch
# hits from_user_id NOT NULL. It is installed VERBATIM from 20260829080500_baseline_schema.sql (function
# trgfn_joinreq_set_user + trigger at :29915) when absent. Game ids are fresh per run, so the test can be re-run.
set -u -o pipefail

H="${1:?usage: kan808_join_recheck_cancelled.sh <socket-dir|localhost> <port> <db>}"
PORT="${2:?port}"
DB="${3:?db}"

if ! { [ -d "$H" ] || [ "$H" = localhost ] || [ "$H" = 127.0.0.1 ]; }; then
  echo "KAN-808 test: refusing host $H: local socket directory or localhost only" >&2; exit 2
fi
case "$DB" in k*) ;; *) echo "KAN-808 test: refusing database $DB: local disposable k* databases only" >&2; exit 2 ;; esac

PSQL=(psql -X -q -h "$H" -p "$PORT" -U postgres -d "$DB")
S() { "${PSQL[@]}" -v ON_ERROR_STOP=1 -At "$@"; }

S <<'SQL' || { echo "KAN-808 test: guard/fixture failed" >&2; exit 2; }
DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-808 test: this looks like a Supabase database; local disposable database only';
  END IF;
  IF to_regprocedure('public.rpc_join_game(text,uuid,uuid)') IS NULL OR to_regprocedure('public.rpc_cancel_game(uuid,text)') IS NULL
     OR to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-808 test: events chain with rpc_join_game / rpc_cancel_game required';
  END IF;
END $g$;
DO $fx$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.game_join_requests'::regclass AND tgname = 'trg_joinreq_set_user') THEN
    -- VERBATIM 20260829080500_baseline_schema.sql trgfn_joinreq_set_user + :29915 trigger (local fixture only)
    EXECUTE $f$CREATE OR REPLACE FUNCTION "public"."trgfn_joinreq_set_user"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare uid uuid;
begin
  select user_id into uid from public.profiles where id = new.from_profile_id;
  if uid is null then raise exception using errcode='P0001', message='profile_not_found'; end if;
  new.from_user_id := uid;
  return new;
end$$$f$;
    EXECUTE 'CREATE OR REPLACE TRIGGER "trg_joinreq_set_user" BEFORE INSERT OR UPDATE OF "from_profile_id" ON "public"."game_join_requests" FOR EACH ROW EXECUTE FUNCTION "public"."trgfn_joinreq_set_user"()';
  END IF;
END $fx$;
SQL

HOST_U=00000000-0000-0000-0000-0000000000a1; HOST_P=00000000-0000-0000-0000-0000000000b1
JOIN_U=00000000-0000-0000-0000-0000000000a2; JOIN_P=00000000-0000-0000-0000-0000000000b2
FILL_U=00000000-0000-0000-0000-0000000000a3; FILL_P=00000000-0000-0000-0000-0000000000b3
FILL2_U=00000000-0000-0000-0000-0000000000a4; FILL2_P=00000000-0000-0000-0000-0000000000b4

# new game as the fixture owner (postgres): <join_policy> <capacity> <allows_waitlist>; prints its id
newgame() {
  S -c "INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
          join_policy, allows_waitlist, sport_id, geo_location_id, area_id)
        VALUES (gen_random_uuid(), 'KAN-808 $1', '$HOST_P', '$HOST_U', '2031-07-01 18:00+00', '2031-07-01 20:00+00', $2, 'public',
          '$1', $3, '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1')
        RETURNING id" | head -1 | grep -E '^[0-9a-f-]{36}$' || { echo "KAN-808 test: fixture game ($1) not created" >&2; exit 2; }
}
# psql script prefix: act as <uid>, role authenticated, application_name <app>
as_user() {
  printf "SET application_name = '%s';\nSELECT set_config('request.jwt.claims', '{\"sub\":\"%s\",\"role\":\"authenticated\"}', false), set_config('request.jwt.claim.sub', '%s', false) \\\\g /dev/null\nSET ROLE authenticated;\n" "$2" "$1" "$1"
}
# rpc_join_game as <uid> on <game>; prints 'ret:<result|roster_status|waitlist_position>' or 'err:<SQLSTATE>:<message>:<detail>'
join_sql() { printf "SELECT 'ret:' || r.result || '|' || coalesce(r.roster_status, '-') || '|' || coalesce(r.waitlist_position::text, '-') FROM public.rpc_join_game('player', '%s'::uuid) r;\n" "$1"; }
norm() {  # psql -At output with VERBOSITY verbose -> one token
  local out; out=$(cat)
  if grep -q '^ret:' <<<"$out"; then grep '^ret:' <<<"$out" | head -1
  else
    local code msg det
    code=$(sed -nE 's/^(psql:[^E]*)?ERROR:  ([0-9A-Z]{5}): (.*)$/\2/p' <<<"$out" | head -1)
    msg=$(sed -nE 's/^(psql:[^E]*)?ERROR:  ([0-9A-Z]{5}): (.*)$/\3/p' <<<"$out" | head -1)
    det=$(sed -nE 's/^DETAIL:  (.*)$/\1/p' <<<"$out" | head -1)
    echo "err:$code:$msg:$det"
  fi
}
join_now() { { as_user "$1" kan808_b; echo '\set VERBOSITY verbose'; join_sql "$2"; } | "${PSQL[@]}" -At 2>&1 | norm; }
cancel_now() { { as_user "$HOST_U" kan808_a; echo "SELECT public.rpc_cancel_game('$1'::uuid, 'kan808');"; } | "${PSQL[@]}" -At -v ON_ERROR_STOP=1 >/dev/null; }
state() {  # <game> -> games/events cancelled, joiner roster row, joiner pending request
  S -c "SELECT format('games.is_cancelled=%s events.is_cancelled=%s roster_b2=%s pending_b2=%s',
           g.is_cancelled, e.is_cancelled,
           coalesce((SELECT string_agg(r.status, ',') FROM public.game_roster r WHERE r.game_id = g.id AND r.profile_id = '$JOIN_P'), 'none'),
           (SELECT count(*) FROM public.game_join_requests q WHERE q.game_id = g.id AND q.from_profile_id = '$JOIN_P' AND q.status = 'pending'))
        FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '$1'"
}

PASS=0; FAIL=0
chk() {  # <id> <title> <want> <got>
  if [ "$3" = "$4" ]; then PASS=$((PASS + 1)); echo "PASS $1 $2"; echo "     got:  $4"
  else FAIL=$((FAIL + 1)); echo "FAIL $1 $2"; echo "     want: $3"; echo "     got:  $4"; fi
}

# The race: A cancels and holds its transaction 3 s; B joins 1 s in; a sampler reads B's wait 0.5 s after that.
race() {  # <game> -> prints B's token, B's elapsed seconds, B's wait sample
  local g=$1 tmp; tmp=$(mktemp -d)
  { as_user "$HOST_U" kan808_a; echo "BEGIN;"; echo "SELECT 'A cancel: ' || public.rpc_cancel_game('$g'::uuid, 'kan808');";
    echo "SELECT pg_sleep(3);"; echo "COMMIT;"; } | "${PSQL[@]}" -At -v ON_ERROR_STOP=1 > "$tmp/a.out" 2>&1 &
  local apid=$!
  sleep 1
  { as_user "$JOIN_U" kan808_b; echo '\set VERBOSITY verbose';
    echo "SELECT set_config('kan808.t0', clock_timestamp()::text, false) \\g /dev/null"; join_sql "$g";
    echo "SELECT 'elapsed=' || round(extract(epoch FROM clock_timestamp() - current_setting('kan808.t0')::timestamptz)::numeric, 1);"; } \
    | "${PSQL[@]}" -At > "$tmp/b.out" 2>&1 &
  local bpid=$!
  sleep 0.5
  S -c "SELECT coalesce(string_agg(format('B wait_event_type=%s wait_event=%s blocked_by_A=%s', a.wait_event_type, a.wait_event,
           EXISTS (SELECT 1 FROM pg_stat_activity x WHERE x.pid = ANY (pg_blocking_pids(a.pid)) AND x.application_name = 'kan808_a')), ';'), 'B not active')
        FROM pg_stat_activity a WHERE a.application_name = 'kan808_b'" > "$tmp/w.out"
  wait $bpid; wait $apid
  echo "$(norm < "$tmp/b.out")"
  grep -oE 'elapsed=[0-9.]+' "$tmp/b.out" | head -1
  cat "$tmp/w.out"
  grep -q '^A cancel: cancelled' "$tmp/a.out" || echo "A did not cancel: $(cat "$tmp/a.out")"
  rm -rf "$tmp"
}

echo "== KAN-808 on $DB: rpc_join_game md5(prosrc)=$(S -c "SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure")"

# R1 F1 open game
G=$(newgame open 10 true) || exit 2; OUT=$(race "$G"); TOK=$(sed -n 1p <<<"$OUT")
echo "-- R1 race detail: game=$G"; sed 's/^/     /' <<<"$OUT"; echo "     state: $(state "$G")"
WAITED=$(grep -c 'wait_event_type=Lock.*blocked_by_A=t' <<<"$OUT")
chk R1 "F1 open game: join racing an uncommitted cancel waits on A, then is refused cancelled; no roster row" \
  "wait=1 err:P0001:cancelled:cancelled | games.is_cancelled=t events.is_cancelled=t roster_b2=none pending_b2=0" \
  "wait=$WAITED $TOK | $(state "$G")"

# R2 F2 request game
G=$(newgame request 10 true) || exit 2; OUT=$(race "$G"); TOK=$(sed -n 1p <<<"$OUT")
echo "-- R2 race detail: game=$G"; sed 's/^/     /' <<<"$OUT"; echo "     state: $(state "$G")"
WAITED=$(grep -c 'wait_event_type=Lock.*blocked_by_A=t' <<<"$OUT")
chk R2 "F2 request game: request racing an uncommitted cancel waits on A, then is refused cancelled; no pending request" \
  "wait=1 err:P0001:cancelled:cancelled | games.is_cancelled=t events.is_cancelled=t roster_b2=none pending_b2=0" \
  "wait=$WAITED $TOK | $(state "$G")"

# E1/E2 join after the cancel committed
G=$(newgame open 10 true) || exit 2; cancel_now "$G"
chk E1 "join after the cancel committed (open): refused cancelled, no row" \
  "err:P0001:cancelled:cancelled | games.is_cancelled=t events.is_cancelled=t roster_b2=none pending_b2=0" "$(join_now "$JOIN_U" "$G") | $(state "$G")"
G=$(newgame request 10 true) || exit 2; cancel_now "$G"
chk E2 "join after the cancel committed (request): refused cancelled, no row" \
  "err:P0001:cancelled:cancelled | games.is_cancelled=t events.is_cancelled=t roster_b2=none pending_b2=0" "$(join_now "$JOIN_U" "$G") | $(state "$G")"

# E3/E4 live games
G=$(newgame open 10 true) || exit 2
chk E3 "live open game: joined" \
  "ret:joined|active|- | games.is_cancelled=f events.is_cancelled=f roster_b2=active pending_b2=0" "$(join_now "$JOIN_U" "$G") | $(state "$G")"
G=$(newgame request 10 true) || exit 2
chk E4 "live request game: request_submitted, one pending row" \
  "ret:request_submitted|-|- | games.is_cancelled=f events.is_cancelled=f roster_b2=none pending_b2=1" "$(join_now "$JOIN_U" "$G") | $(state "$G")"

# E5/E6 full games (capacity 2 = the events minimum, fillers a3 + a4 active) -> waitlist; E6 is O1
# (allows_waitlist = false still waitlists)
for W in true false; do
  G=$(newgame open 2 $W) || exit 2
  S -c "INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES ('$G', '$FILL_U', '$FILL_P', 'player', 'active'),
          ('$G', '$FILL2_U', '$FILL2_P', 'player', 'active')" >/dev/null || exit 2
  ID=E5; [ $W = false ] && ID=E6
  chk $ID "full game, allows_waitlist=$W: waitlisted at 1$([ $W = false ] && echo ' (O1 kept open)')" \
    "ret:waitlisted|-|1 | games.is_cancelled=f events.is_cancelled=f roster_b2=none pending_b2=0 waitlist_b2=1" \
    "$(join_now "$JOIN_U" "$G") | $(state "$G") waitlist_b2=$(S -c "SELECT count(*) FROM public.game_waitlist WHERE game_id = '$G' AND profile_id = '$JOIN_P'")"
done

echo "TOTAL pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
