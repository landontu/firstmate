#!/usr/bin/env bash
# tests/fm-state-prune.test.sh - bin/fm-state-prune.sh removes watcher/daemon
# marker litter only for ids with no state/<id>.meta and no pending wake-queue
# entry, is idempotent, and never touches live tasks.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-state-prune)
PRUNE="$ROOT/bin/fm-state-prune.sh"

markers_for() {  # <state> <id> <session>
  local st=$1 id=$2 ses=$3 f
  for f in ".hash-${ses}_fm-$id" ".count-${ses}_fm-$id" ".stale-${ses}_fm-$id" ".stale-since-${ses}_fm-$id" \
           ".seen-${id}_status" ".seen-${id}_turn-ended" ".hb-surfaced-$id" \
           ".subsuper-seen-status-$id" ".subsuper-stale-$id"; do
    echo x > "$st/$f"
  done
}

count_for() {  # <state> <id>
  find "$1" -maxdepth 1 -name ".*" -type f \( -name "*_fm-$2" -o -name "*-$2" -o -name ".seen-$2_*" \) | wc -l | tr -d ' '
}

test_sweep_prunes_only_orphans() {
  local st="$TMP_ROOT/sweep/state" out
  mkdir -p "$st"
  markers_for "$st" gone-a1 firstmate
  markers_for "$st" gone-b2 0
  markers_for "$st" live-c3 firstmate
  markers_for "$st" queued-d4 firstmate
  markers_for "$st" site firstmate
  markers_for "$st" site-cards firstmate
  echo "pid=1" > "$st/live-c3.meta"
  echo "pid=1" > "$st/site.meta"
  printf '1700000000\t1\tstale\tfirstmate:fm-queued-d4\tstale: firstmate:fm-queued-d4\n' > "$st/.wake-queue"
  echo keep > "$st/.last-heartbeat"; echo keep > "$st/.watch.lock"; echo keep > "$st/.afk"

  FM_STATE_OVERRIDE="$st" "$PRUNE" --dry-run >/dev/null || fail "dry-run failed"
  [ "$(count_for "$st" gone-a1)" = 9 ] || fail "dry-run removed files"

  out=$(FM_STATE_OVERRIDE="$st" "$PRUNE") || fail "prune failed"
  [ "$(count_for "$st" gone-a1)" = 0 ] || fail "orphan gone-a1 markers survived"
  [ "$(count_for "$st" gone-b2)" = 0 ] || fail "orphan gone-b2 (other session) markers survived"
  [ "$(count_for "$st" live-c3)" = 9 ] || fail "live task markers were touched"
  [ "$(count_for "$st" queued-d4)" = 9 ] || fail "markers of an id with a pending wake were removed"
  [ "$(count_for "$st" site)" = 9 ] || fail "live task 'site' markers were touched"
  [ "$(count_for "$st" site-cards)" = 0 ] || fail "orphan 'site-cards' kept because of live prefix id 'site'"
  [ -e "$st/.last-heartbeat" ] && [ -e "$st/.watch.lock" ] && [ -e "$st/.afk" ] || fail "non-task state files were touched"
  [ -e "$st/live-c3.meta" ] || fail "meta removed"
  assert_contains "$out" "removed 27" "unexpected summary: $out"

  out=$(FM_STATE_OVERRIDE="$st" "$PRUNE") || fail "second prune failed"
  assert_contains "$out" "removed 0" "prune is not idempotent: $out"
  pass "fm-state-prune: sweep removes only orphan markers, keeps live/queued/non-task files, idempotent"
}

test_id_mode() {
  local st="$TMP_ROOT/idmode/state" rc
  mkdir -p "$st"
  markers_for "$st" one-a1 firstmate
  markers_for "$st" two-b2 firstmate
  FM_STATE_OVERRIDE="$st" "$PRUNE" --id one-a1 >/dev/null || fail "--id prune failed"
  [ "$(count_for "$st" one-a1)" = 0 ] || fail "--id left markers"
  [ "$(count_for "$st" two-b2)" = 9 ] || fail "--id touched another task"
  echo m > "$st/two-b2.meta"
  FM_STATE_OVERRIDE="$st" "$PRUNE" --id two-b2 >/dev/null 2>&1 && rc=0 || rc=$?
  [ "$rc" -ne 0 ] || fail "--id pruned a live task"
  [ "$(count_for "$st" two-b2)" = 9 ] || fail "--id removed a live task's markers"
  FM_STATE_OVERRIDE="$st" "$PRUNE" --bogus >/dev/null 2>&1 && fail "bad flag accepted"
  pass "fm-state-prune: --id removes one task's markers and refuses a live task"
}

test_sweep_prunes_only_orphans
test_id_mode
