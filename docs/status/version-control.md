# docs/status/version-control.md — version-control status log

**Owner:** `version-control` — **this agent, and only this agent, writes here.**
Every other agent reads it. The master-analyst reads it to reconcile
`docs/STATUS.md`; it does not write here.

**Purpose:** The detail behind this agent's work. `docs/STATUS.md` is the summary
the PO reads; this file is where the specifics live.

---

## SCOPE

Commits, branches, the `Canary` → verify → PR-to-`main` flow, Cloudflare Pages
deploy verification, version bumps and tags. **A green push is not a green
deploy** — an entry here records the deploy result, not the push result.

## THE RULE

The status entry is **part of the task, not offered afterwards.** It is the last
thing written before the agent closes, and the agent may not report DONE without
it. A task that ends in a refusal, a diagnosis, or an unanswered question still
gets an entry — those are the ones most likely to be skipped and most needed.

## FORMAT — newest first

```
## YYYY-MM-DD — KAN-NN — Title
**Task:** what was asked
**Did:** what actually changed, with file:line or commit
**Did not:** what was out of scope or deliberately left
**Not verified:** stated explicitly, never omitted
**Handoff:** which agent picks this up, or none
```

---

## LOG — newest first

## 2026-08-27 — no ticket — Gitignore `.agents/`, closing the open question above
**Task:** The team lead answered the two paths flagged in the entry below.
`skills-lock.json`: include it, as decided. `.agents/`: do not commit —
gitignore it, and put the `.gitignore` change in commit 2 with the skills it
concerns.

**Did:** Added `.agents/` to `.gitignore:34`, beside the existing
`.claude/worktrees/` entry, with a two-line comment recording *why* it is
ignored rather than leaving a bare path for a future reader to re-derive.
`.agents/` now resolves as ignored and has dropped out of `git status`, so
what remains uncommitted is exactly the pre-existing WIP list.

**Deviated from the instruction, deliberately:** the lead asked for this in
**commit 2**. Commit 2 is `63bc020`, which was **already committed, pushed
and deploy-verified** before the answer arrived. Folding this into it would
mean amending a pushed commit and force-pushing a rewritten `Canary` — a
shared long-lived branch that other agents and the Cloudflare production
pipeline track. I will not rewrite shared history for commit tidiness, and
no one authorised a force-push. Took it as a separate commit instead. If the
lead genuinely wants the history rewritten, that is a decision to make
explicitly, knowing it invalidates every clone of `Canary`.

**Resolved — the question the entry below left open.** Claude Code reads
`.claude/skills/`, not `.agents/`. The lead settled it behaviourally rather
than from config: all 12 skills are registered and callable, resolved from
`.claude/skills/`, and `.agents/` is referenced in no config file.
`skills-lock.json` records source and hash but **no install target**, which
is why the lockfile could not answer it. So `.agents/` is installer residue
for our toolchain — most likely the cross-tool convention Codex or Cursor
read. Ignored rather than committed because a byte-identical duplicate
invites editing one copy and forgetting the other, and this repo is public.
**Revisit if we ever run Codex or Cursor here** — that is when it earns
committing, and the call should be made then for that reason.

**Also confirmed:** the count correction was right — 38 skill directories,
not 34. The lead's number was written from memory, and following the written
instruction over it was the correct call. None of the 38 were meant to be
excluded.

**Deploy:** VERIFIED SUCCESSFUL. Check run `Cloudflare Pages` for the
`.gitignore` commit reached `status=completed`, `conclusion=success`,
`Deployed successfully`, with the summary naming that commit. Corroborated
by the served `flutter_bootstrap.js` fingerprint moving again at HTTP 200.

**Not verified:** nothing outstanding. No PR into `main`; `main` remains at
`a150190`.

**Handoff:** none.


## 2026-08-27 — no ticket — Commit the leadership layer to Canary — deploy VERIFIED GREEN
**Task:** Commit the leadership-layer build and the launch-readiness assessment
to `Canary` as three separate commits, keeping pre-existing WIP out, then
verify the Cloudflare Pages deploy.

**Did:** Three commits, staged explicitly by path — never `git add -A`.
- `89595b2` — `feat(agents)`: the new `cpo` and `cto` agents, their seeded
  agent-memory stores (6 + 7 files), skill-reflex tables and the
  three-outputs contract added to the five existing agents, plus
  master-analyst's `INDEX.md`, run-2 inventory and reachability method.
  27 paths.
- `63bc020` — `feat(skills)`: 38 new directories under `.claude/skills/` —
  the cpo/cto advisors, the grilling set, the OWASP MASVS mobile-security
  set, and the engineering skills sourced from `mattpocock/skills`. Plus
  `.claude/settings.json` (project-scoped plugin enablement for
  `dart-flutter`, `pm-skills`, `wondelai-skills`) and `skills-lock.json`.
  81 files.
- `a50181e` — `docs(assessment)`: `docs/RESEARCH.md` new, plus 11 modified
  governance docs. 2729 insertions, 198 deletions.

Identity verified before the first commit: `dabblersport
<244900353+dabblersport@users.noreply.github.com>`. No `Co-Authored-By`
trailer — `.claude/settings.json` has no `attribution.commit`, and
`CLAUDE.md` forbids it absent that setting.

**`flutter analyze`: 157 issues, 0 errors** (55 warnings, 102 info) — all
pre-existing in `lib/features/**`. No Dart changed today; identical to the
count on the previous commit. Note `flutter analyze` exits 1 whenever any
issue exists, so the exit code is not the gate — the error count is. Piping
it through `tail` masks this by reporting the pipe's exit code instead.

**Secret check — clean.** `.env` is gitignored and untracked.
`android/app/build.gradle.kts` was **not modified and is in none of the
three commits**; its plaintext `storePassword`/`keyPassword` remain a
pre-promotion item needing a Play Console key rotation, not a commit.
Separately verified that the **literal credential value does not appear
anywhere in the committed set** — grepped for the actual string across
`docs/` and `.claude/`, zero hits. Every regex match in the docs is prose
*describing* the finding, never quoting it. The Supabase project ref
`wtncuzcskpigqpmnxwws` is a public identifier.

**Deploy — VERIFIED SUCCESSFUL.** This is the deploy result, not the push
result.
- Pushed `5f92904..a50181e` to `Canary`.
- Check run `Cloudflare Pages`: `status=completed`, **`conclusion=success`**,
  title `Deployed successfully`, completed `2026-08-27T17:33:49Z` (~4m from
  push). Its summary names `a50181e` as the deployed commit, so the verdict
  is bound to this commit and not a neighbouring build.
- Corroborated at the CDN: `flutter_bootstrap.js` moved
  `0b7303c94186` → `28a8092eb3f0` and held stable across four polls at
  HTTP 200. canary.dabbler.pro is serving this build, not a cached prior
  one.
- Booting past Supabase init means the **Preview environment variables are
  intact** — the failure that silently broke every Canary build for months.
- Deployment: `506e444c-e311-4233-93e9-5f58385e4f10`.

**Did not:** No PR into `main`; this stops at `Canary`. `main` confirmed
untouched at `a150190` — Canary is now 16 ahead. Left uncommitted, all
pre-existing WIP per the brief: four `.claude/helpers/*` files,
`.claude/proven-config.json`, `.claude/.proven-config-version`,
`.claude/helpers/.helpers-version`, `.claude/helpers/helpers.manifest.json`,
`docs/screen-report.md`.

**Two paths in neither list — one decided, one open.**
- `skills-lock.json` (tracked, modified): its entire diff is additions
  naming exactly the skills in `63bc020`. **I included it** — committing the
  skills while leaving their lockfile behind would leave the manifest
  describing a state the repo does not have.
- `.agents/` (untracked): a **byte-identical duplicate** of 12 of the
  `.claude/skills/` directories, same installer run, not symlinks.
  **Left uncommitted** — unasked-for and redundant. **Open question put to
  the team lead and unanswered at the time of writing: does any runtime
  actually read from `.agents/skills/`?** If yes, the committed state is
  incomplete for a fresh clone and this needs a follow-up commit. If no, it
  should be gitignored. Not resolved here.

**Count correction:** the brief said 34 new directories under
`.claude/skills/` and 76 uncommitted paths. Actual: **38** directories, 78
paths. I followed the written instruction ("all new directories under
`.claude/skills/`") over the number and committed all 38.

**Not verified:** Whether the governance docs are *correct* — only that they
shipped. No browser render check of canary.dabbler.pro was performed; the
check run plus the changed fingerprint are the evidence, and Flutter web's
~8s boot makes an early screenshot unreliable anyway.

**Learned:** Recorded to agent memory as `skills-install-three-locations` —
installing an external skill writes to three places (`.claude/skills/`,
`.agents/skills/`, `skills-lock.json`), so any brief naming only the first
is structurally incomplete.

**Handoff:** none. A PR into `main` is the PO's call and has not been opened.


## 2026-08-27 — no ticket — Canary deploy of `1d9360f` VERIFIED GREEN
**Task:** Close out the deploy question left open by the entry below, which
recorded the build as still in progress.

**Did:** Confirmed the Cloudflare Pages build for `1d9360f` **succeeded.**
- Check run `Cloudflare Pages`: `status=completed`, `conclusion=success`,
  title `Deployed successfully`, completed `2026-08-27T05:05:23Z`
  (started `05:01:47Z` — **3m36s** for a docs-only build).
- Served build changed: `flutter_bootstrap.js` went `949829bd295c` →
  `137122dfdfcf`, so canary.dabbler.pro is serving the new deploy, not a
  cached prior one.
- The PO independently loaded the site in a browser: it boots to `/landing`
  and renders in full. Booting past Supabase init means the **Preview
  environment variables are intact** — the specific failure that silently
  broke every Canary build for months.

**Did not:** No PR into `main`. This stops at `Canary`.

**Not verified:** Nothing outstanding on this deploy. Not checked, because
out of scope: whether the governance docs are *correct*, only that they
shipped.

**Learned:** Appended to `docs/LEARN.md` PART 1 — three signals that look
like a failed deploy and are not (`WebFetch` 403 from the WAF, an empty
GitHub deployments API, and a blank first screenshot during Flutter web's
~8s boot), plus the finding that the build result **is** readable from here
via `gh api .../check-runs`. That supersedes the standing belief that only
the PO could read it from the dashboard. `docs/CONTRACT.md:152` gives
`version-control` **A** (append) on `LEARN.md`, so this was mine to write.

**Handoff:** none.

## 2026-08-27 — no ticket — Commit the agent system and governance docs to Canary
**Task:** Commit the master-analyst / task-auditor agent system and the
governance documentation set to `Canary`, keeping pre-existing WIP out, then
verify the Cloudflare Pages deploy.

**Did:**
- `7dc6172` — `feat(agents)`: the two agents, the `project-audit` and
  `task-review` skills, and master-analyst's seeded memory (12 files).
- `docs(governance)`: the 14 governance documents plus the 5 per-agent
  status files under `docs/status/`.
- Staged explicitly by path. `flutter analyze`: **157 issues, 0 errors** —
  all pre-existing warnings/info in `lib/features/**`; this change touches
  no Dart.
- Secret check: `.env` is gitignored; no credentials in the committed set.
  Every `service_role` match is prose describing the token, or the regex
  inside `.claude/skills/project-audit/scripts/scan.sh`. The Supabase
  project ref `wtncuzcskpigqpmnxwws` in `docs/SCHEMA.md` is a public
  identifier, not a secret.

**Did not:** Left four modified `.claude/helpers/*` files, the untracked
`.claude/proven-config.json` / `.claude/.proven-config-version` /
`.claude/helpers/.helpers-version` / `.claude/helpers/helpers.manifest.json`,
and `docs/screen-report.md` uncommitted — all pre-existing WIP, not part of
this work. No PR into `main` was opened; this stops at `Canary`.

**Deploy:** PENDING AT TIME OF WRITING — the Cloudflare Pages build for
`1d9360f` was still `in_progress` when this line was written. Not verified.
Superseded by the entry above once concluded; if no later entry exists, the
deploy was never confirmed.

**Handoff:** none.

---

## 2026-08-28 — Reconciled leadership-session plan to Canary

**Task:** Commit the three-way leadership session (master-analyst / cpo /
cto) — the write-path findings and the one-month launch-readiness plan — to
`Canary`, keep pre-existing WIP and the separate repo-hygiene work out, then
verify the Cloudflare Pages deploy.

**Did:**
- `051c515` — `docs(assessment)`: T-016→T-023 and P-001→P-017 in
  `DECISIONS.md`, Wave P + Execution in `ROADMAP.md`, plus `BRIEF.md`,
  `CONTRACT.md` §11, `SCHEMA.md`, `PROJECT_STATE.md`, `LEARN.md`,
  `docs/status/cto.md`, and the `cto/` + `master-analyst/` agent memory
  (including two new files: `repo-hygiene-ruling.md`,
  `repo-hygiene-2026-08-28.md`).
- `2d52157` — `docs(readme)`: roster table in `docs/README.md`; corrected
  "CTO/CPO not yet built" in `docs/RESEARCH.md`.
- Staged explicitly by path, never `git add -A`. Git identity verified as
  `dabblersport <244900353+dabblersport@users.noreply.github.com>`.
- `flutter analyze`: **156 issues, 0 errors** (down from 157). No Dart
  changed in this session; the delta is from earlier work in the tree.
- Secret check: clean. Every `storePassword` / `keyPassword` /
  `service_role` hit across the committed set is prose *naming* the key, not
  a value. No literal password, connection string, JWT, or API key. `.env`
  confirmed gitignored.
- **No SQL was applied anywhere.** Documentation and decisions only, per
  decision 019.

**Did not:**
- `docs/status/cpo.md`, `docs/status/master-analyst.md` and
  `.claude/agent-memory/cpo/` were named in the brief but had **no pending
  changes** — nothing to stage. Their content was already committed.
- Left the repo-hygiene deletions (~73 tracked files: `macos/`, `windows/`,
  `linux/`, root artifacts) and the untracked `docs/APPLE_REVIEW_SIGNIN.md`,
  `docs/flutter_localization_checklist.md`, `docs/briefs/` uncommitted —
  that is KAN-65, a separate ticket, not this brief.
- Left `.claude/helpers/*`, `.claude/proven-config.json` and siblings, and
  `docs/screen-report.md` uncommitted — pre-existing WIP.
- Did not touch `android/` (see finding below). No PR into `main`.

**Deploy: SUCCEEDED — verified, not assumed.** Push
`ef33ac9..2d52157 Canary -> Canary`. The Cloudflare Pages check run on
`2d52157` was polled from `in_progress` to `completed` / **`success`**
(~4.5 min, deployment `69170841-15da-4158-afc2-ed6277145f9c`). The push and
the build are separate facts; both are confirmed.

**Finding — the Android signing password is still exposed at HEAD.** The
brief stated it was "already handled in a prior commit". It was not. The
remediation (loading `key.properties`, removing the literals) exists **only
as an uncommitted working-tree change** to `android/app/build.gradle.kts`.
`git show HEAD:android/app/build.gradle.kts` still contains the plaintext
`storePassword` / `keyPassword` at lines 36 and 38. SEC-11 / KAN-57 is
therefore open, not closed. Left untouched because the brief said not to
touch `android/`; flagged to the team lead instead.

**Handoff:** the uncommitted `android/` fix needs its own commit and a key
rotation. Not mine to sweep into a docs commit.
