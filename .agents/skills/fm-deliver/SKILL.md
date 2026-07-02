---
name: fm-deliver
description: Agent-only reference for firstmate delivery stages. Load when a ship task reports done, reaches validate / PR-ready / merge / teardown, when a scout report lands, when promoting a scout to ship, or when a teardown refuses. Owns per-mode delivery mechanics (no-mistakes, direct-PR, local-only), yolo approval rules, the validate wrapper, PR-ready and merge helpers, the full landed-work definition, the sanctioned-write exception catalog, and secondmate teardown.
user-invocable: false
---

# fm-deliver

A ship task's path from `done` to landed on `main` is set by the project's `mode` (recorded in meta; fm-project-setup); `yolo` decides who approves. The Validate / PR ready / Ship teardown stages below are written for the `no-mistakes` path; the other modes diverge:

- **no-mistakes** - the stages below as written: no-mistakes validation pipeline -> PR -> captain merge.
- **direct-PR** - no pipeline. The crewmate pushes and opens the PR itself (its brief says so) and reports `done: PR <url>`. Skip the Validate step and go straight to PR ready (run `fm-pr-check`, relay the PR). Teardown uses the normal landed-work check.
- **local-only** - no remote, no PR. The crewmate stops at `done: ready in branch fm/<id>`. Review the diff with `bin/fm-review-diff.sh <id>`, relay a one-paragraph summary to the captain, and on approval run `bin/fm-merge-local.sh <id>` to fast-forward local `main` (it refuses anything but a clean fast-forward - if it does, have the crewmate rebase). No `fm-pr-check`. Then teardown, whose safety check requires the branch already merged into local `main`, OR the work pushed to any remote (a fork counts - relevant for upstream-contribution PRs on a local-only-registered project).

When reviewing any crewmate branch diff, use `bin/fm-review-diff.sh <id>` rather than `git diff <default>...branch` directly.
Pooled clones keep their local default refs frozen at clone time and can lag `origin`; the helper always compares against the authoritative base.

**yolo (orthogonal).** With `yolo=off` (default) every approval is the captain's: ask-user findings, PR merges, the local-only merge.
With `yolo=on`, firstmate makes those calls itself without asking - resolve ask-user findings on your judgment, and run `bin/fm-pr-merge.sh <id> <full GitHub PR URL>` / `bin/fm-merge-local.sh` once the work is green/approved - EXCEPT anything destructive, irreversible, or security-sensitive, which still escalates to the captain.
Never merge a red PR even under yolo.
`bin/fm-pr-merge.sh` always records `pr=` and records `pr_head=` when available before merging, parses the full `https://github.com/<owner>/<repo>/pull/<n>` URL into `gh-axi pr merge <n> --repo <owner>/<repo>`, and defaults to `--squash` unless an explicit merge method is forwarded after `--`; this holds even on a repo with no PR CI where the "checks green" signal that normally triggers `bin/fm-pr-check.sh` never fires - do not call `gh-axi pr merge` directly for a task's PR, or the recording step can be silently skipped and a later `fm-teardown.sh` has nothing to verify a squash merge against.
After any merge you perform without asking the captain, post a one-line "merged <full PR URL or local main> after checks passed" FYI so the captain keeps a trail.

## Validate

For `no-mistakes`-mode ship tasks, when a crewmate's status says `done`, trigger validation using the crew's harness from `state/<id>.meta`.
Load `harness-adapters` for the target harness's skill invocation form; natural language also works if uncertain.

The crewmate drives the no-mistakes pipeline (review, test, document, lint, push, PR, CI) itself.
The ship brief intentionally does not restate no-mistakes gate mechanics; it points the crewmate to the version-matched SKILL.md loaded by `/no-mistakes`, `no-mistakes axi run --help`, and per-response `help` lines.
Firstmate's wrapper stays narrow: `ask-user` findings return through `needs-decision`, captain-owned decisions go back through `no-mistakes axi respond`, crewmate validation avoids `--yes`, and CI-green completion is reported as `done: PR {url} checks green`.
Use chat for yes/no decisions; use lavish-axi when there are multiple findings or options to triage.

Judge a validating crewmate by the run's step status, never by whether its shell is still running.
Read its current state with `bin/fm-crew-state.sh <id>`: a deterministic, token-tight one-line read that takes the matching no-mistakes run-step as the source of truth and reconciles it against the crewmate's `state/<id>.status` log.
Because the run-step is authoritative before pane liveness, a crewmate whose window closed after or during validation can still report `done` or `working` from its run; a missing pane becomes `unknown` only when no matching run exists.
That log is an append-only wake-*event* log, not a current-state field, and it goes stale the moment a resolved gate lets the run resume: after you answer a `needs-decision`/`blocked` and the crewmate silently resumes (responds to the gate, the pipeline fixes, it re-validates), the log's last line still reads `needs-decision`/`blocked` while the run-step has moved on.
So never infer current state from a `tail` of that log; `bin/fm-crew-state.sh` reports the live run-step state and explicitly flags the stale log line superseded, where a raw `tail` would mislead you into re-escalating settled work.
The fields below name the run-step states and outcomes it reads from `no-mistakes axi status`; run that command directly when you want the full gate findings.

- `running`/`fixing`/`ci` - the pipeline is working (a fix round, a test, or CI monitoring); these run for many minutes and quiet is normal, so leave it alone.
- `awaiting_approval`/`fix_review` - the run is parked waiting on the agent, surfaced as a top-level `awaiting_agent: parked <duration>` line right after `status:` in `axi status`.
  The crewmate owes a response; if it is idle-waiting for the run to advance on its own, steer it to follow no-mistakes' active-gate help.
- `outcome: passed` or `checks-passed` - the helper reports `done`; `passed` means the PR is already merged or closed, while `checks-passed` means it is ready for PR review.
- `outcome: failed` or `cancelled` - the helper reports `failed`; inspect the run details and recover or report failure with evidence.
- Red flag - self-fix duplication: a validating crewmate making fresh hand-commits, aborting the run, or re-running it mid-validation is re-doing work the pipeline already owns.
  Steer it back to no-mistakes' respond flow; the pipeline, not the crewmate, applies validation fixes.

## PR ready

For PR-based ship tasks, the ready signal depends on mode: `no-mistakes` reports `done: PR <url> checks green` after CI is green, while `direct-PR` reports `done: PR <url>` after opening the PR.
Run `bin/fm-pr-check.sh <id> <PR url>` - it records `pr=` and GitHub's `pr_head=` when available in the task's meta and arms the watcher's merge poll.
Tell the captain: the PR's full URL (always the complete `https://...` link, never a bare `#number`), a one-paragraph summary, and, for `no-mistakes`, the risk level it emitted.

If the captain says "merge it", run `bin/fm-pr-merge.sh <id> <full GitHub PR URL>` yourself; that instruction is the explicit approval.
If `yolo=on`, merge a green/approved PR yourself the same way and post the required FYI.
The helper defaults to `--squash`, accepts explicit merge-method flags such as `-- --merge`, `-- --rebase`, or `-- --method=merge`, and refuses `--repo` or `-R` overrides because the repository is derived from the URL.

## Ship teardown (only after merge is confirmed)

```sh
bin/fm-teardown.sh <id>
```

The script refuses if the worktree holds uncommitted changes or committed work that has not landed; treat a refusal as a stop-and-investigate, not an obstacle.

The full "landed" definition: the work is landed once `HEAD` is reachable from any remote-tracking branch (a fork counts as a remote - upstream-contribution PRs pushed to a fork satisfy this in any mode); for a normal ship task whose commits are not so reachable, it is also landed when its PR is merged and GitHub reports a PR head that contains the current local work, or when its content is already present in the up-to-date default branch; for `local-only` ship tasks with no remote at all, the work may instead be merged into the local default branch.
Containment means local `HEAD` is the PR head, local `HEAD` is an ancestor of the PR head, or the unpushed local patches have matching patch IDs in that PR head after no-mistakes replayed the branch.
This recognizes the common squash-merge-then-delete-branch flow, where the branch's own commits live nowhere on a remote yet the change is fully in `main`; a merged-and-deleted branch now tears down cleanly instead of false-refusing.
Uncommitted changes are never landed.
The PR is looked up from the task's recorded `pr=` when present, or, when no `pr=` was ever recorded, by finding a merged PR whose head branch matches the worktree's branch and fetching its head via `refs/pull/<n>/head` if the branch itself was deleted - so a task whose merge skipped `bin/fm-pr-check.sh` (typically a yolo-authorized merge on a repo with no PR CI, where the "checks green" trigger never fires) still tears down cleanly instead of false-refusing; a missing `pr=` never by itself false-refuses landed work.
Genuinely unlanded work (no merged PR head containing the local work and content not in the default branch) and dirty worktrees still refuse, and a gh lookup error falls back to the content check rather than silently allowing.
Known benign case: after an external-PR task, a squash merge leaves the branch commits reachable only on the contributor's fork; add the fork as a remote and fetch (`git remote add fork <fork url> && git fetch fork`), then retry - never reach for `--force`.
After a successful PR-based teardown, it also runs `bin/fm-fleet-sync.sh` for that project, best-effort, so safe clone states catch up to the merge, clean detached ancestor drift self-heals, and the just-merged branch, now gone on the remote and free of its worktree, is pruned immediately.
Unsafe drift is reported as `STUCK:` and left untouched.
Then update the backlog using the teardown reminder: run `tasks-axi done` when the default tasks-axi backend is active and compatible, otherwise move the task to Done in `data/backlog.md` manually with the full `https://...` PR URL or local merge note and date and keep Done to the 10 most recent (fm-backlog).
Re-evaluate the queue and dispatch only queued work whose blockers are gone and whose time/date gate, if any, has arrived.

## The sanctioned-write exception catalog

Prime directive #1 (never write to a project) has exactly six sanctioned write exceptions; their procedures live where they are used: tool-driven project initialization (fm-project-setup), fleet sync via `bin/fm-fleet-sync.sh` (fm-session-start and teardown above), local-HEAD secondmate sync via `bin/fm-bootstrap.sh` and `bin/fm-spawn.sh` (fm-session-start, fm-dispatch), inheritable config propagation via `bin/fm-config-push.sh` and the bootstrap/spawn convergence paths (fm-session-start, fm-dispatch), self-update via `/updatefirstmate` and `bin/fm-update.sh`, and approved `local-only` merge via `bin/fm-merge-local.sh` (above).
All are fast-forward operations, guarded gitignored-config propagation, or guarded local merges that never force, stash, or discard unlanded work.
Project `AGENTS.md` maintenance is not another exception: firstmate records not-yet-committed project knowledge in `data/`, and crewmates update project `AGENTS.md` through normal delivery (fm-project-setup).

## Secondmate teardown (explicit only)

A secondmate is persistent by default.
An empty queue is healthy and does not trigger teardown.
Run `bin/fm-teardown.sh <id>` for `kind=secondmate` only when the captain or main firstmate explicitly decides to retire that persistent supervisor.
Load `secondmate-provisioning` before retiring it.
The safety check is the secondmate's own home: teardown refuses while its `state/*.meta` contains in-flight work.
With `--force`, teardown is the explicit discard path for child windows, child work, state, route, lease, and home; never use it unless the captain explicitly said to discard the work.

## Scout tasks (report instead of PR)

A scout task follows Intake, Spawn, and Supervise exactly as for ship tasks - scaffold the brief with `bin/fm-brief.sh <id> <repo> --scout`, spawn with `--scout` - then diverges after the work:

- There is no Validate or PR-ready stage. When the crewmate's status says `done`, read `data/<id>/report.md`.
- Relay the findings to the captain: plain chat for a focused answer, lavish-axi when the report has structure worth a visual (multiple findings, options, a plan).
- Tear down immediately - no merge gate. `bin/fm-teardown.sh` allows a scout worktree's scratch commits and dirty files once the report exists; if the report is missing, it refuses, because the findings are the work product.
- Record it in Done with the report path instead of a PR link using `tasks-axi done` when the default tasks-axi backend is active and compatible, otherwise hand-edit `data/backlog.md` and keep Done to the 10 most recent, then re-evaluate the queue and dispatch only queued work whose blockers are gone and whose time/date gate, if any, has arrived.

**Promotion.** When a scout's findings reveal shippable work (a reproduced bug with a clear fix) and the captain wants it shipped, promote the task in place instead of respawning: run `bin/fm-promote.sh <id>` (flips `kind=` to ship in meta, restoring teardown's full protection), then send the crewmate its ship instructions - inventory scratch state, reset to a clean default-branch base, carry over only intended fix changes, create branch `fm/<id>`, implement, and report `done` according to the project's delivery mode.
The crewmate keeps its worktree, loaded context, and repro, but the ship branch must start from a clean base with only intended changes; scratch commits and debug edits from the scout phase never ride along.
The repro becomes the regression test.
From there the task is an ordinary ship task through its mode-specific validation, PR or local merge, and Teardown.
