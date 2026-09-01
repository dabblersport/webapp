---
name: qa-and-ci-gate-position
description: Ruling T-026 — QA gates promotion not tickets, and the mechanical CI gate comes first; with the measured fact that nothing runs analyze or test
metadata:
  type: project
---

**Decision `T-026`, 2026-08-28.** QA is required at the **`Canary` → `main` promotion boundary**,
not at `In Review` on every ticket. A per-ticket QA pass would bottleneck `backend-owner` and
`flutter-feature-agent` immediately for no proportionate gain.

**Why:** `task-auditor`'s two gates are both document-to-document comparisons — acceptance
criteria, and governance alignment. Neither opens the app. An agent can satisfy every criterion
in prose and ship a screen that throws on build. Real gap, and it widens with parallel agents.

**How to apply:** the QA seat is only worth filling if it **drives the running app** (Dart MCP:
`widget_inspector`, `get_runtime_errors`, `hot_reload`). A QA agent that reviews diffs is
`task-auditor` with a second name — reject that shape. Filling the seat is the PO's call, not
`cto`'s.

**The measurement that reorders the priority — verified 2026-08-28, not assumed:**

| Fact | Command / file |
|---|---|
| 5 test files | `find test -name '*_test.dart' \| wc -l` |
| `flutter test` run by **nothing** | `.github/workflows/deploy-web.yml` has no test step |
| `flutter analyze` run by **nothing** | not in that workflow; `scripts/cloudflare-build.sh` only has four `test -n` env guards |

So the only thing between a bad commit and canary is whether an agent *remembered* to run analyze.
**The mechanical gate precedes the reviewer** — hiring judgment where the missing thing is
arithmetic is the wrong order. Filed as **KAN-72** (CI gate, `version-control`).

**Second finding from the same pass — KAN-73.** `deploy-web.yml` publishes to `gh-pages` on every
push to `main` and `BETA`, while production is Cloudflare Pages. **`main` drives two deploy
targets and only one is watched.** `CLAUDE.md`'s release-topology section describes one. Not a key
exposure — those keys are publish-safe (see [[confirmed-false-positives]]) — an unmonitored
surface.

See [[kan39-launch-readiness]] — promotion must not be described as QA-verified until the seat
exists and KAN-72 has landed.

**Numbering, settled 2026-08-28.** This ruling is `T-026`. It was briefly filed as `G-003`
(collided with team-lead's hiring decision), renumbered `G-004`, then moved to `T-026` — its
correct home, because `CONTRACT.md` §9.3 gives `G-nnn` to master-analyst and `T-nnn` to `cto`.
**The rule: a leadership agent's own-domain ruling stays in its own prefix even when the topic
brushes governance.** §9.3 now names the assistant as `G-nnn`'s only second appender, and only
for PO-direct decisions transcribed live. Logged in CONTRACT.md's errata table.

---

## Amended 2026-09-01 by `T-042` — the gate was built and has never worked

**`ci.yml` has never passed. 12 runs, 12 failures**, verified
`gh run list --workflow=ci.yml --limit 100 | awk '{print $2}' | sort | uniq -c`.
It dies at Analyze: **0 errors, 55 warnings, 160 infos**, and `flutter analyze` exits
non-zero on all of them. KAN-72 is marked **Done**. Now KAN-112.

**Two traps this taught, both worth carrying:**

1. **"The gate exists" is not "the gate passes."** I wrote the T-026 memo when KAN-72
   landed and then reasoned from it for days as though `main` were gated. A closed ticket
   is a claim about work performed, never about the state that work was supposed to
   produce. **Check the run history, not the ticket status.**
2. **A dead workflow's failure reason is load-bearing before you delete it.**
   `deploy-web.yml` failed at `flutter build web` — which looks like a real signal about
   `main`. It was not: `flutter-version: 3.38.9` is a stale pin, while
   `scripts/cloudflare-build.sh:13` clones `-b stable --depth 1` and floats. Production
   built fine throughout. Had I deleted on "it's dead anyway" I would have been right by
   luck. **The same stale pin is still in `ci.yml`** — a gate compiling against a
   different SDK than production is testing something else.

**Also settled here:** Cloudflare Pages builds on its own trigger, independent of Actions.
**A red Actions check does not block a deploy** to canary or production. So a red CI is an
*ignored* pipeline, not a blocked one — which is why 12 red runs went unremarked.

See [[deployed-not-committed-trap]] — same family: a thing's recorded status is not its
live state.
