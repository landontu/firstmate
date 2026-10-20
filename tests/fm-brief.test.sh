#!/usr/bin/env bash
# tests/fm-brief.test.sh - fm-brief.sh scaffold contract: every crewmate brief
# kind (ship in each delivery mode, and scout) carries the local-server cleanup
# rule; the secondmate charter, which only delegates, does not.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-brief)

CLEANUP='Track every local server, port, or background process you start'
CLEANUP_EXCEPTION='a server backing an active human review stays up until that review ends'

assert_cleanup_rule() {
  local brief=$1 label=$2
  assert_present "$brief" "$label brief was not scaffolded"
  assert_grep "7. $CLEANUP" "$brief" "$label brief is missing the cleanup rule as rule 7"
  assert_grep "always before appending done/blocked/failed" "$brief" \
    "$label brief cleanup rule lacks the before-terminal-status deadline"
  assert_grep "$CLEANUP_EXCEPTION" "$brief" "$label brief cleanup rule lacks the review exception"
  assert_grep "lavish-axi" "$brief" "$label brief cleanup rule lacks the self-managed-server exception"
}

test_ship_briefs_carry_cleanup_rule() {
  local home mode
  home="$TMP_ROOT/ship"
  mkdir -p "$home/data"
  cat > "$home/data/projects.md" <<'REG'
- nm-app [no-mistakes] - test app (added 2026-10-20)
- dp-app [direct-PR] - test app (added 2026-10-20)
- lo-app [local-only] - test app (added 2026-10-20)
REG
  for mode in nm dp lo; do
    FM_HOME="$home" "$ROOT/bin/fm-brief.sh" "brief-$mode" "$mode-app" >/dev/null \
      || fail "ship brief scaffold failed for $mode-app"
    assert_cleanup_rule "$home/data/brief-$mode/brief.md" "ship ($mode-app)"
  done
  pass "fm-brief: ship briefs carry the cleanup rule in every delivery mode"
}

test_scout_brief_carries_cleanup_rule() {
  local home
  home="$TMP_ROOT/scout"
  mkdir -p "$home/data"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" brief-scout app --scout >/dev/null 2>&1 \
    || fail "scout brief scaffold failed"
  assert_cleanup_rule "$home/data/brief-scout/brief.md" "scout"
  pass "fm-brief: scout brief carries the cleanup rule"
}

test_secondmate_charter_omits_cleanup_rule() {
  local home brief
  home="$TMP_ROOT/secondmate"
  mkdir -p "$home/data"
  FM_HOME="$home" FM_SECONDMATE_CHARTER='ops domain' "$ROOT/bin/fm-brief.sh" brief-sm --secondmate app >/dev/null \
    || fail "secondmate charter scaffold failed"
  brief="$home/data/brief-sm/brief.md"
  assert_present "$brief" "secondmate charter was not scaffolded"
  assert_no_grep "$CLEANUP" "$brief" "secondmate charter must not carry the crewmate cleanup rule"
  pass "fm-brief: secondmate charter omits the crewmate cleanup rule"
}

test_ship_briefs_carry_cleanup_rule
test_scout_brief_carries_cleanup_rule
test_secondmate_charter_omits_cleanup_rule
