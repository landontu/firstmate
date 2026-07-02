---
name: fm-dispatch
description: Agent-only reference for firstmate work intake and dispatch. Load on every new task at intake, when picking a harness/model/effort profile (crew-dispatch.json), when routing work to a secondmate, and when spawning a crewmate, scout, or secondmate. Owns project resolution, secondmate scope routing, ship/scout/readiness classification, dispatch profiles and precedence, per-harness profile axes, secondmate-harness pinning, inheritable config, and fm-spawn mechanics.
user-invocable: false
---

# fm-dispatch

Load this at intake for every new piece of work, and before every spawn. Load `harness-adapters` as well before any spawn or recovery.

## Intake: resolve the project first

The captain will rarely name the project explicitly, and may juggle several projects across messages.
Resolve each message independently; never assume the last-discussed project out of habit.
Use these signals in order:

1. An explicit project name in the message wins.
2. A clear follow-up ("also add tests for that", a reply to a PR you reported) inherits the project of the thing it refers to.
3. Otherwise, match the message content against what you know: project names under `projects/`, in-flight tasks in `data/backlog.md`, and the projects' own code and READMEs (read them; that is what your read access is for). A mentioned feature, file, stack trace, or technology usually points at exactly one project.
4. One confident match: proceed, but state the project in plain outcome language in your reply ("I'll work on this in `yourapp`") so a wrong guess costs one correction instead of wasted work.
5. More than one plausible match, or none: ask a one-line question. A misdirected dispatch is recoverable because crewmates work in isolated worktrees, but it is expensive; a question is cheap.

## Intake: resolve the secondmate scope

`data/secondmates.md` is the secondmate routing table.
Every persistent secondmate has one line:

```markdown
- <id> - <charter summary> (home: <absolute-home-path>; scope: <natural-language responsibility>; projects: <project-a>, <project-b>; added <date>)
```

The `scope:` field is used during intake; the `projects:` field is a non-exclusive clone list, not ownership.

Read `data/secondmates.md` before dispatching and compare the work request to each registered `scope:`.
Route by the nature of the task, not just the project name.
A project may appear in several `projects:` clone lists, so choose the secondmate whose natural-language scope actually fits the work, such as triage versus feature development.
If the resolved project is `local-only`, keep the work with the main firstmate even when a secondmate scope sounds relevant.
If a secondmate's scope fits, steer that secondmate with one concise instruction via `bin/fm-send.sh fm-<id> '<work request>'` and let it run the normal lifecycle inside its own home.
Its charter retargets escalation to the main firstmate's status file, so routine internal churn stays inside the secondmate home and only `done`, `blocked`, `needs-decision`, `failed`, or captain-relevant phase changes wake the main firstmate.
The bare `fm-<id>` target resolves through this home's `state/<id>.meta`; pass an explicit backend target only when intentionally targeting an endpoint outside this firstmate home.
A secondmate is itself a firstmate, so a request reaches it in its own chat, which you never read - the return channel that wakes you is its status file.
So `fm-send` to a bare `fm-<id>` whose meta is `kind=secondmate` automatically prepends a from-firstmate marker (`bin/fm-marker-lib.sh`); the secondmate recognizes it and returns its answer via its status file, or via a doc under its home plus a status pointer for a detailed response, never only in chat.
Expect and read that response on the status/doc path the same way you read any other status signal; do not peek the secondmate's chat for the answer.
A captain typing directly into the secondmate's window is unmarked and stays a conversational captain intervention, so do not relay captain-destined chat through this path; the marker is applied only by `fm-send` to a `kind=secondmate` target.
Do not spawn a direct crewmate for work that belongs to a secondmate scope unless the secondmate is blocked or the captain explicitly redirects it.
If no secondmate scope fits, proceed in the main firstmate or create a new secondmate with the captain when that domain should become persistent (load `secondmate-provisioning`).

A secondmate is idle by default: it acts only on work the main firstmate routes to it.
On startup and restart it runs bootstrap and recovery solely to reconcile work that is already its own - in-flight crewmates, tracked backlog items, and durable watches in its home - and then waits silently for routed work.
It must never spawn a survey, audit, or self-directed "find improvements" task on its own initiative; an empty queue is a healthy resting state, not a cue to invent work.
This idle contract is encoded in the charter brief (fm-brief), so it travels with the live secondmate as well as living here.

**Hand off in-scope backlog on creation.**
When a secondmate is created for a domain, the existing main-backlog items that fall under its scope should become its work instead of staying stranded in the main backlog.
Scope-matching is firstmate's judgment against the secondmate's natural-language scope, not a keyword rule.
Read `data/backlog.md`, pick queued items that fit the scope, and move them with `bin/fm-backlog-handoff.sh <secondmate-id> <item-key>...`.
Do not hand off `local-only` items; that work stays with the main firstmate.
For idempotence, destination validation, and refusal of `## In flight` entries, load `secondmate-provisioning`.

## Intake: classify shape and readiness

Shape:

- **Ship** (the default): the deliverable is a change to the project. It ships through the project's delivery mode: `no-mistakes`, `direct-PR`, or `local-only` (fm-deliver).
- **Scout:** the deliverable is knowledge - an investigation, a plan, a bug reproduction, an audit. It ends in a report at `data/<id>/report.md`, never a PR. When the captain asks "what's wrong", "how would we", or "find out why" about a project, that is a scout task; dispatch it instead of doing the digging yourself.

Readiness:

- **Dispatchable:** no overlap with in-flight tasks. Dispatch immediately. There is no concurrency cap.
- **Blocked:** touches the same files or subsystem as an in-flight task, or explicitly depends on an unmerged PR. Record it in `data/backlog.md` with `blocked-by: <id>` and tell the captain what work is waiting and why. Scout tasks are read-mostly and almost never block on anything.

Keep dependency judgment coarse: same repo plus overlapping area means serialize; everything else runs parallel.
For `no-mistakes` projects, the pipeline rebase step absorbs mild overlaps; for other modes, have the crewmate rebase before review or merge if needed.

Then write the brief (fm-brief).

## Crew dispatch profiles

Crewmates default to the same harness you are running on.
The captain may override the static default at any time, typically at bootstrap: record the choice in `config/crew-harness` (a single adapter name; absent or `default` means mirror your own harness).
Resolve `default` with `bin/fm-harness.sh`; resolve the active static crewmate harness with `bin/fm-harness.sh crew`.

`config/crew-dispatch.json` is an optional local dispatch profile file.
It is firstmate-maintained but human-editable.
When the captain expresses a standing preference such as "use grok for news-dependent work", firstmate codifies it into this file; the captain may also hand-edit it.
The file is JSON so firstmate can read the natural-language rules and bootstrap can validate it with `jq`.
When the file is valid, bootstrap prints a concise `CREW_DISPATCH: active config/crew-dispatch.json` block listing each active rule and any default profile so the current policy is visible at every session start.
See `docs/examples/crew-dispatch.json` for a documented starting point to copy into local `config/crew-dispatch.json`.

Schema:

```json
{
  "rules": [
    {
      "when": "<natural-language condition describing a kind of task>",
      "use": { "harness": "<adapter>", "model": "<optional model>", "effort": "<low|medium|high|xhigh|max, optional>" },
      "why": "<optional rationale that helps firstmate choose>"
    }
  ],
  "default": { "harness": "<adapter>", "model": "<optional model>", "effort": "<optional effort>" }
}
```

Per rule, `when` and `use` are required, and `use.harness` is required.
`use.model`, `use.effort`, and `why` are optional.
`default` is optional.
An omitted model or effort means the selected harness uses its own default for that axis.

When `config/crew-dispatch.json` is present, read it during intake before every crewmate or scout dispatch.
Pick the single best-fit rule using your own judgment.
This is explicitly not first-match: weigh all rules, their `when` text, and their `why` rationales against the actual task.
Resolve the chosen rule's `use` object into a concrete profile `(harness, model, effort)` and pass it to `bin/fm-spawn.sh` with explicit `--harness`, `--model`, and `--effort` flags for the axes that are set.
If no rule fits, use `default`.
If `default` is absent, fall back to `config/crew-harness` through `bin/fm-harness.sh crew`, exactly as the static path did before dispatch profiles, but still pass that resolved harness explicitly.
This is enforced: when `config/crew-dispatch.json` exists, `bin/fm-spawn.sh` refuses crewmate and scout launches that do not include an explicit harness (`--harness <name>`, a positional adapter name, or a raw launch command).
That refusal is the consultation backstop, so the rules are never silently skipped.
The requirement is gated only on the file's presence; when the file is absent, `fm-spawn.sh` keeps resolving the crewmate harness from `config/crew-harness` as before.
Secondmate launches are exempt because they resolve through `fm-harness.sh secondmate`, not the crewmate dispatch-profile rules.

Precedence, highest first:

1. An explicit per-task captain override, such as "run this one on codex" or "use haiku for this".
2. firstmate's best-fit rule from `config/crew-dispatch.json`.
3. The dispatch file's `default` profile.
4. `config/crew-harness`.

Never select an unverified harness.
Validate every selected harness name against the verified adapter list (`claude`, `codex`, `opencode`, `pi`, `grok`).
If a dispatch rule or default names an unverified harness, ignore that profile, fall back to the next valid source, and note the problem when it affects the dispatch.
The shell scripts never parse or match the natural-language rules; firstmate does the matching and passes only concrete flags to `fm-spawn`.
`fm-spawn` only checks whether the file exists so it can enforce the explicit-harness backstop for crewmate and scout dispatches.

The verified profile axes are:

- `claude`: model via `--model <name>`, effort via `--effort <low|medium|high|xhigh|max>`.
- `codex`: model via `--model <name>`, effort via `-c 'model_reasoning_effort="<low|medium|high|xhigh>"'`; `max` is not passed because the installed Codex model catalog advertises only `low`, `medium`, `high`, and `xhigh`.
- `grok`: model via `--model <name>`, reasoning effort via `--reasoning-effort <low|medium|high|xhigh>`; `max` is not passed because Grok rejects it for `--reasoning-effort`.
- `pi`: model via `--model <name>`, effort via `--thinking <low|medium|high|xhigh>`; `max` is not passed because the installed Pi CLI warns that it is invalid.
- `opencode`: model via `--model <provider/model>`; no verified effort flag for firstmate's interactive `opencode --prompt` launch, so effort is not passed.

If the selected profile asks for an effort value the selected harness does not accept, `fm-spawn` records the requested `effort=` in meta for traceability but omits the launch flag so the harness starts successfully.
Bootstrap reports this as a `CREW_DISPATCH` diagnostic when it can see the invalid harness/effort pair in `config/crew-dispatch.json`.

## Secondmate harness, model, and effort

Secondmates can run on a different harness than crewmates.
`config/secondmate-harness` (local, gitignored) is the harness the primary uses to launch SECONDMATE agents; resolve it with `bin/fm-harness.sh secondmate`, which follows the fallback chain `config/secondmate-harness` -> `config/crew-harness` -> your own harness.
So an absent or `default` `config/secondmate-harness` behaves exactly as before this knob existed - secondmates launch on the crew harness - and setting it splits the two: e.g. primary `config/crew-harness=codex` with `config/secondmate-harness=claude` runs the secondmate AGENTS on claude while all crewmates (the primary's and the secondmates' own) run on codex.
`bin/fm-spawn.sh` resolves a `--secondmate` launch through `secondmate` mode and a crewmate/scout launch through `crew` mode; an explicit per-spawn `--harness` flag or positional harness arg still overrides either kind.
The split is durable: every secondmate respawn (recovery, `/updatefirstmate`, restart) re-resolves from `config/secondmate-harness`, so it survives restarts without being recorded per-task.

`config/secondmate-harness` may also pin a concrete model and effort for the secondmate agent, in the SAME file rather than a new one: the format is a single whitespace-separated line `<harness> [<model>] [<effort>]`, with only the first non-empty, non-comment line parsed.
A bare `<harness>` (today's format, e.g. `claude`) behaves exactly as before - harness only, no model/effort flag - so this is fully backward-compatible.
`bin/fm-harness.sh secondmate-model` and `bin/fm-harness.sh secondmate-effort` print the optional 2nd/3rd tokens (empty when absent, or when the file is absent/`default`/harness-only); they read only `config/secondmate-harness`, never `config/crew-harness`, which stays a bare adapter name.
For a `--secondmate` spawn, `bin/fm-spawn.sh` populates `MODEL`/`EFFORT` from those tokens only when the harness itself came from the secondmate config path for that spawn.
An explicit per-spawn `--harness` flag, positional harness arg, or raw launch command starts clean on model and effort too, unless the caller also passes explicit `--model` or `--effort`.
When the file's tokens do apply, an explicit per-spawn `--model` or `--effort` flag always wins over the file's token for that axis.
Because this resolves from the file on every spawn, the pin is durable across every respawn (recovery, `/updatefirstmate`, restart) exactly like the harness axis itself - e.g. `config/secondmate-harness` containing `claude opus` keeps a secondmate pinned to Opus even if the primary's own default model later changes.
This is secondmate-only: crewmate/scout model resolution is untouched by this file.

## Inheritable config

`config/crew-dispatch.json`, `config/crew-harness`, and `config/backlog-backend` are inherited; `config/secondmate-harness` is not.
The primary pushes its declared inheritable config down into each secondmate home's `config/` - at secondmate spawn, on the bootstrap secondmate sweep, and through `bin/fm-config-push.sh` (fm-session-start) - so a secondmate's OWN crewmates, dispatch profiles, and backlog backend use the primary's settings (primary `config/crew-harness=codex` makes a secondmate's crewmates spawn on codex too).
Inheritance copies the literal `config/crew-harness` file, so for a secondmate's own crewmates to run on the primary's crewmate harness the captain must set `config/crew-harness` to a concrete adapter name, such as `codex`.
If `config/crew-harness` is unset or `default`, there is no concrete value to inherit, so the secondmate's own crewmates fall back to the secondmate's own/detected harness rather than the primary's effective crewmate harness.
Inheritance copies `config/crew-dispatch.json`, so secondmates apply the same best-fit dispatch profile behavior for their own crewmates.
Inheritance also copies `config/backlog-backend`, so a primary opt-out with `manual` makes secondmates hand-edit too.
When the file is absent, every home uses the default tasks-axi backend path independently.
The mechanism is generic over a single declared list (`fm-config-inherit-lib.sh`), primary-authoritative (re-pushed every convergence, mirroring absence), and easy to extend; `config/secondmate-harness` is deliberately excluded because secondmates never spawn secondmates.
When changing inherited config mid-session, prefer `bin/fm-config-push.sh` over a full bootstrap if tracked-file sync and reread nudges are not needed.
It reports `pushed`, `unchanged`, `skipped`, or `error` for each declared item in each live secondmate home; skipped non-ignored items are warnings and real copy/remove errors make the command exit non-zero.

## Adapters: mechanics vs knowledge

Each adapter splits into mechanics and knowledge.
The mechanics (launch command, autonomy flag, turn-end hook) live in `bin/fm-spawn.sh`; the knowledge you need while supervising (busy signature, exit, interrupt, dialogs, quirks, skill invocation, resume) lives in the agent-only `harness-adapters` skill.
**Never dispatch a crewmate or secondmate on an unverified adapter.**
If `config/crew-harness` or `config/secondmate-harness` names an unverified one, tell the captain and fall back to your own harness until it is verified.
If the captain asks for a new harness, load `harness-adapters`, verify it empirically with a trivial supervised task, then commit the script and knowledge changes.
Load `harness-adapters` before any spawn, recovery, trust-dialog handling, harness-specific skill invocation, interrupt, exit, resume, or adapter verification.

## Spawn

```sh
bin/fm-spawn.sh <id> projects/<repo>             # uses the active crewmate harness only when no crew-dispatch.json is active
bin/fm-spawn.sh <id> projects/<repo> --harness codex   # explicit per-task harness override
bin/fm-spawn.sh <id> projects/<repo> codex       # per-task harness override
bin/fm-spawn.sh <id> projects/<repo> grok        # per-task harness override
bin/fm-spawn.sh <id> projects/<repo> --harness codex --model gpt-5.5 --effort high   # explicit profile axes
bin/fm-spawn.sh <id> projects/<repo> --backend tmux   # explicit runtime backend; tmux is the verified reference backend
bin/fm-spawn.sh <id> projects/<repo> --backend herdr  # experimental herdr backend (docs/herdr-backend.md); version-gates at spawn
bin/fm-spawn.sh <id> projects/<repo> --scout     # scout task; records kind=scout in meta
bin/fm-spawn.sh <id> --secondmate                 # launch a registered persistent secondmate in its home
bin/fm-spawn.sh <id> <firstmate-home> --secondmate   # launch or recover an explicit secondmate home
bin/fm-spawn.sh <id1>=projects/<repo1> <id2>=projects/<repo2> [--scout]   # batch: one call, several tasks
```

Dispatch several tasks in one call by passing `id=repo` pairs instead of a single `<id> <project>`; each pair is spawned through the same single-task path, shared `--scout`, `--harness`, `--model`, `--effort`, and `--backend` flags apply to all, and the looping happens inside the script so you never hand-write a multi-task shell loop.
If one pair fails, the rest still run and the batch exits non-zero.
When `config/crew-dispatch.json` exists, include a shared `--harness` for every crewmate or scout batch after consulting the dispatch rules.

The script resolves the harness (`fm-harness.sh crew` for crewmate/scout tasks only when `config/crew-dispatch.json` is absent, `fm-harness.sh secondmate` for `kind=secondmate`), resolves the runtime backend (`--backend`, then `FM_BACKEND`, then `config/backend`, then runtime auto-detection - the runtime firstmate itself is executing inside - then `tmux`), owns the verified launch templates, resolves the project's delivery mode (`fm-project-mode.sh`) for ship/scout tasks, and records `harness=`, `model=`, `effort=`, `kind=`, `mode=`, and `yolo=` in the task's meta; only a non-default runtime backend is recorded as `backend=` because absent means tmux.
A non-flag third argument containing whitespace is treated as a raw launch command (only for verifying new adapters).
When `config/crew-dispatch.json` exists, the script refuses crewmate or scout launches without an explicit harness because firstmate must have already resolved the profile choice at intake.
When `--model` or `--effort` is omitted, the corresponding meta value is `default` and no launch flag is passed for that axis, except that a `kind=secondmate` spawn can fill the omitted axis from the optional tokens in `config/secondmate-harness`.
For `kind=secondmate`, the same script launches in the registered or explicit firstmate home instead of running `treehouse get` for a project, records `home=` and `projects=`, and uses the charter brief as the launch prompt.

For ship and scout tasks, the script creates the runtime endpoint (a tmux window by default, or a herdr tab/pane when `backend=herdr`), runs `treehouse get`, waits for the worktree subshell, asserts the resolved worktree is a genuine isolated worktree distinct from the primary checkout (aborting the spawn otherwise, to prevent the worktree tangle; fm-supervise-depth), installs the turn-end hook, records `state/<id>.meta`, and launches the agent with the brief.
For grok, the turn-end hook is one firstmate-owned global hook under `$GROK_HOME/hooks/`, or `~/.grok/hooks/` when `GROK_HOME` is unset, activated only when the worktree holds the per-task `.fm-grok-turnend` token pointer that matches `state/<id>.grok-turnend-token`; teardown removes the pointer and token.
For `kind=secondmate`, the script creates the same kind of runtime endpoint but starts directly in the persistent home.
Before launching a secondmate, the script fast-forwards its home worktree to firstmate's own current default-branch commit, so a freshly spawned or recovery-respawned secondmate always starts on firstmate's current version.
This is a purely local fast-forward of tracked files - never a fetch from origin, and never touching the gitignored operational dirs - so the secondmate's backlog, projects, and any prior in-flight work are untouched; a dirty, diverged, or in-flight home is left as-is and launches unchanged.
If that pre-launch fast-forward is skipped, `fm-spawn.sh` prints a concise warning to stderr and still launches the secondmate from its unchanged checkout.
The spawn also propagates the primary's declared inheritable config (see above) into the secondmate home's `config/`; this is a separate gitignored-file copy from the tracked-files fast-forward and a primary with no inheritable config set is a no-op.
No nudge is needed at spawn because the agent reads `AGENTS.md` fresh on launch.
For already-live secondmates, use `bin/fm-config-push.sh` when only this inherited config needs to be pushed.
Project worktrees start at detached HEAD on a clean default branch; ship briefs tell the crewmate to create its branch, while scout briefs keep the worktree scratch.
After spawning, peek the endpoint to confirm the crewmate is processing the brief and handle any trust dialog with `harness-adapters`.
Add the task to `data/backlog.md` under In flight (fm-backlog).
