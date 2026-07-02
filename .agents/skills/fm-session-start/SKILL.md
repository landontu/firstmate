---
name: fm-session-start
description: Agent-only reference for firstmate session start. Load at every session start and after every restart, before taking on work. Owns the home layout and state-file reference, the bootstrap procedure and its full diagnostic catalog (MISSING, NEEDS_GH_AUTH, TANGLE, CREW_HARNESS_OVERRIDE, CREW_DISPATCH, FLEET_SYNC, SECONDMATE_SYNC, TASKS_AXI, NUDGE_SECONDMATES, FMX), the recovery checklist, and X-mode activation, mechanism, cadence, and opt-out.
user-invocable: false
---

# fm-session-start

Load this at every session start: bootstrap first, then recovery. Both procedures are below, plus the home layout they operate on and the X-mode activation that bootstrap gates.

## Home layout and state

`FM_HOME` selects the operational home for a firstmate instance.
When it is unset, the home is this repo root, which is today's behavior.
When it is set, scripts still use their own `bin/` from the repo they live in, but operational dirs come from `$FM_HOME`: `state/`, `data/`, `config/`, and `projects/`.
Existing overrides remain compatible: `FM_STATE_OVERRIDE` can still point at a custom state dir, and `FM_ROOT_OVERRIDE` still behaves like the old whole-root override when `FM_HOME` is unset.
Each secondmate gets its own persistent `FM_HOME`, so its local state, backlog, projects, and session lock are isolated from the main firstmate.

```
AGENTS.md            firstmate's job description (CLAUDE.md is a symlink to it)
CONTRIBUTING.md      contributor workflow and repo conventions
README.md            public overview and development notes
.github/workflows/   shared CI and PR enforcement, committed
.tasks.toml          tracked tasks-axi markdown backend config for the default backlog backend (fm-backlog)
.agents/skills/      shared skills, committed
.claude/skills       symlink to .agents/skills for claude compatibility
bin/                 helper scripts, committed; read each script's header before first use
.env                 optional X-mode pairing token; LOCAL, gitignored; presence-gates X mode
config/crew-harness  crewmate harness override; LOCAL, gitignored; absent or "default" = same as firstmate. Inherited: the primary pushes this into every secondmate home's config/ (fm-dispatch), so a secondmate's own crewmates use the primary's value
config/crew-dispatch.json  optional crewmate dispatch profiles; LOCAL, gitignored; firstmate-maintained but human-editable natural-language rules that choose a per-task harness/model/effort profile (fm-dispatch). Inherited by secondmate homes
config/secondmate-harness  harness the PRIMARY uses to launch SECONDMATE agents, optionally followed by a model and effort token on the same line ("<harness> [<model>] [<effort>]"; fm-dispatch); LOCAL, gitignored; absent or "default" harness falls back to config/crew-harness then firstmate's own. The primary's own setting; NOT inherited into secondmate homes (secondmates do not spawn secondmates)
config/backlog-backend  backlog backend override; LOCAL, gitignored; absent or "tasks-axi" = default tasks-axi backend, "manual" = force hand-editing; inherited by secondmate homes (fm-backlog)
config/backend  runtime session-provider backend override for new tasks; LOCAL, gitignored; absent = tmux; only tmux is verified today; not inherited into secondmate homes
config/x-mode.env    generated X-mode watcher cadence; LOCAL, gitignored; source before arming watcher when present
data/                personal fleet records; LOCAL, gitignored as a whole
  backlog.md         task queue, dependencies, history
  captain.md         captain's curated personal preferences and working style; LOCAL, gitignored, and canonical even if harness memory mirrors it
  projects.md        thin fleet navigation registry; firstmate-private, parsed by fm-project-mode.sh (fm-project-setup)
  secondmates.md      secondmate routing table; firstmate-private, maintained by fm-home-seed.sh (fm-dispatch, secondmate-provisioning)
  <id>/brief.md      per-task crewmate brief, or per-secondmate charter brief when kind=secondmate
  <id>/report.md     scout task deliverable, written by the crewmate; survives teardown
projects/            cloned repos; gitignored; READ-ONLY for you
state/               volatile runtime signals; gitignored
  <id>.status        appended by crewmates: "<state>: <note>" wake-event lines, not current-state truth
  <id>.turn-ended    touched by turn-end hooks
  <id>.grok-turnend-token   firstmate-owned grok hook registry token for the task; removed by teardown
  <id>.meta          written by fm-spawn: window=, worktree=, project=, harness=, model=, effort=, kind=, mode=, yolo=, tasktmp=; kind=secondmate also records home= and projects=; a task on a non-default runtime backend also records backend= (absent means tmux, the only implemented backend today; bin/fm-backend.sh, fm-supervise-depth) (fm-pr-check, including through fm-pr-merge, appends pr= and GitHub's pr_head= when available; fm-x-link appends x_request= and x_request_ts= for an X-mention-originated task)
  <id>.check.sh      optional slow poll you write per task (e.g. merged-PR check)
  x-watch.check.sh   generated X-mode relay poll shim; present only when opted in
  x-inbox/           generated X-mode pending mention payloads; fmx-respond drains it
  x-outbox/          generated X-mode dry-run reply and dismiss previews; inspect it when FMX_DRY_RUN is set
  x-poll.error       generated X-mode relay diagnostic dedupe marker
  .wake-queue        durable queued wakes: epoch<TAB>seq<TAB>kind<TAB>key<TAB>payload
  .afk               durable away-mode flag; present = sub-supervisor may inject escalations (set by /afk, cleared on user return)
  .watch.lock .wake-queue.lock watcher singleton and queue serialization locks
  .hash-* .count-* .stale-* .stale-since-* .seen-* .hb-surfaced-* .last-* .heartbeat-streak   watcher internals; never touch
  .watch-triage.log  watcher's absorbed-wake debug log (size-capped); never relied on, safe to delete
  .last-watcher-beat watcher liveness beacon, touched every poll (including while absorbing benign wakes); fm-guard.sh reads it
  .subsuper-* .supervise-daemon.*   sub-supervisor internals; never touch
.no-mistakes/        local validation state and evidence; gitignored
```

## Bootstrap (run at every session start)

Bootstrap is detect, then consent, then install.
Never install anything the captain has not approved in this session.

Run `bin/fm-bootstrap.sh`.
Bootstrap also refreshes the fleet via `bin/fm-fleet-sync.sh`, best-effort and non-fatal, under the sanctioned-write exceptions of the prime directives.
Set `FM_FLEET_PRUNE=0` to temporarily disable that branch pruning.
Bootstrap also sweeps every live secondmate home, fast-forwarding each one's worktree to firstmate's own current default-branch commit so the fleet stays converged on whatever version firstmate is on.
The live set comes from `state/<id>.meta` records with `kind=secondmate`; `data/secondmates.md` only backfills `home=` for older or incomplete meta records.
This is a purely local fast-forward (every secondmate home is a worktree of this same repo, sharing one object store), never a fetch from origin and never a surprise pull: the version followed is simply whatever the primary is currently on, which only the captain changes deliberately via `git pull` or `/updatefirstmate`.
A tracked-files fast-forward never touches the gitignored operational dirs, so a secondmate's backlog, projects, and in-flight work are never disturbed; a dirty, diverged, or in-flight home is skipped untouched.
The same sweep also propagates the primary's declared inheritable config (`config/crew-dispatch.json`, `config/crew-harness`, and `config/backlog-backend`; fm-dispatch and fm-backlog) into each live secondmate home's `config/`, so every secondmate's own crewmates, dispatch profiles, and backlog backend stay on the primary's settings.
Because `config/` is gitignored this is a separate, primary-authoritative copy independent of the tracked-files fast-forward: it re-converges every live home whether or not its tracked files advanced, and it touches only the declared inheritable items (never `config/secondmate-harness`).
For a mid-session inheritable-config change that should reach live secondmates without a full bootstrap, run `bin/fm-config-push.sh`.
It is config-only: it uses the same live secondmate discovery and the same `propagate_inheritable_config` helper as bootstrap, prints a per-home/per-item summary, does not fast-forward tracked files, and does not nudge secondmates.
The propagation helper itself keeps stdout silent for existing callers, but warns on stderr when an item is skipped because the destination does not allow it or when a copy/remove error occurs.
The sweep reports the `NUDGE_SECONDMATES:` line below only when a running secondmate actually advanced with an instruction change, so firstmate knows which ones to live-converge.
Silence means all good: say nothing and move on.
Otherwise it prints one line per problem or capability fact; handle each:

- `MISSING: <tool> (install: <command>)` - list the missing tools to the captain with a one-line purpose each plus the printed install commands, wait for consent (one approval may cover the list), then run `bin/fm-bootstrap.sh install <approved tools...>`.
  For `treehouse`, this also covers an installed version whose `treehouse get` lacks `--lease`; treat it as an upgrade request.
  For `no-mistakes`, this also covers an installed version older than 1.31.2, because crewmate validation briefs delegate gate mechanics to no-mistakes' version-matched guidance.
  For `tasks-axi`, this appears only when `config/backlog-backend` is absent or set to `tasks-axi`; hand-edit fallback continues until the captain approves installation.
- `NEEDS_GH_AUTH` - ask the captain to run `! gh auth login` (interactive; you cannot run it for them).
- `TANGLE: <remediation>` - the firstmate primary checkout (the repo root, `FM_ROOT`) is stranded on a feature branch instead of its default branch: a crewmate working firstmate-on-itself branched/committed in the primary instead of its own isolated worktree (fm-supervise-depth). The work is safe on that branch ref; restore the primary to its default branch with the printed `git -C <root> checkout <default>`, then re-validate that branch in a proper worktree. This is the only sanctioned firstmate-initiated git write to the primary, and it is a non-destructive branch switch that strands nothing.
- `CREW_HARNESS_OVERRIDE: <name>` - record and use the override silently; surface a harness fact only if it actually blocks work or the captain asks.
- `CREW_DISPATCH: invalid config/crew-dispatch.json - <reason>` - the optional dispatch profile file exists but failed low-cost bootstrap validation; continue with the normal fallback chain, resolve and pass the chosen fallback harness explicitly while the file remains present, fix the JSON, unverified harness name, or invalid harness/effort pair when convenient, and do not select a bad profile.
- `CREW_DISPATCH: active config/crew-dispatch.json` - bootstrap validated the optional dispatch profile file and printed its active rules as `rule: <when> -> <harness[/model[/effort]]>` lines, plus `default:` when present.
  Keep this block top-of-mind during intake; it is the reminder that every crewmate or scout dispatch must consult the rules before spawning.
- `FLEET_SYNC: <repo>: skipped: <reason>` - a benign one-off skip (offline, no origin, local-only); bootstrap continued, investigate only if it blocks work.
- `FLEET_SYNC: <repo>: recovered: <detail>` - the clone had drifted onto a clean detached HEAD holding no unique commits and the sync self-healed it (re-attached the default branch and fast-forwarded); no action needed, it is reported only so the self-heal is visible.
- `FLEET_SYNC: <repo>: STUCK: on <state>, N commits behind <base> - needs attention` - the clone is dirty, on a non-default branch, detached with unique commits, or diverged, so the sync left it untouched (never forcing or discarding); it will keep falling behind until you look. A loud STUCK, especially a growing N across bootstraps, means that clone needs hands-on attention; dispatch a crewmate or resolve it before it strands work.
- `SECONDMATE_SYNC: secondmate <id>: skipped: <reason>` - the local-HEAD secondmate sync left a live secondmate home on its existing checkout because the home was dirty, diverged, unsafe, on the wrong branch, missing the primary target commit, or otherwise not fast-forwardable; bootstrap continued, but inspect the reason because the secondmate may be stale after a primary update.
- `TASKS_AXI: available` - a default-backend capability fact, not a problem; record it silently and use `fm-backlog` for backlog mutations.
  It prints only when `config/backlog-backend` is absent or set to `tasks-axi` and the compatibility probe accepts `tasks-axi --version` as 0.1.1 or newer.
  If the backend is not opted out and `tasks-axi` is missing or incompatible, bootstrap reports `MISSING: tasks-axi (install: npm install -g tasks-axi)` but still falls back to hand-editing and never blocks work.
  If `config/backlog-backend=manual`, bootstrap hand-edits and does not suggest installing `tasks-axi`.
- `NUDGE_SECONDMATES: <window-targets...>` - the secondmate sweep fast-forwarded one or more *running* secondmate homes to firstmate's current version and their instructions actually changed; for each listed window, send a one-line re-read nudge with `bin/fm-send.sh <window-target> 'firstmate was updated to the latest - please re-read your AGENTS.md to pick up the new instructions.'` so that secondmate picks up its new instructions.
  This mirrors `/updatefirstmate`'s `nudge-secondmates:` report: it is a gentle steer, never an interruption, and the fast-forward already landed safely.
  A secondmate that was skipped, already current, or whose advance changed no instructions is not listed and must not be disturbed.
- `FMX: X mode on ...` / `FMX: X mode off ...` - bootstrap confirmed or removed the local X-mode poll artifacts; follow the X-mode section below for watcher cadence restart only when a running watcher needs the transition applied immediately.

Bootstrap's fleet refresh is bounded by `FM_FLEET_SYNC_BOOTSTRAP_TIMEOUT` seconds, default 20; a timeout is reported as a `FLEET_SYNC` skip and does not block startup.

Then read `data/projects.md`, the fleet registry, to load what each project is.
If it is missing or disagrees with what is actually under `projects/`, rebuild it from the clones (a README skim per project is enough) before taking on work.
Then read `data/secondmates.md` if present so intake can route work by registered secondmate scope.
Then read `data/captain.md` if present, to load this captain's curated preferences and working style.
If it is absent, use this template's defaults with no special preferences.
Treat any harness memory of these preferences as a recall cache only; `data/captain.md` is the canonical, harness-portable home.

Do not dispatch any work until the tools that work needs are present and GitHub auth is good.
If the captain names a different static crewmate harness at bootstrap or later, write it to `config/crew-harness` (local, gitignored).
If the captain expresses a standing dispatch preference such as "use grok for news-dependent work", codify it in `config/crew-dispatch.json` instead (fm-dispatch).

## Recovery (run at every session start, after bootstrap)

You may have been restarted mid-flight.
Reconcile reality with your records before doing anything else:

1. Run `bin/fm-lock.sh` to acquire the session lock (it records the harness process PID, which is session-stable).
   If it refuses because another live session holds the lock, tell the captain another active session is already managing the work and operate read-only until resolved.
2. Drain queued wakes with `bin/fm-wake-drain.sh` and keep the printed records as the first work queue for this recovery turn.
3. Read `data/backlog.md`, `data/secondmates.md` if present, every `state/*.meta`, and every `state/*.status`.
   Treat status files as wake-event history; when you need a live current-state read for a recorded direct report, use `bin/fm-crew-state.sh <id>` instead of inferring from the last status line.
4. Use the `window=` values from this home's `state/*.meta` files as the live direct-report set, then check those backend endpoints (tmux panes today).
   Do not sweep every `fm-*` tmux window across all sessions during recovery; another firstmate home's child panes may share that namespace and are not this home's orphans.
5. If a recorded direct-report window is missing, reconcile it through its meta as described below.
6. For meta with no window, reconcile by kind.
   For ordinary crewmates, check `treehouse status` in that project, salvage or report.
   For `kind=secondmate`, load `secondmate-provisioning`, treat it as a dead persistent direct report, and respawn it from recorded meta or the registry entry.
7. Do not reconstruct a secondmate's whole tree from the main home.
   The main firstmate reconciles only direct reports.
   Each secondmate is a firstmate in its own home, so it reconciles only work that is already its own and then idles; it never creates new work during recovery.
8. If `state/.afk` is present, load `/afk`, ensure the daemon is running, do not separately arm the watcher because the daemon owns it, and resume away-mode supervision.
9. Surface only what needs the captain: pending decisions, PRs ready to merge, failures, or needed credentials.
   If there is nothing that needs them, say nothing and resume.
10. Handle drained wakes, then follow the AGENTS.md supervision checklist; if `state/.afk` exists, the daemon owns the watcher.

## X mode: activation, mechanism, cadence

X mode lets a firstmate instance answer public mentions of the shared `@myfirstmate` bot on X, and act on actionable mention requests, in firstmate's own voice, from its live fleet state.
It ships inside this repo for every user but is **inert until opted in**, so a user who never enables it sees zero behavior change.
Response behavior (classifying, acting, replying, follow-ups) lives in the `fmx-respond` skill; this section owns activation and cadence.

**Activation is `.env` presence, not a command.**
Put one value, `FMX_PAIRING_TOKEN`, into a `.env` file at this home's root (`.env` is gitignored).
That token is the whole consent, including standing authorization for normal reversible lifecycle actions from mention requests, and the only required config; the relay derives the tenant from it.
It is not consent for destructive, irreversible, or security-sensitive actions; those still require trusted-channel confirmation first.
`FMX_RELAY_URL` is optional and defaults to `https://myfirstmate.io`; only a developer pointing at a local relay sets it.

**Mechanism (purely additive; the watcher backbone is untouched).**
On the next bootstrap, an `.env` with a non-empty `FMX_PAIRING_TOKEN` makes bootstrap drop two gitignored, idempotent artifacts: `state/x-watch.check.sh`, a check shim that execs `bin/fm-x-poll.sh`, and `config/x-mode.env`, which exports `FM_CHECK_INTERVAL=30`.
The shim rides the existing `state/*.check.sh` mechanism (fm-supervise-depth): each check cycle `bin/fm-x-poll.sh` does one short, bounded poll of the relay; HTTP 204 is silent, a pending mention with non-empty text is stashed to `state/x-inbox/<request_id>.json` and prints `x-mention <request_id>`, which the watcher surfaces as a `check:` wake.
Missing local poll dependencies and relay auth/config responses print one rate-limited `x-mode-error ...` diagnostic, which the watcher surfaces as a `check:` wake for captain-visible repair; report that as an X-mode configuration blocker and do not load `fmx-respond` for it.
On opt-out (the token is removed or emptied), the next bootstrap deletes both artifacts so the instance reverts to the default 300s, no-poll behavior.
This layer stays additive to the watcher backbone: **no** edit is made to `bin/fm-watch.sh`, `bin/fm-watch-arm.sh`, `bin/fm-wake-lib.sh`, or the afk daemon (`bin/fm-supervise-daemon.sh` and the `afk` skill).
X mode lives in X-specific `bin/` scripts, the `fmx-respond` skill, and the generated local artifacts.

**Cadence.**
An X instance polls every 30s instead of the default 300s.
To get that, arm the watcher with the X cadence sourced, exactly as the AGENTS.md supervision section describes but prefixed:

```sh
[ -f config/x-mode.env ] && . config/x-mode.env
bin/fm-watch-arm.sh        # as the harness's tracked background task
```

The sourced file exports `FM_CHECK_INTERVAL=30` into the arm, which the watcher it forks inherits, so only an X instance speeds up; a non-X instance has no such file and keeps the 300s default.
Because `bin/fm-watch.sh` reads `FM_CHECK_INTERVAL` only at process start and the arm no-ops on an already-healthy watcher, a cadence **transition** (opt-in while a watcher is already running, or opt-out) is applied by restarting the home-scoped watcher with the new environment: `[ -f config/x-mode.env ] && . config/x-mode.env; bin/fm-watch-arm.sh --restart` (omit the source on opt-out so the 300s default returns), run as the harness's tracked background task.
Bootstrap deliberately does not restart the watcher itself - it must never block, and `fm-watch-arm.sh --restart` is home-scoped (never a broad `pkill`).
X mode is also a reason to keep the watcher armed even with no fleet work, so an X-only user is still served.
Cadence under away-mode (the supervise daemon owns the watcher then) is a separate follow-up and out of scope here; while afk is active the daemon's default cadence applies.
