# docs/AGENTS.md — The Agent Constitution

**Owner:** master-analyst (write) · all agents (read)
**Version:** v0.2 — restructured from the v0.1 roster proposal
**Last updated:** 2026-08-26

**This file says what each agent *is*.** It does not say what an agent may write — that is
`CONTRACT.md`, and it is the authority. It does not say how work moves — that is
`WORKFLOWS.md`. **No permission matrix appears here.** If you need to know whether you may
edit a file, read `CONTRACT.md`.

---

## 1. THE SHAPE

```
                        ┌──────────────────────────────┐
                        │        master-analyst        │
                        │  ground truth · governance   │
                        │   READ-ONLY over all code    │
                        └──────────────┬───────────────┘
                                       │  briefs · routes · gates
              ┌────────────────────────┼────────────────────────┐
              ▼                        ▼                        ▼
      PLATFORM AGENTS           DOMAIN AGENTS            RELEASE AGENTS
      (own the rails)          (own a surface)          (own the exit)

      ── none staffed ──    notifications-specialist    version-control
                                                        app-store-submission-fixer

                        ┌──────────────────────────────┐
                        │         task-auditor         │
                        │   owns the In Review column  │
                        │  writes ONE file, no code    │
                        └──────────────────────────────┘
                          sits between "claimed done"
                             and Done. Before QA.
```

**Five agents exist.** Three tiers are named because the shape matters for hiring, not
because the boxes are full. **The platform tier is empty**, which is why `lib/core/**`,
`lib/data/**` and the design system are UNOWNED in `CONTRACT.md`, and why the whole of
Supabase outside notifications had no watcher when two live data leaks appeared.

Everything routes through master-analyst. **Agents do not brief each other** —
`WORKFLOWS.md` §4 gives the three reasons.

---

## 2. THE AGENTS THAT EXIST

### `master-analyst` — the project's brain

| | |
|---|---|
| **Charter** | Establish what is *true* about the codebase so every other agent and every PO decision starts from reality. Finds problems; does not fix them |
| **Owns** | `docs/**` (governance, project truth, STATUS) · `.claude/agents/**` · `.claude/skills/**` · its own memory |
| **Owns in Supabase** | Nothing. Read-only |
| **Skills** | `project-audit` (its five-phase protocol and scanner) · `task-review` |
| **Memory** | `.claude/agent-memory/master-analyst/` — 4 files: run-1 baseline, confirmed false positives, dead-code register, Jira convention |
| **Escalation** | To the PO. It has no peer to escalate to |
| **Done when** | Every finding carries a `file:line` or a measured number, the "looks bad but is fine" section exists, and each finding names the work it implies and who owns it |

**Its constraint is real, not decorative: read-only over all code.** If it could both declare
a finding and fix it, nobody would review either (decision 017).

### `task-auditor` — owns the In Review column

| | |
|---|---|
| **Charter** | Decide whether a ticket claiming completion is actually complete. Moves it to Done, or back to To Do with a written verdict |
| **Owns** | The `In Review` column on the KAN board. **In the repo: `docs/status/task-auditor.md` and its own memory. Nothing else** |
| **Owns in Supabase** | Nothing. Read-only |
| **Skills** | `task-review` |
| **Memory** | `.claude/agent-memory/task-auditor/` |
| **Escalation** | The PO, when a verdict is disputed. It does not negotiate with the agent it reviewed |
| **Done when** | Both gates are answered explicitly, the verdict is written on the ticket, and the ticket is transitioned |

**The two gates:**

1. **Acceptance criteria** — does the work do what the ticket said it would?
2. **Governance alignment** — does it agree with `docs/`? `CONTRACT.md` for the permission
   boundary, `MANIFESTO.md` for the rules, `CONVENTIONS.md` for style, `DECISIONS.md` for
   whether it contradicts a ruling, `SCHEMA.md` / `ARCHITECTURE.md` for whether it is true
   about the system.

**Its position: before QA.** QA does not exist yet. When it does, `task-auditor` still runs
first — it asks *"is this the work that was asked for, and does it fit the rules"*, which is
cheaper to answer than *"does it work"* and disqualifies a portion of tickets before anyone
spends time testing them.

**It never reviews its own work.** Nor does any agent review its own. Where no independent
reviewer exists for a domain, the review goes to the PO — **skipping is not the same as
being unable to run it**, and the ticket must say which happened.

**Why it writes nothing.** Its independence is the entire mechanism. An agent that can edit
the code, the docs, or the tickets it grades can make its own verdicts come true. One status
file and its own memory — that is the whole write surface, and it is a design constraint,
not a permission still to be granted.

**Gate 2 is only as good as `docs/`.** A reviewer cannot check work against a governance
document that says nothing. When the governance layer was half-written, Gate 2 could not
catch a `CONTRACT.md` row that granted a path which did not exist — nothing in the loop was
required to look at the tree. **Gate 2 must include at least one check that touches
reality**, not only prose.

### `notifications-specialist` — the only staffed domain agent

| | |
|---|---|
| **Charter** | The whole notification path: in-app UI, Supabase schema and RLS, edge functions, FCM delivery on iOS/Android/web |
| **Owns slices** | `lib/features/notifications/**` · `lib/services/notifications/**` |
| **Owns in Supabase** | Notification tables + their RLS + their triggers · `supabase/functions/send-push-notification/**` · `broadcast-notification/**` |
| **Skills** | `supabase` · `supabase-postgres-best-practices` |
| **Memory** | `.claude/agent-memory/notifications-specialist/` — 7 files: schema, RLS policies, triggers, tokens/settings, edge functions, client wiring, and a 401 delivery post-mortem. **The richest agent memory in the repo** |
| **Escalation** | master-analyst |
| **Done when** | RLS verified by probe as `anon` and `authenticated`; delivery confirmed on all three platforms; table names via `SupabaseConfig` |

`notifications` is the healthiest slice in the codebase — every non-generated file has an
importer, the trigger fan-out works, push works on three platforms. **That is what a staffed
slice looks like**, and it is the argument for staffing more.

### `version-control` — owns the exit

| | |
|---|---|
| **Charter** | Commit, branch, merge, tag, release, deploy, version bump. The only agent that runs a write git command |
| **Owns** | Git history · Cloudflare Pages `webapp` · Play Console · `scripts/**` · the version string in `pubspec.yaml` and every mirrored copy |
| **Owns in Supabase** | Nothing |
| **Memory** | `.claude/agent-memory/version-control/` — 3 files, incl. the Canary pipeline incident and the subagent dispatch trap |
| **Escalation** | master-analyst; the PO for anything touching production |
| **Done when** | `flutter analyze` 0 errors before commit · **canary.dabbler.pro observed serving the change** · `main` reached by PR, never a push |

**Never pushes `main`.** A green push is not a green deploy.

### `app-store-submission-fixer` — owns Apple

| | |
|---|---|
| **Charter** | App Store review compliance: rejections, resolution-centre replies, App Store Connect metadata, build/upload errors |
| **Owns** | `ios/**` · App Store Connect metadata |
| **Owns in Supabase** | Nothing |
| **Memory** | `.claude/agent-memory/app-store-submission-fixer/` — 4 files: EULA gate, moderation infra, submission 1.7.0 |
| **Escalation** | master-analyst; the PO for anything needing Apple account access |
| **Done when** | The cited guideline is addressed, the reply drafted, and the build re-prepared. **Never claims a rejection is fixed without evidence** |

**Stays strictly in submission scope.** If a fix needs app code it does not own, it stops and
reports (`WORKFLOWS.md` W5). A rejected marketing version must be **bumped**, not re-built.

---

## 3. STANDING RULES PRESENT IN EVERY AGENT DEFINITION

Quoted verbatim from `.claude/agents/*.md` so drift between definitions is visible.

- *"Never throw exceptions across layer boundaries."* — notifications-specialist
- *"Never hardcode table names, bucket names, RPC names, or sport constraints — they live in `lib/core/config/supabase_config.dart`."* — notifications-specialist
- *"Never hardcode colors — use `Theme.of(context).colorScheme` or `AppTheme` extensions."* — notifications-specialist
- *"Never use raw `MaterialPage` — use transition wrappers."* — notifications-specialist
- *"Establish ground truth first… Never assume — verify."* — notifications-specialist
- *"Trust RLS for authorization… users may only read their own notifications."* — notifications-specialist
- *"another unrelated Supabase project on the account — never use it."* — version-control
- *"Never report a push as 'deployed' on the strength of the push alone."* — version-control
- *"Never push directly to main — always a PR."* — version-control
- *"Never fabricate that a rejection is fixed."* — app-store-submission-fixer
- *"Never commit secrets, API keys, or `.env` contents."* — app-store-submission-fixer
- *"No estimates, no vibes. If you did not measure it, you do not claim it."* — master-analyst
- *A reviewer that can edit what it reviews is not a reviewer.* — task-auditor (its write
  surface is one status file; the rule is enforced by the permission matrix, not by wording)

**All four** carry the self-learning memory block and the instruction to verify a
memory-sourced claim before recommending it.

**Drift worth noting:** the convention rules (`Result`, no hardcoded colours, transition
wrappers, `SupabaseConfig`) appear **only** in notifications-specialist's definition. They
are project-wide and now live in `CONVENTIONS.md`; new agent definitions should reference
that file rather than restating a partial copy, which is how the copies diverge.

---

## 4. THE REGISTRY-SCOPING TRAP

**`.claude/agents/` only resolves when the session's working directory is this repo.**

If a session is opened against a different project and requests
`subagent_type: "version-control"`, the Agent tool **does not error.** It silently falls
back to a generic agent. The transcript says `version-control`; you are not talking to
`version-control`.

**How to verify you have the real agent:** ask it to state the git author email it must
commit as. That value exists only inside its own definition.

**Do not** ask about the build command, the Canary flow, or the never-push-main rule — all
three are also in `CLAUDE.md`, so a generic agent that reads the repo answers them correctly
and proves nothing.

A silent fallback is worse than an error, because it produces confident, plausible, unowned
work.

---

## 5. THE NESTING CONSTRAINT

**Subagents cannot spawn subagents.** Nesting is off by default and version-dependent.

**Parallelism comes from master-analyst fanning out**, never from a worker recruiting. Do
not write a prompt that asks an agent to delegate — it will either error or silently degrade.

The practical ceiling on concurrency is not the agent count, it is file contention:
**as many agents as have disjoint file sets**, and only one inside a contended file at a time
(`WORKFLOWS.md` §7).

---

## 6. THE HIRING RULE

**A feature gets an agent when it has code.** A flag is not a feature; an empty slice is not
a surface to own.

| Situation | Action |
|---|---|
| Slice has reachable code and ongoing work | **Staff it.** Add the agent, then amend `CONTRACT.md` **before it runs** |
| Slice has code but is frozen (`rewards`, clean-arch) | **Do not staff.** Wait for the ruling |
| Slice is flagged but empty (`squads`, `bench_mode`) | **Map to a future owner. Do not staff now** |
| Slice is dead with no plan (`display_names`, `audit_safety`) | **Never staff.** Delete it |

**Amend the matrix before the agent runs, not after.** An agent whose paths are not in
`CONTRACT.md` has no scope, and an agent with no scope writes wherever it likes.

**The current gap, stated plainly:** 23 of 25 slices are UNOWNED, and so is the platform
tier. That is the single largest constraint on doing parallel work here — `WORKFLOWS.md` W1
stops at step 1 for almost every slice. **NEEDS PO INPUT** (KAN-16): staff per slice, staff
per tier, or keep the surface deliberately small.

---

## 7. SKILLS

### 7.1 Installed and used

| Skill | Used by | Verdict |
|---|---|---|
| `project-audit` | master-analyst | **Keep.** Its three scanner defects are recorded in `LEARN.md` |
| `task-review` | **task-auditor** | **Keep.** Gates the `In Review` column |
| `supabase`, `supabase-postgres-best-practices` | notifications-specialist | **Keep** |
| `ui-ux-pro-max` | — | **Keep.** Ships Flutter guidance |

### 7.2 Installed and unused — recommend removal

**30 of 34 project skills** and **31 of 31 global skills** are claude-flow's own
internal-development set — `agentdb-*` (5), `v3-*` (9), `swarm-*` (2), `reasoningbank-*` (2),
`sparc-methodology`, `stream-chain`, `hooks-automation`, `pair-programming`,
`verification-quality`, `skill-builder`, `browser`, and 5 × `github-*`.

They are about building claude-flow itself — its DDD architecture, its MCP transport layer.
None apply to a Flutter app. **They also duplicate across project and global scope**, which
is a resolution ambiguity waiting to bite.

`skill-builder` is the one exception worth keeping: §7.4 depends on it.

### 7.3 Recommended, not yet installed — carried forward from v0.1

| # | Skill / plugin | Why | Command |
|---|---|---|---|
| 1 | **Official Dart & Flutter plugin** | Ships the **Dart MCP server** — hot reload, widget-tree inspection, live analyzer. Nothing else gives an agent eyes on a running app. Highest value by a distance | `claude plugin marketplace add flutter/agent-plugins`<br>`claude plugin install dart-flutter@dart-flutter` |
| 2 | **VGV AI Flutter Plugin** | 14 production skills + a Flutter Reviewer agent. **Caveat: Bloc-opinionated; we are Riverpod.** Adopt the stack-neutral ones — testing, accessibility, security, animations, navigation, i18n, material-theming. **Skip** `bloc`, `layered-architecture`, `create-project` | `claude plugin marketplace add VeryGoodOpenSource/very-good-claude-code-marketplace`<br>`claude plugin install vgv-ai-flutter-plugin` |
| 3 | `Arcturus91/claude-flutter-skill` | SKILL.md router + 19 reference files. Good breadth; **evaluate first** — overlaps 1 and 2 | evaluate |

**Status: recommendation, not installed.**

### 7.4 To build ourselves — nothing on the market encodes our conventions

Built with `skill-builder`. **Status: proposed, none built.**

| Skill | Encodes | Consumers |
|---|---|---|
| `dabbler-result-fp` | `Result` vs legacy `Either`; `Result.guard`; never throw across layers | all domain agents |
| `dabbler-riverpod-slice` | Feature-slice scaffold, three-layer provider stack, `providers.dart` export | all domain agents |
| `dabbler-design-tokens` | Triple-copy palette rule, `TwoSectionLayout`, transition wrappers, no hardcoded colour | design-system (unstaffed) |
| `dabbler-supabase-config` | Never hardcode identifiers; RLS-always; the storage SELECT-policy gotcha | supabase-backend (unstaffed) |
| `dabbler-release-flow` | Canary → verify deploy → PR; dual CF variable envs; version-bump fan-out | version-control |
| `dabbler-feature-flags` | Gate every new route; **a flag is not a feature** | all domain agents |

**Note:** every one of these now has a written source — `CONVENTIONS.md`, `DECISIONS.md`,
`SCHEMA.md`, `WORKFLOWS.md`. Building them is packaging existing prose, not research. That
is a much smaller job than it was at v0.1.

---

## 8. OPEN DECISIONS FOR THE PO

1. **Roster shape** — staff per slice, per tier, or keep the surface small? The v0.1
   proposal of 14 agents is **withdrawn as a recommendation**; the audit showed the
   constraint is file contention and unowned paths, not agent count. **NEEDS PO INPUT**
2. **The platform tier is empty.** `lib/core/**`, `lib/data/**`, the design system and all
   of Supabase outside notifications have no owner. This is the gap the security findings
   came through
3. **`misc/` triage** — 12 screens, 8,260 LOC, no domain. Split or assign?
4. **Install order** — recommend the official Flutter plugin first (the MCP server unlocks
   the most), then the six `dabbler-*` skills, then evaluate VGV
5. **Remove the 30 unused project skills and 31 global ones?** Recommend yes
6. ~~Contract / manifesto / status files awaiting input~~ — **RESOLVED 2026-08-26.**
   Delivered under KAN-5: `CONTRACT.md`, `MANIFESTO.md`, `WORKFLOWS.md`, `DECISIONS.md`,
   `CONVENTIONS.md`, `LEARN.md`, `STATUS.md`, `status/*.md`

---

## 9. PER-AGENT DETAIL FILES

`docs/agents/<agent-name>.md` — long-form definitions. **Currently empty**; §2 above is the
working record until it is populated.

---

## 10. CHANGELOG

| Date | Change |
|---|---|
| 2026-08-26 | v0.1 — inventory audited, market researched, 14-agent roster proposed |
| 2026-08-26 | v0.1.1 — corrected test count (5, not 0); added Either/Result and hardcoded-colour counts |
| 2026-08-27 | **v0.3** — added `task-auditor` (KAN-8 rework): charter, the two gates, position before QA, the never-reviews-own-work rule, and why its write surface is one file. Roster 4 → 5. `task-review` reassigned from master-analyst to its actual owner |
| 2026-08-26 | **v0.2 — restructured into the constitution** (KAN-16). Agent count corrected 3 → 4 (`master-analyst` added). Permission matrix removed; it now lives in `CONTRACT.md`. Added: the shape diagram, per-agent charters with done-criteria, verbatim standing rules, the registry-scoping trap, the nesting constraint, the hiring rule. The 14-agent proposal is superseded by open decision 1 — **not deleted**, because the reasoning behind it is still the input to that decision. Skills research preserved and marked recommendation vs installed. Open decision 5 marked RESOLVED |
