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

scaffold_kind() {  # <home> <kind> <id>
  if [ "$2" = scout ]; then
    FM_HOME="$1" "$ROOT/bin/fm-brief.sh" "$3" nm-app --scout >/dev/null || fail "$2 scaffold failed"
  else
    FM_HOME="$1" "$ROOT/bin/fm-brief.sh" "$3" nm-app >/dev/null || fail "$2 scaffold failed"
  fi
}

test_install_rule_and_local_rules() {
  local home kind brief next
  home="$TMP_ROOT/install"
  mkdir -p "$home/data"
  printf -- '- nm-app [no-mistakes] - t (added 2026-10-20)\n' > "$home/data/projects.md"
  for kind in ship scout; do
    scaffold_kind "$home" "$kind" "inst-$kind"
    brief="$home/data/inst-$kind/brief.md"
    assert_grep '8. Install nothing globally or system-wide without explicit per-install approval' "$brief" \
      "$kind brief is missing the no-global-installs rule"
    assert_grep 'project-local dependencies in the worktree are fine' "$brief" "$kind install rule lacks the local-deps carve-out"
    assert_no_grep 'LOCALRULE' "$brief" "$kind brief has local rules without a config file"
  done
  mkdir -p "$home/config"
  printf '9. LOCALRULE keep it terse.\n' > "$home/config/brief-rules.md"
  for kind in ship scout; do
    scaffold_kind "$home" "$kind" "loc-$kind"
    brief="$home/data/loc-$kind/brief.md"
    next=$(grep -A1 '^8. Install nothing globally' "$brief" | tail -1)
    [ "$next" = '9. LOCALRULE keep it terse.' ] || fail "$kind local rules do not directly follow the install rule (got: $next)"
  done
  FM_HOME="$home" FM_SECONDMATE_CHARTER='ops' "$ROOT/bin/fm-brief.sh" loc-sm --secondmate app >/dev/null || fail "charter scaffold failed"
  assert_no_grep 'LOCALRULE' "$home/data/loc-sm/brief.md" "secondmate charter must not carry local brief rules"
  pass "fm-brief: install rule in ship+scout; config/brief-rules.md appended when present, absent = no change"
}

test_rejects_dash_task_id() {
  local home out rc id
  home="$TMP_ROOT/dash"
  mkdir -p "$home/data"
  for id in --help -x; do
    out=$(FM_HOME="$home" "$ROOT/bin/fm-brief.sh" "$id" app 2>&1) && rc=0 || rc=$?
    [ "$rc" -ne 0 ] || fail "fm-brief.sh accepted task id $id"
    assert_contains "$out" "usage: fm-brief.sh" "no usage printed for task id $id"
  done
  out=$(FM_HOME="$home" "$ROOT/bin/fm-brief.sh" 2>&1) && rc=0 || rc=$?
  [ "$rc" -ne 0 ] || fail "fm-brief.sh accepted no task id"
  { [ ! -e "$home/data/--help" ] && [ ! -e "$home/data/-x" ]; } || fail "junk data dir created for dash-prefixed id"
  pass "fm-brief: dash-prefixed or missing task id prints usage and creates nothing"
}

test_ship_briefs_carry_cleanup_rule
test_scout_brief_carries_cleanup_rule
test_secondmate_charter_omits_cleanup_rule
test_install_rule_and_local_rules
test_rejects_dash_task_id
