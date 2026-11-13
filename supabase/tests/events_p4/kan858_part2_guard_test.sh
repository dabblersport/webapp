#!/usr/bin/env bash
# KAN-858 LOCAL PROOF. LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Proves 20261105110000_kan714_events_parent_reads_2.sql (re-authored under KAN-858) on a brand-new cluster
# built from TRACKED files only (git HEAD), through step 29 (supabase/tests/events_p4/build_kan810.sh):
#   RED-A  k858     step-29 chain as tracked: B04 is not applied there (build_kan788.sh runs B04 only on k788b),
#                   so the B01-B07/D04 guard must abort, naming B04.               (prerequisite ABSENT)
#   RED-B  k788b    base chain + B04 only: B01-B03 and B05-B07 absent -> guard aborts naming them. (ABSENT)
#   RED-C  k858_r   k858 + B04 post-image, then rpc_meetup_card's body altered by one comment line
#                   -> guard aborts naming B06.                                    (prerequisite ALTERED)
#   GREEN  k858_ok  k858 + B04 post-image -> the file applies; 22 functions + 5 created objects captured.
#   AGAIN  k858_ok  a second apply aborts ("already applied").
#   CHECK  k858_c   GREEN with check_function_bodies ON: the only failure is nearby_games (its baseline body
#                   reads games.sport, which the local harness games table does not have).
# GREEN runs with check_function_bodies=off for that reason only; CHECK shows it is the only reason.
#
# Two local-only fixtures, both cut verbatim from tracked files:
#   - the 7 functions present only in the baseline (20260829080500_baseline_schema.sql), which no step-29
#     harness creates (fn_game_roster_activity_sync, fn_meetup_rsvps_activity_sync, nearby_games,
#     rpc_autocomplete_entities, rpc_search_entities, trg_game_join_request_notify,
#     trg_game_waitlist_promoted_notify);
#   - B04's rpc_games_following_joined post-image (20261104100400_kan714_b04_rpc_nearby_following.sql, its
#     CREATE OR REPLACE statement), because B04's pre-images exist only on k788b's harness.
# B03 is taken from fbae534e^: fbae534e (KAN-853) pinned the production numeric(3,2) column signature, which
# the local harness does not reproduce, so HEAD's B03 refuses locally. The two versions differ only in that
# pin literal.
#
# Usage (from the repository root):
#   bash supabase/tests/events_p4/kan858_part2_guard_test.sh /tmp/kan858_pg 55871
# The cluster, its fixtures and the exported source tree are removed on exit.
set -euo pipefail

DATADIR="${1:?usage: kan858_part2_guard_test.sh <new-datadir> <port>}"
PORT="${2:?usage: kan858_part2_guard_test.sh <new-datadir> <port>}"
case "$DATADIR" in /tmp/*|/private/tmp/*) ;; *) echo "datadir must be under /tmp" >&2; exit 1 ;; esac
case "$PORT" in 55461|55854) echo "port $PORT is reserved by another proof" >&2; exit 1 ;; esac

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$(mktemp -d /private/tmp/kan858_src.XXXXXX)"
cleanup() {
  pg_ctl -D "$DATADIR" stop -m fast >/dev/null 2>&1 || true
  rm -rf "$DATADIR" "$DATADIR.log" "$DATADIR.fixtures" "$SRC"
}
trap cleanup EXIT

M=supabase/migrations
PART2="$REPO/$M/20261105110000_kan714_events_parent_reads_2.sql"
B03=20261104100300_kan714_b03_views_rating_host_metrics.sql
B04=20261104100400_kan714_b04_rpc_nearby_following.sql

git -C "$REPO" archive HEAD supabase scripts | tar -x -C "$SRC"
git -C "$REPO" show "fbae534e^:$M/$B03" > "$SRC/$M/$B03"
bash "$SRC/supabase/tests/events_p4/build_kan810.sh" "$DATADIR" "$PORT" > "$SRC/build.log" 2>&1 \
  || { tail -20 "$SRC/build.log"; exit 1; }

PSQL=(psql -X -q -h /tmp -p "$PORT" -U postgres)
mkdb() { createdb -h /tmp -p "$PORT" -U postgres -T "$2" "$1"; }

# Fixture 1: the 7 baseline-only functions, verbatim.
perl -e '
  my $file = shift; my %want = map { $_ => 1 } @ARGV; my ($on, $tag) = (0, undef);
  open my $fh, "<", $file or die; print "SET check_function_bodies = off;\n";
  while (my $l = <$fh>) {
    if (!$on && $l =~ /^CREATE OR REPLACE FUNCTION "public"\."(\w+)"\(/ && $want{$1}) { $on = 1; $tag = undef; }
    next unless $on; print $l;
    if (!defined $tag && $l =~ /AS (\$\w*\$)/) { $tag = $1; $on = 0 if $'"'"' =~ /\Q$tag\E/; next; }
    $on = 0 if defined $tag && $l =~ /\Q$tag\E/;
  }' "$SRC/$M/20260829080500_baseline_schema.sql" fn_game_roster_activity_sync fn_meetup_rsvps_activity_sync \
  nearby_games rpc_autocomplete_entities rpc_search_entities trg_game_join_request_notify \
  trg_game_waitlist_promoted_notify > "$SRC/baseline7.sql"
# Fixture 2: B04's rpc_games_following_joined post-image, verbatim.
awk '/^CREATE OR REPLACE FUNCTION public.rpc_games_following_joined\(/{on=1} on{print} on&&/^\$function\$;/{exit}' \
  "$SRC/$M/$B04" > "$SRC/b04_fixture.sql"

mkdb k858 k810
"${PSQL[@]}" -v ON_ERROR_STOP=1 -d k858 -f "$SRC/baseline7.sql"

fail=0
expect_abort() {  # db, label, pattern
  local out
  if out=$("${PSQL[@]}" -v ON_ERROR_STOP=1 -d "$1" -f "$PART2" 2>&1); then
    echo "FAIL $2: applied, expected abort"; fail=1; return
  fi
  if grep -Eq "$3" <<<"$out"; then echo "PASS $2: $(grep -m1 ERROR <<<"$out" | cut -c1-400)"
  else echo "FAIL $2: wrong abort: $(grep -m1 ERROR <<<"$out")"; fail=1; fi
  if [ "$("${PSQL[@]}" -d "$1" -tA -c "select to_regclass('public.kan714_preimage_2') is null")" != t ]; then
    echo "FAIL $2: abort left kan714_preimage_2 behind"; fail=1; fi
}

expect_abort k858  RED-A 'prereq: .*B04 public\.rpc_games_following_joined'
expect_abort k788b RED-B 'prereq: .*B01 .*B02 .*B03 .*B05 .*B06 .*B07 '

"${PSQL[@]}" -v ON_ERROR_STOP=1 -d k858 -f "$SRC/b04_fixture.sql"
mkdb k858_r k858; mkdb k858_ok k858; mkdb k858_c k858
"${PSQL[@]}" -v ON_ERROR_STOP=1 -d k858_r -c "DO \$x\$ BEGIN EXECUTE regexp_replace(
  pg_get_functiondef('public.rpc_meetup_card(uuid,text)'::regprocedure), 'AS \\\$function\\\$',
  E'AS \$function\$\n-- KAN-858 RED-C: altered body'); END \$x\$;"
expect_abort k858_r RED-C 'not in place: B06 public\.rpc_meetup_card\(uuid,text\) \(md5 [0-9a-f]{32} expected c63da3ea'

if out=$(PGOPTIONS='-c check_function_bodies=off' "${PSQL[@]}" -v ON_ERROR_STOP=1 -d k858_ok -f "$PART2" 2>&1); then
  echo "PASS GREEN: applied; preimage_2 = $("${PSQL[@]}" -d k858_ok -tA -c \
    "select string_agg(kind||':'||n, ' ' order by kind) from (select kind, count(*) n from public.kan714_preimage_2 group by 1) s")"
else echo "FAIL GREEN: $(grep -m1 ERROR <<<"$out")"; fail=1; fi
if out=$("${PSQL[@]}" -v ON_ERROR_STOP=1 -d k858_ok -f "$PART2" 2>&1); then echo "FAIL AGAIN: re-applied"; fail=1
elif grep -q 'already applied' <<<"$out"; then echo "PASS AGAIN: $(grep -m1 ERROR <<<"$out")"
else echo "FAIL AGAIN: $(grep -m1 ERROR <<<"$out")"; fail=1; fi

out=$("${PSQL[@]}" -v ON_ERROR_STOP=1 -d k858_c -f "$PART2" 2>&1) && { echo "CHECK: applied with bodies checked"; } || \
  echo "CHECK (check_function_bodies on): $(grep -m1 ERROR <<<"$out") at $(grep -m1 -o 'new[^ ]*\|reads_2.sql:[0-9]*' <<<"$out")"

[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
