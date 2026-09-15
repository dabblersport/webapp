# Tests — the deterministic layers, who owns them, and how they run

**Tests are Product assets.** They live in this repository, survive chat restarts, provider
changes, agent changes and machine restarts, and are the thing that replaces an expensive
model navigating the app to learn what a command could have told it. The rule the QA layer
runs on: **use the lowest-cost test that provides sufficient confidence.**

## The layers

| Layer | Where | Command | Proves | Owner | Trigger |
|---|---|---|---|---|---|
| static | `analysis_options.yaml` | `flutter analyze --no-pub --no-fatal-infos` | the CI lint gate | `frontend` | routine — any Dart or config change |
| unit / widget | `test/` | `flutter test` | Dart logic, controllers, repositories | `frontend` / `backend` by feature | routine — any Dart change |
| integration (device) | `integration_test/` | `./scripts/qa.sh` | the real bootstrap on a simulator | `frontend` | on request |
| backend probes | `supabase/tests/<KAN>/` | `bash supabase/tests/<KAN>/run.sh` | a migration, pre/post, on a throwaway Postgres in Docker | `backend` | per ticket that ships a migration |
| API | `tests/api/` | `npm run test:api` | the REST/Auth contract, read-only, anon key | `backend` | routine — `supabase/` changes; schema / money / security items |
| web E2E | `tests/e2e/` | `npm run test:e2e` | the app in one headless Chromium, signed in once | `frontend` | routine — user-visible web changes |
| mobile E2E | `tests/maestro/` | `npm run test:maestro` | the app on the Android emulator | `frontend` | routine — mobile-platform / native changes; release |
| performance | `tests/perf/` | `npm run test:perf` | a named path under load, thresholds in the script | `backend` | **intentional only** |
| exploratory | TestSprite MCP | requested by `qa` | discovery beyond deterministic coverage | `qa` (tester role) | **intentional only** — never after every task |
| real devices | BrowserStack (reuses Maestro flows) | — | the Maestro suite on a device matrix | `devops` | **release stage only** — deferred: no credentials |

Selection is canonical and deterministic: `agent/qa/routing.py` in the Thebes repository,
tested by `agent/qa/tests/test_routing.py`. No agent re-implements it. Docs-only changes select
nothing; that is an answer, not a gap.

## Running locally

Every layer is one command from the repository root and exits 0/1. Runners refuse with **exit
2 and a named reason** when infrastructure is missing (no device, no tool, no key); the Thebes
QA layer classifies that as `TEST_INFRASTRUCTURE_FAILURE`, never as a Product defect.

```bash
flutter analyze --no-pub --no-fatal-infos
flutter test
npm run test:api
npm run test:e2e
npm run test:maestro        # needs: emulator booted + debug APK (see tests/maestro/README.md)
npm run test:perf           # only on purpose
```

Full output of every run goes to an artifact on disk (`tests/*/.results/`, `test-results/`,
`playwright-report/` — all gitignored) and is referenced by path. **Screenshots, traces and
logs never enter an agent's long-lived context**; the bounded tail and the reference do.

## Known local constraint (2026-09-15)

`flutter test` **cannot run on this machine**: `Building native assets failed … linker
command failed` (package `objective_c`, Xcode SDK), reproduced on parent commits. It is a
toolchain fault, classified as infrastructure, and it is the first entry in the QA layer's
signature table. CI runs the same command on Ubuntu and is unaffected. Fixing it is a `devops`
act (Xcode licence / SDK), not a Product change.

## How a failure is reported

One structured record, not a transcript — test, environment, work item, expected, actual,
minimal reproduction, evidence references, severity, likely domain, classification, whether a
deterministic regression already exists, recommended owner (`agent/qa/results.py::QADefect`).

Classification decides routing:

| Classification | Meaning | Goes to |
|---|---|---|
| `PRODUCT_DEFECT` | tests ran; an assertion about the Product failed | the Product capability (`frontend` / `backend`) |
| `TEST_DEFECT` | tests ran; the test is wrong (synthetic, support code, quarantined) | whoever owns the test |
| `TEST_INFRASTRUCTURE_FAILURE` | the harness never reached the tests | `devops`; **no review cycle spent** |
| `EXTERNAL_QA_FAILURE` | TestSprite / BrowserStack could not run or answer | `devops`; deferred |

## Retest is bounded

A review may be reopened after FAIL at most `MAX_REVIEW_CYCLES = 3` times in total (one review
plus two retests), enforced in Thebes' canonical state writer. Reaching it is a finding for a
human — an intervention or a CEO decision — never an automatic retry and never a downgrade to
an easier route. Infrastructure refusals happen before any verdict and spend nothing.

## Regression accumulation

When QA finds an important, reproducible Product defect: reproduce it; route it to the
Product capability; fix it; and — where a deterministic test is economical — add the smallest
test that would catch the same defect next time, in the layer that owns that surface. **One
permanent regression test beats repeated AI exploration of the same failure.**

## Secrets

Never committed: TestSprite API key, BrowserStack username / access key, Postman API key,
production credentials, any service-role key. `.env`, `tests/e2e/.env.e2e` and
`tests/e2e/.auth/` are gitignored; runners read from the environment first, then those files.
The anon key is public-by-design and RLS-protected. Production mutation authority stays with
the existing Thebes policy; no test integration is a way around it.

## CI — designed for, not yet wired

Local execution works first. The same commands run in CI unchanged; intended triggers:

| Event | Runs |
|---|---|
| pull request | `flutter analyze`, `flutter test`, targeted `tests/api` |
| push to `Canary` | the above + `tests/e2e` + `tests/maestro` smoke on an emulator job |
| release candidate | full mobile / web / API regression + BrowserStack device matrix (Maestro flows) |
| performance milestone | `tests/perf` on the named path, explicitly |

`ci.yml` today runs `flutter analyze` + `flutter test` on `Canary` pushes and PRs into `main`
(KAN-72); `anon-allowlist-check.yml` gates anon-reachable views (KAN-61). No expensive gate is
added to every commit.
