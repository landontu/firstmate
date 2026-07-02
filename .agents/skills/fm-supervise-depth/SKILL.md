---
name: fm-supervise-depth
description: Agent-only reference for firstmate supervision internals. Load on a WORKTREE TANGLE banner, a watcher-down guard banner (work in flight with a stale state/.last-watcher-beat beacon), a state/.subsuper-inject-wedged marker, a wake the daemon classifier escalated, or when diagnosing watcher, guard, wake-triage, or arm-chain behavior. Owns the wake-triage classifier, singleton/liveness mechanics, the guard beacon, the worktree-tangle guard, and supervision token discipline.
user-invocable: false
---

# fm-supervise-depth

The always-loaded supervision invariant lives in AGENTS.md; this is the depth behind it: how the watcher triages wakes in bash, how the arm chain and its guards work, and how to diagnose the two guard banners.

## Wake triage (absorb only when provably working)

The watcher classifies every wake it detects in bash and absorbs the benign majority without ever waking you, but it never absorbs a crewmate that has stopped.
The no-verb path - a `signal` whose status carries no captain-relevant verb (a `working:` note, a bare turn-ended) and a non-terminal `stale` (a crewmate gone quiet) - is absorbed ONLY while that crewmate shows positive evidence it is still working: its no-mistakes run for its branch is in an actively-running step, or its pane shows the harness busy signature.
The watcher reads that evidence with `bin/fm-crew-state.sh` (run-step first, then pane), so a finish that wrote no `done:` status - for example one reported only through interactive pane menus - is no longer swallowed.
A `heartbeat` with no captain-relevant change is likewise absorbed.
Absorbed wakes are advanced past their suppression marker and logged to `state/.watch-triage.log` while the watcher keeps blocking - no queue entry, no exit, no LLM turn.
It exits with one reason line on an *actionable* wake: a `signal` carrying a captain-relevant verb (`needs-decision:`/`blocked:`/`failed:`/`done:`/`PR ready`/`checks green`/`ready in branch`/`merged`); a no-verb `signal` whose crewmate is NOT provably working (it stopped its turn with no running pipeline and no busy pane, so it may be done, waiting on a decision, or wedged); any `check`; a terminal `stale`; a non-terminal `stale` whose crewmate is not provably working (surfaced at once, never left to wait out the timer); a provably-working non-terminal `stale` that stays idle past the wedge threshold (`FM_STALE_ESCALATE_SECS`, default 240s); or the heartbeat fleet-scan's fail-safe backstop catching a captain-relevant status the per-wake path missed.
Only an actionable wake is written to the durable queue at `state/.wake-queue` - before advancing suppression markers such as `.seen-*`, `.stale-*`, `.last-check`, or `.last-heartbeat` - and only an actionable wake ends the background task, so you re-arm exactly once per actionable event instead of once per wake.
That is what eliminates the quiet-stretch churn without swallowing a finish: during a long crew validation the run is actively running, so the crewmate's `turn-ended`/`working:`/non-terminal-stale wakes (and no-change heartbeats) are absorbed in bash, the liveness beacon (`state/.last-watcher-beat`) stays fresh the whole time so `fm-guard.sh` never false-alarms, and your LLM is woken only when something genuinely needs you - including the moment that crewmate stops with no running pipeline, which now surfaces immediately.
The classifier lives in `bin/fm-classify-lib.sh` and is shared: the captain-relevant verb set and status-scan primitives back both this always-on watcher and the away-mode daemon, so the overlapping policy cannot drift; the provably-working predicate (`crew_is_provably_working`, reusing `bin/fm-crew-state.sh`) lives in that same library and runs only on the watcher's no-verb path, never on every wake, so the per-wake triage stays cheap.
While `state/.afk` exists the daemon owns supervision, so the watcher reverts to one-shot - it surfaces every wake for the daemon to classify (skipping the provably-working read entirely) - and never double-triages; the daemon keeps its own bounded-latency stale backstop for a crewmate that stops in away mode.

Heartbeats back off exponentially while they are the only wakes firing (600s doubling to a 2h cap - an idle fleet stops burning turns); any signal, stale, or check wake resets the cadence to the base interval.
Due per-task checks run before signal scanning so chatty crewmate status updates cannot starve slow polls like merge detection.
The custom check contract, for any `state/<id>.check.sh` you write yourself: print one line only when firstmate should wake, print nothing otherwise, and finish before `FM_CHECK_TIMEOUT`.

## Arm-chain mechanics

Each cycle is one harness-tracked background task that blocks until an actionable wake is due (benign wakes are absorbed in bash without ending the task), fires with one reason line, and ends, so the chain survives only when firstmate starts the next cycle after each fire.
Never fire-and-forget the watcher with a shell `&` inside another call: that backgrounded child is reaped when the call returns, so supervision silently stops, and worse, the dying process reports a false "already running" that hides the gap.
Run `bin/fm-watch-arm.sh` as its OWN background task with nothing else in that bash, never tacked onto the tail of a multi-command call: bundled, its self-verifying status line is buried in unrelated output and it can silently no-op as a side effect of those other commands, so no fresh cycle gets established and supervision lapses unnoticed.
`bin/fm-watch-arm.sh` is self-verifying: it confirms a genuinely live watcher with a fresh beacon and prints exactly one honest status line - `watcher: started ...`, `watcher: healthy ...`, or `watcher: FAILED - no live watcher with a fresh beacon` (which exits non-zero) - so treat that line, not a process count or an unverified "already running", as the source of truth for watcher state.
`started` (this arm just launched the live cycle, now blocking for the next wake) and `healthy` (a live cycle already held the lock) both mean a cycle is live, so do NOT start another - re-running it while one is healthy only churns no-op tasks and never establishes a fresh cycle; `FAILED` means no live cycle, so arm one now after draining any queued wakes.
A cycle is down only when its background task completes carrying a WAKE REASON (`signal`/`stale`/`check`/`heartbeat`): that is the watcher firing, and that is the one moment to handle the wake and then start exactly one fresh cycle.
The watcher is singleton-safe: acquisition is race-proof, so under any number of concurrent arms at most one watcher ever holds this home's lock, and a duplicate that somehow starts self-evicts within one poll once it sees the lock no longer names it.
If one is already alive with a fresh liveness beacon, another invocation exits cleanly instead of creating a duplicate watcher; if the live holder's beacon is stale, the new invocation exits with an actionable failure.
If a forced restart is ever genuinely needed, use `bin/fm-watch-arm.sh --restart`, which stops only this home's watcher (the pid recorded in this home's `state/.watch.lock`) and starts a fresh one.
Never `pkill -f bin/fm-watch.sh`: that pattern matches every firstmate home's watcher, including secondmate homes that run the same script, so a broad pkill from one home kills sibling homes' watchers.

A wake's `signal:` line lists every signal that landed within the coalescing grace window (e.g. a status write plus the same turn's turn-end marker), and each status file is ~30 tokens and usually sufficient.
When a task reaches a terminal state on any wake (a `done`/merge `check:`, a `failed` signal, a scout report, a local-only merge), and X mode is enabled, also post the X-mention completion follow-up if that task is X-linked: `bin/fm-x-followup.sh --check <id>` then `bin/fm-x-followup.sh <id> --text-file <path>` (fmx-respond).

Never rely on hooks or status files alone; when a heartbeat wake does reach you, the review of every window is mandatory and unconditional.
tmux is the ground truth.
For `kind=secondmate`, an idle pane is healthy.
A secondmate may be sitting on its own watcher with no visible pane changes, so parent supervision uses status writes plus heartbeat review, not pane-staleness.
`fm-watch.sh` therefore skips stale-pane wakes for windows whose meta records `kind=secondmate`.
This exception is narrow: ordinary crewmates still trip stale detection when their pane stops changing without a busy signature.

## The liveness guard

Watcher liveness is guarded, not just disciplined.
While running, `fm-watch.sh` touches `state/.last-watcher-beat` every poll cycle.
The supervision scripts (`fm-peek`, `fm-send`, `fm-spawn`, `fm-teardown`, `fm-pr-check`, `fm-promote`, `fm-review-diff`, `fm-fleet-sync`, `fm-update`) call `bin/fm-guard.sh` first, which warns to stderr when any task is in flight (`state/*.meta` exists) but queued wakes are pending, or that beacon is missing or older than `FM_GUARD_GRACE` (default 300s).
`bin/fm-wake-drain.sh` runs the same guard after it drains, so the liveness check also fires on a drain-and-handle turn that runs no other supervision script, narrowing the window in which a lapsed chain can hide; the grace beacon keeps it silent right after a normal fire and it warns only on a genuine stale-beyond-grace lapse.
The no-watcher case leads with a prominent, bordered ●-marked banner (in-flight count, beacon age, and the exact one-line re-arm command) so it reads as an alarm rather than a buried stderr line you can skim past.
So the next time you touch the fleet with queued wakes or no watcher alive, the tool output itself tells you what to do - a pull-based guard that works on any harness, since it rides the script output you already read rather than a harness-specific hook.
The grace window keeps normal handling (watcher briefly down between a wake and its re-arm) silent.
If a guard warning says queued wakes are pending, drain them before doing anything else.
If a guard warning says watcher liveness is stale, arm `bin/fm-watch-arm.sh` after draining any queued wakes.
Because a text-only "holding" turn runs no supervision script, this guard cannot catch a blind turn; the AGENTS.md "no turn ends blind" discipline must.

## The worktree-tangle guard

`fm-guard.sh` carries a second, independent alarm in the same bordered ●-marked style: the **worktree-tangle** guard.
Firstmate is a treehouse-pooled git repo of itself - the primary checkout (the repo root, `FM_ROOT`) and every crewmate worktree and secondmate home are linked worktrees of one repo - and the primary must stay on its default branch.
If a crewmate sent to work firstmate-on-itself branches or commits in the primary instead of its own isolated worktree, the primary is stranded on a feature branch (the failure this guards against); the guard names the offending branch and prints the non-destructive restore (`git -C <root> checkout <default>`), so the tangle surfaces on the very next fleet action.
The check is scoped precisely to the primary: detached HEAD (the legitimate resting state of crewmate worktrees and secondmate homes on the default branch) and the default branch itself never alarm; only a named non-default branch checked out in the primary does.
The same assertion runs at session start as the bootstrap `TANGLE:` line (fm-session-start).
Two further guards prevent the tangle upstream: `fm-spawn` refuses to launch unless `treehouse get` yields a genuine isolated worktree distinct from the primary checkout, and every ship brief's first instruction has the crewmate verify it is in its own worktree before branching (fm-brief).

## Foreground blocking and token discipline

Watcher liveness is not enough if you are foreground-blocked.
Whenever one or more tasks are in flight, do not run long foreground-blocking operations in your own session.
This is about firstmate's own session: it includes a no-mistakes pipeline firstmate runs for this repo, long builds, and any other multi-minute command.
Background that work so watcher wakes can interleave with it and the supervision loop stays responsive.
A crewmate driving its own `no-mistakes` validation does the opposite: it drives that gate loop synchronously and processes every return, never idle-waiting for its own validation run to advance on its own.

Token discipline: for a crewmate's current state prefer `bin/fm-crew-state.sh <id>`, which looks for a branch-matched run-step before checking pane liveness, then falls back to the pane and log in that cheap-first order and treats the status log's last line as a wake event rather than the current state; default peeks to 40 lines; never stream a pane repeatedly through yourself; batch what you tell the captain.
The context-% shown in a peek is not actionable as crew health; ignore it and intervene only on real signals (`signal`, `stale`, `needs-decision`, `blocked`), looping or confusion in the pane, or a question the brief already answers.
Silence is the correct state while a healthy background watcher is waiting.
Empty polls, elapsed waiting time, and "still no change" are tool bookkeeping, not conversational progress.
