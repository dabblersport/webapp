#!/usr/bin/env bash
# KAN-887 LOCAL PROOF. LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Proves 20261105110000_kan714_events_parent_reads_2.sql (release step 30) applies on top of
# 20261105120000_kan794_d04_on_live_bodies.sql (release step 25), and refuses without it (CTO ruling
# dreq-9e4edd4c). Part 2 pins rpc_create_game / rpc_create_meetup at the bodies step 25 leaves
# (md5(prosrc) 5b8883b2 / 0f5ba02e) and replaces them with those bodies plus only part 2's own delta (the
# request_id replay lookup reads public.kan714_games_read / kan714_meetups_read instead of public.games /
# public.meetups): post-image 1b3aa6f2 / f347168e.
#
# Base: the KAN-858 base (step-29 chain from tracked files via build_kan810.sh, plus the 7 baseline-only
# functions and B04's rpc_games_following_joined post-image; see kan858_part2_guard_test.sh, which this copies).
#   RED    k887_no794  base as is: rpc_create_* are the KAN-772 local post-images (e565a2ba / 77a14a22), i.e.
#                      step 25 NOT applied -> part 2's drift pin aborts on rpc_create_game, nothing left behind.
#   PRE    k887_ok     base + the production pre-image of the four step-25 functions (section P of
#                      kan794_d04_live_bodies_test.sql, verbatim), then step 25 applied; rpc_create_* now
#                      5b8883b2 / 0f5ba02e, and not yet the part 2 post-image (the GREEN probe fails here).
#   GREEN  k887_ok     part 2 applies (guard, pins, post-conditions incl. the KAN-887 md5 post-assert);
#                      rpc_create_* = 1b3aa6f2 / f347168e; 22 functions + 5 created objects captured.
# B03 is taken from fbae534e^ (as KAN-858) and B06 from cdc1810b^: KAN-881 (cdc1810b) re-pinned B06's
# rpc_meetup_card pre-image to the production comment-bearing body and made rpc_meetup_my absent-tolerant, which
# the local chain does not reproduce (the HEAD order check refuses on rpc_meetup_my). Both differ from HEAD only
# in pin/guard text; no function body differs.
# GREEN runs with check_function_bodies=off for the same reason as KAN-858 (nearby_games reads games.sport).
#
# Usage (from the repository root):
#   bash supabase/tests/events_p4/kan887_part2_after_kan794_test.sh /tmp/kan887_pg 55887
# The cluster, its fixtures and the exported source tree are removed on exit.
set -euo pipefail

DATADIR="${1:?usage: kan887_part2_after_kan794_test.sh <new-datadir> <port>}"
PORT="${2:?usage: kan887_part2_after_kan794_test.sh <new-datadir> <port>}"
case "$DATADIR" in /tmp/*|/private/tmp/*) ;; *) echo "datadir must be under /tmp" >&2; exit 1 ;; esac
case "$PORT" in 55461|55854) echo "port $PORT is reserved by another proof" >&2; exit 1 ;; esac

# Claim a private workspace atomically before registering cleanup. All generated
# files, including the cluster and its siblings, live inside this directory.
if [ -e "$DATADIR" ] || [ -L "$DATADIR" ]; then
  echo "datadir already exists; refusing" >&2; exit 1
fi
PARENT="$(dirname "$DATADIR")"
PHYSICAL_PARENT="$(cd "$PARENT" && pwd -P)"
case "$DATADIR" in /tmp/*) EXPECTED_PARENT="/private$(dirname "$DATADIR")" ;; *) EXPECTED_PARENT="$PARENT" ;; esac
[ "$PHYSICAL_PARENT" = "$EXPECTED_PARENT" ] || { echo "symlinked or noncanonical parent; refusing" >&2; exit 1; }
(umask 077; mkdir "$DATADIR") || { echo "cannot claim datadir; refusing" >&2; exit 1; }
WORK="$DATADIR"
WORK_ID="$(ls -di "$WORK" | awk '{print $1}')"
DATADIR="$WORK/cluster"
cleanup() {
  # Do not touch a replacement at the same pathname.
  [ ! -L "$WORK" ] && [ -d "$WORK" ] && [ "$(ls -di "$WORK" | awk '{print $1}')" = "$WORK_ID" ] || return 0
  if [ -f "$DATADIR/postmaster.pid" ] && [ ! -L "$DATADIR" ]; then
    if ! pg_ctl -D "$DATADIR" stop -m fast >/dev/null 2>&1; then
      echo "cleanup: could not stop cluster; preserving $WORK" >&2
      return 1
    fi
  fi
  rm -rf -- "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$WORK/src"
mkdir "$SRC"

M=supabase/migrations
PART2="$REPO/$M/20261105110000_kan714_events_parent_reads_2.sql"
K794="$REPO/$M/20261105120000_kan794_d04_on_live_bodies.sql"
K794T="$REPO/supabase/tests/events_p4/kan794_d04_live_bodies_test.sql"
B03=20261104100300_kan714_b03_views_rating_host_metrics.sql
B04=20261104100400_kan714_b04_rpc_nearby_following.sql
B06=20261104100600_kan714_b06_rpc_meetup_reads.sql
G='public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'
MT='public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)'

git -C "$REPO" archive HEAD supabase scripts | tar -x -C "$SRC"
git -C "$REPO" show "fbae534e^:$M/$B03" > "$SRC/$M/$B03"
git -C "$REPO" show "cdc1810b^:$M/$B06" > "$SRC/$M/$B06"
bash "$SRC/supabase/tests/events_p4/build_kan810.sh" "$DATADIR" "$PORT" > "$SRC/build.log" 2>&1 \
  || { tail -20 "$SRC/build.log"; exit 1; }

PSQL=(psql -X -q -h /tmp -p "$PORT" -U postgres)
mkdb() { createdb -h /tmp -p "$PORT" -U postgres -T "$2" "$1"; }
md5s() { "${PSQL[@]}" -d "$1" -tA -c "select string_agg(left(md5(prosrc), 8), ' / ' order by proname) from pg_proc
  where oid in ('$G'::regprocedure, '$MT'::regprocedure)"; }

# Fixture 1: the 7 baseline-only functions, verbatim (as KAN-858).
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
# Fixture 3: the production pre-image of step 25's four functions -- section P of the KAN-823 proof, verbatim
# (from its first CREATE OR REPLACE to its last GRANT, before the P assertions).
awk '/^-- P  production pre-image/{on=1; next} on&&/^INSERT INTO k823_r/{exit} on{print}' "$K794T" > "$SRC/pre794.sql"
grep -q 'GRANT EXECUTE ON FUNCTION public.rpc_create_meetup' "$SRC/pre794.sql" || { echo "fixture 3 cut failed"; exit 1; }

mkdb k887_base k810
"${PSQL[@]}" -v ON_ERROR_STOP=1 -d k887_base -f "$SRC/baseline7.sql"
"${PSQL[@]}" -v ON_ERROR_STOP=1 -d k887_base -f "$SRC/b04_fixture.sql"
mkdb k887_no794 k887_base; mkdb k887_ok k887_base

fail=0
# RED: step 25 not applied.
echo "RED   k887_no794 rpc_create_* before: $(md5s k887_no794)"
if out=$(PGOPTIONS='-c check_function_bodies=off' "${PSQL[@]}" -v ON_ERROR_STOP=1 -d k887_no794 -f "$PART2" 2>&1); then
  echo "FAIL RED: applied without step 25"; fail=1
elif grep -Eq "pin: public\.rpc_create_game\(.* body drifted \(md5 [0-9a-f]{32} expected 5b8883b2ab8b55f8d2119c6fbd023dcc\)" <<<"$out"; then
  echo "PASS RED: $(grep -m1 ERROR <<<"$out" | sed 's/(text,uuid[^)]*)/(26 args)/' | cut -c1-300)"
else echo "FAIL RED: wrong abort: $(grep -m1 ERROR <<<"$out" | cut -c1-300)"; fail=1; fi
[ "$("${PSQL[@]}" -d k887_no794 -tA -c "select to_regclass('public.kan714_preimage_2') is null")" = t ] \
  || { echo "FAIL RED: abort left kan714_preimage_2 behind"; fail=1; }

# PRE: production pre-image, then step 25.
"${PSQL[@]}" -v ON_ERROR_STOP=1 -d k887_ok -f "$SRC/pre794.sql"
echo "PRE   k887_ok rpc_create_* production pre-image: $(md5s k887_ok)"
if out=$("${PSQL[@]}" -v ON_ERROR_STOP=1 -d k887_ok -f "$K794" 2>&1); then echo "PASS PRE: step 25 applied"
else echo "FAIL PRE: step 25: $(grep -m1 ERROR <<<"$out" | cut -c1-300)"; fail=1; fi
pre=$(md5s k887_ok); echo "PRE   k887_ok rpc_create_* after step 25: $pre"
[ "$pre" = "5b8883b2 / 0f5ba02e" ] || { echo "FAIL PRE: step-25 post-image not 5b8883b2 / 0f5ba02e"; fail=1; }
[ "$pre" != "1b3aa6f2 / f347168e" ] && echo "PASS PRE: GREEN probe fails before part 2 (not yet 1b3aa6f2 / f347168e)" \
  || { echo "FAIL PRE: part 2 post-image already present"; fail=1; }

# GREEN: part 2.
if out=$(PGOPTIONS='-c check_function_bodies=off' "${PSQL[@]}" -v ON_ERROR_STOP=1 -d k887_ok -f "$PART2" 2>&1); then
  echo "PASS GREEN: part 2 applied; preimage_2 = $("${PSQL[@]}" -d k887_ok -tA -c \
    "select string_agg(kind||':'||n, ' ' order by kind) from (select kind, count(*) n from public.kan714_preimage_2 group by 1) s")"
else echo "FAIL GREEN: $(grep -m1 ERROR <<<"$out" | cut -c1-400)"; fail=1; fi
post=$(md5s k887_ok); echo "GREEN k887_ok rpc_create_* after part 2: $post"
[ "$post" = "1b3aa6f2 / f347168e" ] || { echo "FAIL GREEN: post-image not 1b3aa6f2 / f347168e"; fail=1; }
"${PSQL[@]}" -d k887_ok -tA -c "select object ~ 'rpc_create_game' as game, md5(substring(definition from 'AS \\\$function\\\$(.*)\\\$function\\\$')) from public.kan714_preimage_2
  where object like 'rpc_create_%' or object like 'public.rpc_create_%' order by 1 desc" | sed 's/^/GREEN preimage_2 row (game?|md5 prosrc): /'

[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
