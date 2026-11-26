#!/usr/bin/env bash
# Remove per-task watcher/daemon marker files from state/ for tasks that are gone.
# Usage: fm-state-prune.sh [--id <task-id>] [--dry-run]
#   (no args)   sweep: remove markers for every id with no state/<id>.meta and no
#               pending entry in the wake queue. Idempotent; live tasks are never touched.
#   --id <id>   remove exactly that task's markers (used by fm-teardown.sh after the
#               task's meta is gone); refuses while state/<id>.meta still exists.
#   --dry-run   print what would be removed, remove nothing.
# Marker families (see fm-watch.sh / fm-supervise-daemon.sh):
#   .hash-/.count-/.stale-/.stale-since-<session>_fm-<id>   pane staleness tracking
#   .seen-<id>_status, .seen-<id>_turn-ended                  signal signatures
#   .hb-surfaced-<id>                                         heartbeat surfaced status
#   .subsuper-seen-status-<id>, .subsuper-stale-<id>          away-mode daemon dedup
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
QUEUE="${FM_WAKE_QUEUE:-$STATE/.wake-queue}"

ONLY=""
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --id) [ $# -ge 2 ] || { echo "error: --id needs a task id" >&2; exit 2; }; ONLY=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "usage: fm-state-prune.sh [--id <task-id>] [--dry-run]" >&2; exit 2 ;;
  esac
done
case "$ONLY" in -*) echo "error: task id must not start with '-'" >&2; exit 2 ;; esac
[ -d "$STATE" ] || exit 0

# marker_id <basename>: print the task id a marker belongs to, or nothing.
marker_id() {
  local b=$1 key
  case "$b" in
    .stale-since-*) key=${b#.stale-since-} ;;
    .hash-*) key=${b#.hash-} ;;
    .count-*) key=${b#.count-} ;;
    .stale-*) key=${b#.stale-} ;;
    .seen-*)
      key=${b#.seen-}
      case "$key" in
        *_status) printf '%s' "${key%_status}" ;;
        *_turn-ended) printf '%s' "${key%_turn-ended}" ;;
      esac
      return 0 ;;
    .hb-surfaced-*) printf '%s' "${b#.hb-surfaced-}"; return 0 ;;
    .subsuper-seen-status-*) printf '%s' "${b#.subsuper-seen-status-}"; return 0 ;;
    .subsuper-stale-*) printf '%s' "${b#.subsuper-stale-}"; return 0 ;;
    *) return 0 ;;
  esac
  # pane keys are <session>_fm-<id>; anything else is not a task window marker.
  case "$key" in *_fm-*) printf '%s' "${key##*_fm-}" ;; esac
}

# queue_mentions <id>: conservative - any pending wake record naming the id as a
# whole token (fm-<id>, <id>.status, ...) counts, so a stray hit only keeps markers.
queue_mentions() {
  [ -s "$QUEUE" ] || return 1
  local esc
  esc=$(printf '%s' "$1" | sed 's/[][\.*^$/+?(){}|]/\\&/g')
  grep -Eq "(^|[^A-Za-z0-9_-])(fm-)?${esc}([^A-Za-z0-9_-]|\$)" "$QUEUE" 2>/dev/null
}

removed=0
for f in "$STATE"/.hash-* "$STATE"/.count-* "$STATE"/.stale-* "$STATE"/.seen-* \
         "$STATE"/.hb-surfaced-* "$STATE"/.subsuper-seen-status-* "$STATE"/.subsuper-stale-*; do
  [ -e "$f" ] || continue
  id=$(marker_id "$(basename "$f")")
  [ -n "$id" ] || continue
  if [ -n "$ONLY" ]; then
    [ "$id" = "$ONLY" ] || continue
    [ ! -e "$STATE/$ONLY.meta" ] || { echo "error: $ONLY is live (state/$ONLY.meta exists)" >&2; exit 1; }
  else
    [ ! -e "$STATE/$id.meta" ] || continue
    queue_mentions "$id" && continue
  fi
  if [ "$DRY" = 1 ]; then echo "would remove $f"; else rm -f "$f"; fi
  removed=$((removed + 1))
done
echo "state-prune: $([ "$DRY" = 1 ] && echo would-remove || echo removed) $removed marker file(s)"
