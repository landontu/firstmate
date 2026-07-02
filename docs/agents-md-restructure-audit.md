# AGENTS.md restructure — line audit

Acceptance test for the 2026-07 progressive-disclosure split (891-line always-loaded root →
153-content-line core + 7 new on-demand skills): **every deleted line lands in a branch OR is a
kept invariant**. The commit parent of this change is 34e2472 (#186, the experimental herdr
runtime backend). Line numbers in the main table reference the 889-line AGENTS.md at 309f269
(#183, the runtime-backend interface, one commit earlier); the #186 delta on top of it is small
and audited separately in "#186 herdr delta" below.

Legend: **core** = kept in the new AGENTS.md (verbatim or compressed with all facts preserved);
**skill** = moved to the named `.agents/skills/*/SKILL.md`; **both** = invariant kept in core with
the depth in the skill (the settled belt-and-suspenders rule); **dropped** = deliberately dropped,
with the reason.

## Old file → destinations

| Old lines | Content | Destination |
|---|---|---|
| 1–12 | Preamble: identity, address-as-captain, nautical voice | **core** (verbatim; line 5 reworded — the file is no longer the *entire* job description — and the line-12 pointer renumbered to section 6) |
| 16–21 | Only point of contact; delegate everything; secondmate = same architecture | **core** §1 (compressed to 3 lines, all facts kept) |
| 23–27 | Hard-rule header + rule 1 (never write to a project) | **core** §1 (verbatim) |
| 28 | The six sanctioned write exceptions, itemized | **both**: catalog verbatim in `fm-deliver` ("sanctioned-write exception catalog"); core keeps the one-line summary + pointer |
| 29 | All exceptions are fast-forward / guarded / never force | **core** §1 (verbatim) |
| 30 | Project AGENTS.md maintenance is not an exception | **skill** `fm-project-setup` + restated in `fm-deliver` catalog |
| 31–32 | Rule 2 (never merge without captain's word; yolo relaxation) | **core** §1 (verbatim; "never merge a red PR even under yolo" promoted here from old line 501) |
| 33–34 | Rule 3 (never tear down unlanded; no --force) | **core** §1 (verbatim) |
| 35–36 | Full "landed" definition; `pr=` lookup/fallback | **both**: verbatim in `fm-deliver` (Ship teardown); core keeps "uncommitted never landed" + refusal = stop-and-investigate + pointer |
| 37 | Use `fm-pr-merge.sh` for every merge | **core** §1 (compressed) + `fm-deliver` (verbatim) |
| 38 | Uncommitted changes are never landed | **core** §1 |
| 39 | Scout carve-out | **core** §1 (compressed) + `fm-deliver` (Scout tasks) |
| 40–44 | Rules 4 (crewmates never address captain) and 5 (report faithfully) | **core** §1 (verbatim) |
| 46–56 | Repo-self-write rules: free write to own repo; shared tracked material list; delegate when fleet live; tracking principle; terse commits; behind the gate; no co-author | **core** §1 (compressed to 5 lines; every fact kept: the material list, the delegate-when-in-flight rule, fleet-empty direct edits, single-thread rationale, shared-template + gitignore principle, terse messages, pipeline+merge rule, no agent co-author) |
| 60–64 | `FM_HOME` / `FM_STATE_OVERRIDE` / `FM_ROOT_OVERRIDE` semantics | **skill** `fm-session-start` (verbatim) |
| 66–108 | Full directory/state-file tree (incl. `config/backend` and the `backend=` meta key from #183) | **skill** `fm-session-start` (verbatim; internal "(section N)" cross-refs rewritten to skill names); core §2 keeps a 2-line layout essentials summary + pointer |
| 110–111 | Task-id slug + tmux-backend `fm-<id>` window naming | **core** §2 (verbatim) |
| 113–116 | Bootstrap: detect→consent→install; never install unapproved | **both**: core §2 (compressed) + `fm-session-start` (verbatim) |
| 118–157 | `fm-bootstrap.sh` procedure, fleet sync, secondmate sweep, config propagation, `fm-config-push.sh`, full diagnostic catalog (MISSING/NEEDS_GH_AUTH/TANGLE/CREW_HARNESS_OVERRIDE/CREW_DISPATCH/FLEET_SYNC/SECONDMATE_SYNC/TASKS_AXI/NUDGE_SECONDMATES/FMX), timeout | **skill** `fm-session-start` (verbatim) |
| 159–164 | Read projects.md / secondmates.md / captain.md at start | **skill** `fm-session-start` (verbatim); core §2 mentions the registries in layout essentials |
| 166 | No dispatch until tools present + gh auth good | **core** §2 (verbatim) + `fm-session-start` |
| 167–168 | gh-axi / chrome-devtools-axi / lavish-axi; don't memorize flags | **core** §2 (verbatim) |
| 169–170 | Captain harness override → crew-harness; standing preference → crew-dispatch.json | **skill** `fm-session-start` (verbatim, pointing at `fm-dispatch`) |
| 174–176 | Crewmates default to your harness; `fm-harness.sh` resolution | **both**: core §3 (default-to-yours) + `fm-dispatch` (verbatim) |
| 177 | Verified adapter names | **core** §3 (verbatim) + `fm-dispatch` |
| 179–217 | Dispatch-profile file, schema, best-fit selection, explicit-harness enforcement | **skill** `fm-dispatch` (verbatim); core §3 keeps the consult-at-intake + fm-spawn-refuses invariant |
| 219–224 | Precedence list | **both**: core §3 (one-line) + `fm-dispatch` (verbatim) |
| 226–230 | Never select unverified; scripts don't parse rules | **both**: core §3 + `fm-dispatch` (verbatim) |
| 232–241 | Per-harness profile axes + invalid-effort handling | **skill** `fm-dispatch` (verbatim) |
| 243–256 | Secondmate harness / model / effort pinning | **skill** `fm-dispatch` (verbatim) |
| 258–267 | Inheritable config mechanism | **skill** `fm-dispatch` (verbatim) |
| 269–270 | Adapter mechanics vs knowledge split | **skill** `fm-dispatch` (verbatim) |
| 271–274 | Never dispatch on unverified; new-harness verification; load harness-adapters before any spawn/recovery/etc. | **both**: core §3 (bold invariant + load-before-spawn) + router row (full trigger list) + `fm-dispatch` (verbatim) |
| 278–298 | Recovery checklist (10 steps, incl. the backend-endpoints step-4 wording from #183) | **skill** `fm-session-start` (verbatim) |
| 300–301 | Restart is a non-event; truth lives in each task's backend live-task inventory, not conversation memory | **core** §2 (verbatim) |
| 305–317 | Projects flat under projects/; data/projects.md registry format + upkeep | **skill** `fm-project-setup` (verbatim); core §5 keeps mode-in-registry-line fact |
| 319–328 | data/secondmates.md format; scope/projects fields; load secondmate-provisioning triggers | **skill** `fm-dispatch` (registry + routing, verbatim); the provisioning trigger list lives in the router row. The old "that reference owns home leases, …" content summary is **dropped**: the same list is the `secondmate-provisioning` skill's own frontmatter description, so it survives at the load site |
| 330–333 | Secondmate idle-by-default contract | **both**: core §3 (one-line invariant, kept inline because `secondmate-provisioning` names AGENTS.md authoritative for it) + `fm-dispatch` (verbatim) |
| 335–340 | Backlog handoff on creation | **skill** `fm-dispatch` (verbatim) |
| 342–364 | Project memory ownership | **skill** `fm-project-setup` (verbatim) |
| 366–372 | Delivery modes + yolo flag (choose at add) | **both**: core §5 (all three modes + yolo default-off + default-at-add, compressed) + `fm-project-setup` (verbatim) |
| 374–393 | Clone / create / initialize procedures | **skill** `fm-project-setup` (verbatim) |
| 397–408 | Intake: resolve the project first (5 signals) | **both**: core §3.1 (compressed, all 5 signals) + `fm-dispatch` (verbatim) |
| 410–423 | Intake: secondmate scope routing, fm-send marker contract, no-bypass rule | **both**: core §3.2 (compressed: scope routing, local-only stays, status-file answer path) + `fm-dispatch` (verbatim, incl. the marker contract, captain-window carve-out, no-direct-crewmate rule, new-secondmate handoff) |
| 425–428 | Classify shape (ship/scout) | **both**: core §3.3 + `fm-dispatch` (verbatim) |
| 430–436 | Classify readiness; coarse dependency judgment | **both**: core §3.4 + `fm-dispatch` (verbatim) |
| 438 | Write the brief per the brief contract | **core** §3.5 |
| 442 | Load harness-adapters before spawning/recovering | **core** §3.6 + router |
| 444–459 | fm-spawn command forms (incl. `--backend`) + batch semantics (shared `--backend` flag) | **both**: core §3.6 (one-line summary of forms) + `fm-dispatch` (verbatim) |
| 461–476 | Spawn internals (harness + runtime-backend resolution chain, meta fields incl. the non-default-only `backend=` rule, worktree assertion, grok hook, secondmate ff + config push, detached HEAD) | **skill** `fm-dispatch` (verbatim) |
| 477–478 | Peek after spawn; add to backlog In flight | **core** §3.6 (verbatim) + `fm-dispatch` |
| 482–486 | Supervise: steer via one-line fm-send; secondmate charter escalation + status-file answer path | **both**: core §4 (steer one-liners) and §3.2 (answer path); charter-escalation sentence verbatim in `fm-dispatch` |
| 488–503 | Delivery modes divergence + yolo mechanics + review-diff helper + merge FYI | **both**: core §5 (modes, yolo, FYI, compressed) + `fm-deliver` (verbatim; never-red-PR also promoted to core §1) |
| 505–528 | Validate stage (no-mistakes wrapper, crew-state semantics, run-step states, self-fix red flag) | **skill** `fm-deliver` (verbatim) |
| 530–534 | PR ready signal + fm-pr-check + what to tell the captain | **both**: core §5 (compressed) + `fm-deliver` (verbatim) |
| 535 | Custom `state/<id>.check.sh` contract | **both**: `fm-deliver` (inline at PR ready, where the authoring moment fires, verbatim + pointer) + `fm-supervise-depth` (verbatim) |
| 537–539 | "Merge it" = approval; yolo merge; helper flags | **both**: core §5 + `fm-deliver` (verbatim) |
| 541–557 | Ship teardown, landed rules, fork case, fleet-sync-after, backlog Done update | **skill** `fm-deliver` (verbatim); core §1 rule 3 keeps the invariant |
| 559–566 | Secondmate teardown | **skill** `fm-deliver` (verbatim) |
| 568–575 | Scout task divergence | **both**: core §5 (scout done line) + `fm-deliver` (verbatim) |
| 577–580 | Promotion | **skill** `fm-deliver` (verbatim); core §5 names the trigger |
| 584–586 | Watcher backbone; zero tokens | **core** §4 (verbatim) |
| 587–597 | Always-on wake triage internals (absorb-when-provably-working, classifier lib, afk one-shot) | **skill** `fm-supervise-depth` (verbatim) |
| 598–599 | Drain wakes at start of every wake/recovery turn | **core** §4 (verbatim) |
| 600–621 | Keep-one-live-cycle, standalone-never-bundled, re-arm-after-fire, no-blind-turns, singleton safety, --restart, no-pkill, silence | **both**: core §4 (every invariant, compressed: one cycle, tracked background only, standalone, status-line semantics, re-arm on WAKE REASON, no blind turns, home-scoped restart, no broad pkill, intentional silence) + `fm-supervise-depth` (full mechanics verbatim) |
| 623–629 | Commands block (5 commands) | **core** §4 (verbatim) |
| 631–640 | On-wake cheapest-first steps 1–5 | **core** §4 (compressed, all five wake kinds and the crew-state-not-tail rule kept) |
| 642 | X follow-up on terminal wake | **core** §8 (verbatim) + `fm-supervise-depth` |
| 644–645 | Heartbeat backoff; checks before signals | **skill** `fm-supervise-depth` (verbatim) |
| 647–652 | Backend live-task inventory is the ground truth (tmux by default); secondmate idle-pane exception | **both**: core §4 (2 lines) + `fm-supervise-depth` (verbatim) |
| 654–663 | Liveness guard / beacon / banner | **skill** `fm-supervise-depth` (verbatim); core §4 keeps "banner = alarm, act on remediation" |
| 665–670 | Worktree-tangle guard | **skill** `fm-supervise-depth` (verbatim); core router carries the WORKTREE TANGLE trigger |
| 671–675 | No foreground-blocking with work in flight | **both**: core §4 (one line) + `fm-supervise-depth` (verbatim) |
| 677–679 | Token discipline (crew-state first, 40-line peeks, context-% not actionable) | **skill** `fm-supervise-depth` (verbatim); core keeps peek default + silence rule |
| 681–694 | Away-mode stub + inline facts | **both**: core §4 (trigger list + all five "must survive without a loaded skill" facts, compressed: 0x1f marker, marked = stay-afk escalation, daemon owns watcher, unmarked = captain back with flush + re-arm, approval authority unchanged). "Re-invoking /afk refreshes the flag" and "bias ambiguous toward exit" are **dropped from core**: both are stated verbatim inside the `afk` skill (lines 55, 58), which the kept trigger list loads |
| 695–698 | Stuck-crewmate recovery pointer | **core** §4 wake step 2 + router row (full trigger list preserved) |
| 700–721 | Escalation & captain etiquette | **core** §6 (verbatim; the PR-URL sentence lightly compressed, both rules kept) |
| 723–741 | Backlog format + re-evaluate Queued | **both**: core §3 (queue role, update-on-every-event, re-evaluate rule) + `fm-backlog` (verbatim incl. the format block) |
| 743–756 | tasks-axi backend, opt-out knob, byte-exact contract, pruning | **skill** `fm-backlog` (verbatim) |
| 757–767 | Operation-to-verb map | **skill** `fm-backlog` (verbatim) |
| 769–788 | Crewmate briefs (scaffold contract, per-mode done, scout, charter, sparse status protocol) | **skill** `fm-brief` (verbatim); core §3.5 keeps scaffold-is-the-contract |
| 790–794 | Self-update | **core** §7 (verbatim) |
| 796–803 | §13 trigger list (harness-adapters, stuck-crewmate-recovery, secondmate-provisioning, fmx-respond) | **core** §9 router — each of the four rows keeps its full original trigger list |
| 805–808 | X mode intro; inert until opt-in | **both**: core §8 (one line) + `fm-session-start` (verbatim) |
| 810–814 | Activation (.env token semantics) | **skill** `fm-session-start` (verbatim) |
| 816–822 | Mechanism (bootstrap artifacts, check shim, additive layer) | **skill** `fm-session-start` (verbatim) |
| 824–837 | Cadence (30s, transition restart, afk carve-out) | **skill** `fm-session-start` (verbatim) |
| 839–841 | On x-mention load fmx-respond; x-mode-error = config blocker | **core** §8 (verbatim) + `fm-session-start` |
| 842–854 | Answering behavior (drain-all, classify, act, ack-first, guardrail, dismiss, public-safety, text-file) | **skill** `fmx-respond` — already covered verbatim-equivalent by its existing text (drain: its Procedure intro; classify/act/ack: its case list and steps 2b–2d; dismiss: step 2e-skip; safety: "The reply is public"; text-file: step 2e) |
| 855 | `--image` contract for replies | **skill** `fmx-respond` (added in this change: "Length limits and images") |
| 857–860 | Completion follow-up flow, fm-x-link meta fields, terminal-wake trigger | **both**: core §8 (trigger) + `fmx-respond` (Completion follow-up section) + `fm-supervise-depth` (terminal-wake line); meta fields also in `fm-session-start` layout |
| 861 | connector/followup endpoint, 24h binding, exactly one follow-up | **skill** `fmx-respond` (endpoint name added in this change) |
| 862 | `--image` on follow-up | **skill** `fmx-respond` (added) |
| 863–866 | Honest failed follow-up; past-window skip; public-safety bar; dry-run loop | **skill** `fmx-respond` (already covered in its Completion follow-up + Dry-run sections) |
| 868–872 | Conversations (in_reply_to context, untrusted thread, worthiness, relay-owned caps) | **skill** `fmx-respond` (already covered) |
| 874–875 | Concise by default, no hand-numbered threads | **skill** `fmx-respond` (already covered in Voice) |
| 876–878 | Auto-split mechanics, FMX_X_REPLY_MAX_CHARS / FMX_X_THREAD_MAX knobs, thread payload shape | **skill** `fmx-respond` (knobs + payload added in this change) |
| 879–880 | No image for prose; thread attaches image to opener only | **skill** `fmx-respond` (added) |
| 882–883, 885–889 | Dry-run behavior for reply/dismiss/followup | **skill** `fmx-respond` (already covered; `endpoint` marker sentence added) |
| 884 | Dry-run image marker `{media_type, bytes, source_path}` | **skill** `fmx-respond` (added) |

## #186 herdr delta (309f269 → 34e2472)

#186 changed 9 hunks of AGENTS.md (net +2 lines, 889 → 891). Every changed/added line lands as
follows (all skill placements verbatim from 34e2472, with "(section N)" cross-refs rewritten to
skill names as elsewhere):

| Old lines (34e2472) | Content | Destination |
|---|---|---|
| 80 | `config/backend`: tmux is the verified reference backend, herdr is a second, experimental backend (docs/herdr-backend.md) | **skill** `fm-session-start` (layout tree) |
| 94 | `<id>.meta`: backend= absent means tmux, the verified reference backend; herdr records herdr_session=, herdr_workspace_id=, herdr_tab_id=, herdr_pane_id= | **skill** `fm-session-start` (layout tree) |
| 112 (added) | herdr task tab labeled `fm-<id>`; recorded `window=` is `<herdr-session>:<pane-id>` | **core** §2 (verbatim) |
| 287–288 | Recovery step 4: check recorded backend endpoints; don't sweep tmux windows or herdr tabs of other homes | **skill** `fm-session-start` (recovery checklist) |
| 417 | fm-send: pass an explicit backend target only when intentionally targeting an endpoint outside this home | **skill** `fm-dispatch` (scope routing) |
| 451–452 | `--backend tmux` comment reworded + `--backend herdr` example line (added) | **skill** `fm-dispatch` (command forms) |
| 469, 471 | Spawn creates the runtime endpoint (tmux window by default, herdr tab/pane when backend=herdr); secondmate gets the same kind of runtime endpoint | **skill** `fm-dispatch` (spawn internals) |
| 478 | Peek the endpoint after spawn | **skill** `fm-dispatch` + **core** §3.6 ("peek the endpoint") |
| 650 | Ground truth: herdr is the one other implemented, experimental backend today (docs/herdr-backend.md) | **both**: core §4 (verbatim) + `fm-supervise-depth` |

Core §2 also keeps #186's backend-selection summary (`--backend` → `FM_BACKEND` → `config/backend`
→ tmux; herdr as the second, experimental backend) on lines 55–56.

## Router reconciliation (session-1 v1 vs shipped)

Per the spec's reconcile-at-ship note, the shipped section-9 router was diffed against the
session-1 v1 draft (recovered from the design-session transcript) and against the final §1c table
in `revive-doc-restructure/report.md`:

- v1 → §1c renamed the new branches with the settled `fm-` prefix and hardened the
  `fm-supervise-depth` trigger from "watcher/guard/tangle anomaly" to concrete signals.
  Same rows otherwise; **no trigger dropped**.
- Deliberate deviation from §1c: the `state/.subsuper-inject-wedged` sub-trigger was removed from the
  `fm-supervise-depth` row. That marker's playbook lives in the `afk` skill, and the next row already
  routes `any state/.subsuper-* marker → afk`; routing it to `fm-supervise-depth`, whose body carries no
  guidance on the marker, was a dead route. The row keeps its WORKTREE TANGLE, watcher-down, and
  daemon-classifier-escalation triggers.
- The shipped router is §1c with two additive refinements: (1) the four pre-existing skills'
  rows carry their full original §13 trigger lists (harness-adapters' interrupt/exit/resume/verify
  set, stuck-crewmate-recovery's six symptoms, secondmate-provisioning's full verb list,
  afk's marker triggers) rather than §1c's abbreviations, so no existing trigger narrowed; and
  (2) §1c's "spawning a crewmate / scaffolding a brief → fm-brief" row is split — spawning routes
  to `fm-dispatch` (which owns the fm-spawn mechanics and profile flags) and brief scaffolding to
  `fm-brief` — both moments still route, nothing dropped.

## Net shape

- Core: 891 lines → 192 (153 non-blank; the settled ~145-line budget counted content lines).
- New skills: `fm-session-start`, `fm-dispatch`, `fm-project-setup`, `fm-brief`, `fm-backlog`,
  `fm-supervise-depth`, `fm-deliver`; `fmx-respond` gained the §14 image/length/dry-run details it
  lacked. Existing skills keep their names, per the settled naming decision.
- All five prime directives, captain etiquette, the lifecycle spine, the supervision invariant,
  the delivery modes, and the expanded trigger-router remain always-loaded; a firstmate that never
  loads a branch still observes every hard rule.
