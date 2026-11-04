#!/usr/bin/env bash
# KAN-791: smoke test of the running local stack. The committed test of scripts/local_stack.
#   bash scripts/local_stack/start.sh && bash scripts/local_stack/smoke.sh
# Prints PASS / FAIL / NOT RUN per item and exits non-zero if any item FAILs.
#   (a) PostgREST returns a row from a public events view (v_game_card) as anon.
#   (b) GoTrue signs up a fixture user and returns a JWT; PostgREST accepts it and auth.uid() resolves to
#       that user's id (local_stack.whoami()); and the user row is in the same cluster's auth.users.
#       Negative control first: a JWT signed with a WRONG secret must be rejected (401).
#   (c) Realtime delivers one postgres_changes INSERT event for a row inserted into public.meetups
#       (in the supabase_realtime publication, KAN-716). The fixture row is deleted afterwards.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
[ -f "$STATE" ] || die "no running stack ($STATE missing); run start.sh first"
# shellcheck disable=SC1090
. "$STATE"
PSQL=("$PG_BIN/psql" -X -q -At -v ON_ERROR_STOP=1 -h "$PG_SOCK" -p "$PG_PORT" -U postgres -d "$PG_DB")
RESULT_A="NOT RUN"; RESULT_B="NOT RUN"; RESULT_C="NOT RUN"

echo "=== (a) PostgREST: anon reads a public events view"
OUT="$(curl -sS -w '\nHTTP %{http_code}' "$POSTGREST_URL/v_game_card?select=id,title,start_at,listing_visibility&limit=1" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY")"
echo "GET /v_game_card?limit=1 (anon) ->"; echo "$OUT"
if [ "$(echo "$OUT" | tail -1)" = "HTTP 200" ] && echo "$OUT" | sed '$d' | grep -q '"id"'; then
  RESULT_A=PASS
else
  RESULT_A=FAIL
fi
echo "(a) $RESULT_A"

echo; echo "=== (b) GoTrue signup -> JWT -> PostgREST -> auth.uid()"
BAD_JWT="$(make_jwt "not-the-stack-secret-$(date +%s)" '{"role":"authenticated","sub":"00000000-0000-0000-0000-00000000dead"}')"
NEG="$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$POSTGREST_URL/rpc/whoami" -H "Content-Profile: local_stack" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $BAD_JWT" -d '{}')"
echo "negative control: whoami with a JWT signed by a wrong secret -> HTTP $NEG (must be 401)"
EMAIL="kan791-smoke-$(date +%s)-$$@example.test"
SIGNUP="$(curl -sS -X POST "$GOTRUE_URL/signup" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"kan791-Smoke-pw-1\"}")"
USER_ID="$(printf '%s' "$SIGNUP" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(d.get("user",{}).get("id",""))' 2>/dev/null)"
TOKEN="$(printf '%s' "$SIGNUP" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)"
echo "POST /signup $EMAIL -> user.id=$USER_ID access_token=${TOKEN:0:24}...(${#TOKEN} chars)"
if [ -n "$TOKEN" ]; then
  echo "JWT payload: $(printf '%s' "$TOKEN" | python3 -I -c '
import base64,json,sys; p=sys.stdin.read().split(".")[1]; p+="="*(-len(p)%4)
d=json.loads(base64.urlsafe_b64decode(p)); print(json.dumps({k:d.get(k) for k in ("sub","role","aud","email","iss")}))')"
fi
WHO="$(curl -sS -w '\nHTTP %{http_code}' -X POST "$POSTGREST_URL/rpc/whoami" -H "Content-Profile: local_stack" \
  -H "Content-Type: application/json" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -d '{}')"
echo "POST /rpc/whoami (Content-Profile: local_stack, user JWT) ->"; echo "$WHO"
WHO_UID="$(echo "$WHO" | sed '$d' | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("uid") or "")' 2>/dev/null)"
IN_AUTH="$("${PSQL[@]}" -c "SELECT count(*) FROM auth.users WHERE id = '${USER_ID:-00000000-0000-0000-0000-000000000000}'")"
echo "auth.users rows with that id in the stack cluster: $IN_AUTH"
if [ "$NEG" = 401 ] && [ -n "$USER_ID" ] && [ -n "$TOKEN" ] && [ "$WHO_UID" = "$USER_ID" ] && [ "$IN_AUTH" = 1 ]; then
  RESULT_B=PASS
else
  RESULT_B=FAIL
fi
echo "(b) $RESULT_B"

echo; echo "=== (c) Realtime: one postgres_changes INSERT event on public.meetups"
if [ "$REALTIME_STATUS" != "RUNNING" ]; then
  echo "Realtime is not running in this stack: ${REALTIME_NOTE:-no reason recorded}"
  RESULT_C="NOT RUN"
else
  FIX_ID="79100000-0000-0000-0000-$(printf '%012d' "$(( $(date +%s) % 1000000000000 ))")"
  INSERT_SQL="INSERT INTO public.meetups (id, title, description, creator_profile_id, creator_user_id, host_actor_id,
      start_at, end_at, listing_visibility, rsvp_policy, sport_id, geo_location_id, area_id, min_skill, max_skill,
      capacity, is_cancelled, location_name, is_indoor)
    VALUES ('$FIX_ID', 'KAN-791 realtime smoke', 'kan791 smoke', '00000000-0000-0000-0000-0000000000b1',
      '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
      date_trunc('minute', now()) + interval '2 hours', date_trunc('minute', now()) + interval '3 hours', 'public', 'open',
      '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
      1, 10, 10, false, 'KAN-791 Hall', true)"
  WS_URL="ws://$REALTIME_TENANT.localhost:${REALTIME_URL##*:}/socket/websocket?apikey=$SERVICE_KEY&vsn=1.0.0"
  PSQL_CMD="$(printf '%q ' "${PSQL[@]}")"
  RT_OUT="$(INSERT_SQL="$INSERT_SQL" WS_URL="$WS_URL" KEY="$SERVICE_KEY" FIX_ID="$FIX_ID" PSQL_CMD="$PSQL_CMD" \
    node -e '
const { execSync } = require("child_process");
const ws = new WebSocket(process.env.WS_URL);
const log = (m) => console.log(new Date().toISOString().slice(11, 23), m);
let inserted = false, done = false;
const finish = (code, m) => { if (done) return; done = true; log(m); try { ws.close(); } catch (e) {} process.exit(code); };
setTimeout(() => finish(2, "TIMEOUT: no change event within 30s"), 30000);
ws.onopen = () => {
  log("socket open; joining realtime:kan791 with postgres_changes INSERT public.meetups");
  ws.send(JSON.stringify({ topic: "realtime:kan791", event: "phx_join", ref: "1", payload: {
    config: { broadcast: { self: false }, presence: { key: "" },
              postgres_changes: [{ event: "INSERT", schema: "public", table: "meetups" }] },
    access_token: process.env.KEY } }));
  setInterval(() => ws.send(JSON.stringify({ topic: "phoenix", event: "heartbeat", payload: {}, ref: "hb" })), 10000);
};
ws.onerror = (e) => finish(3, "socket error: " + (e.message || e.type));
ws.onmessage = (msg) => {
  const m = JSON.parse(msg.data);
  if (m.event === "phx_reply" && m.ref === "1") log("join reply: " + JSON.stringify(m.payload).slice(0, 300));
  if (m.event === "system") log("system: " + JSON.stringify(m.payload));
  if (m.event === "system" && m.payload.extension === "postgres_changes" && m.payload.status === "ok" && !inserted) {
    inserted = true;
    log("subscribed; inserting fixture meetup " + process.env.FIX_ID);
    execSync(process.env.PSQL_CMD + " -c \"$INSERT_SQL\"", { stdio: "inherit", shell: "/bin/bash" });
  }
  if (m.event === "system" && m.payload.status === "error") finish(4, "subscription error");
  if (m.event === "postgres_changes") {
    const d = m.payload.data || {};
    log("postgres_changes: " + JSON.stringify({ type: d.type, schema: d.schema, table: d.table,
      commit_timestamp: d.commit_timestamp, record_id: d.record && d.record.id, record_title: d.record && d.record.title }));
    if (d.type === "INSERT" && d.record && d.record.id === process.env.FIX_ID) finish(0, "DELIVERED");
  }
};' 2>&1)"
  RC=$?
  echo "$RT_OUT"
  "${PSQL[@]}" -c "DELETE FROM public.meetups WHERE id = '$FIX_ID'" >/dev/null 2>&1 \
    && echo "fixture meetup $FIX_ID deleted" || echo "note: fixture meetup $FIX_ID could not be deleted"
  if [ "$RC" = 0 ]; then RESULT_C=PASS; else RESULT_C=FAIL; fi
fi
echo "(c) $RESULT_C"

echo; echo "=== SUMMARY"
echo "(a) PostgREST anon read of public.v_game_card : $RESULT_A"
echo "(b) GoTrue JWT -> PostgREST -> auth.uid()      : $RESULT_B"
echo "(c) Realtime postgres_changes INSERT delivered : $RESULT_C"
case "$RESULT_A$RESULT_B$RESULT_C" in *FAIL*) exit 1;; esac
exit 0
