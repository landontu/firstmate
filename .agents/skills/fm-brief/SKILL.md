---
name: fm-brief
description: Agent-only reference for firstmate crewmate briefs. Load when scaffolding or hand-adjusting a brief for a ship, scout, or secondmate task, before spawning or seeding. Owns the fm-brief.sh scaffold contract, per-mode definition of done, the scout report contract, the secondmate charter rules, and the sparse status-reporting protocol.
user-invocable: false
---

# fm-brief

Scaffold with `bin/fm-brief.sh <id> <repo-name>` - it writes `data/<id>/brief.md` with the standard contract (branch setup, status-reporting protocol, push/merge rules, definition of done) and all paths filled in.
The ship-brief Setup opens with a worktree-isolation assertion ahead of the branch step: the crewmate confirms it is in its own treehouse worktree, not the primary checkout, and stops with `blocked: launched in primary checkout, not an isolated worktree` if not - the upstream half of the worktree-tangle guard (fm-supervise-depth).
For a ship task the definition of done is shaped by the project's delivery mode (fm-project-setup): `no-mistakes` stops after the implementation commit, then firstmate triggers the harness-appropriate no-mistakes validation pipeline; `direct-PR` has the crewmate push and open the PR itself, and `local-only` has it stop at "ready in branch" for firstmate to review and merge locally.
The no-mistakes brief points to no-mistakes' version-matched guidance and keeps only firstmate-specific wrapper rules for `ask-user` escalation, `--yes` avoidance, and the CI-green done line.
The scaffold reads the mode via `fm-project-mode.sh`, so you do not pass it.
Ship briefs also include the project-memory contract: run `bin/fm-ensure-agents-md.sh` when the project already has agent-memory files or when the task produced durable project-intrinsic knowledge, then record proportionate learnings in `AGENTS.md`.

For scout tasks add `--scout`: the scaffold swaps the definition of done for the report contract (findings to `data/<id>/report.md`, no branch, no push, no PR) and declares the worktree scratch; scout is mode-agnostic.
Scout briefs do not include the project-memory step, because their deliverable is a report rather than a committed project change.

For secondmates use `bin/fm-brief.sh <id> --secondmate <project>...`.
The scaffold writes a charter brief instead of a task brief.
Set `FM_SECONDMATE_CHARTER='<charter>'` to fill the charter text and `FM_SECONDMATE_SCOPE='<scope>'` when the routing scope differs.
If you scaffold without `FM_SECONDMATE_CHARTER`, replace the `{TASK}` placeholder before seeding.
Keep the charter focused on persistent responsibility, available project clones, escalation back to the main firstmate status file, and the idle-by-default contract: reconcile only its own in-flight work and then wait, never self-initiating a survey or audit.
Preserve the requests-from-main-firstmate contract in the charter: marked requests return via status or a doc pointer, while unmarked direct captain messages stay conversational.
Before seeding, loading, handing backlog to, or launching a secondmate home, load `secondmate-provisioning`.

The status-reporting protocol is intentionally sparse: crewmates append status only for supervisor-actionable phase changes or `needs-decision`/`blocked`/`done`/`failed`, because every append wakes firstmate.
For any generated brief that still contains `{TASK}`, replace it with a clear task description, acceptance criteria, and any constraints or context the crewmate needs before spawning or seeding.
Adjust the other sections only when the task genuinely deviates from the standard ship-a-new-PR shape (e.g. fixing an existing external PR); the scaffold is the contract, not a suggestion.
