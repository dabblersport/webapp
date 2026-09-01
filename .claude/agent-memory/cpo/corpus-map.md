---
name: corpus-map
description: Map of the 26-document Notion business corpus — which document answers which question, page IDs, and which docs are containers with children
metadata:
  type: reference
---

Root: **Business docs** `3c9d4c6dd86d80c08d66fd95416b23e4` (parent page: **Dabbler**
`e490df79f9304c84a59d015a5aafae46`). Read-only for `cpo` — writing to Notion is the PO's.

## Which document answers which question

| Question | Document |
|---|---|
| Positioning, category, one-page pitch | `00` exec summary `362d4c6dd86d8023b6c9edd442ee816c` |
| Permanent Truths, voice, audiences, Hidden Talent Doctrine | `01` brand bible `362d4c6dd86d8041b8f7ea0c3b5ea0f0` |
| Seven revenue pillars, unit economics, north star, capital strategy | `02` monetization `362d4c6dd86d8047ae90c3ffdb9df6b5` |
| TAM/SAM/SOM, validation plan, falsification conditions, exit thesis | `03` investment memo `362d4c6dd86d803aa1abfb792a138c2d` |
| Player Rights Charter, Ethics Committee, Non-Negotiables, federation tiers | `04` federation `362d4c6dd86d80019fc6f671675a5115` |
| Slide-by-slide deck script, 24-month milestones | `05` pitch deck `362d4c6dd86d80008171d081d89ebd4c` |
| Colour/type/photography/governance, banned vocabulary | `06` brand book `363d4c6dd86d80769e4ee8130b24addb` (**5 children**, 06a–06e) |
| Real competitors, cricket-first recommendation, honest probabilities | `07` competitor analysis `364d4c6dd86d80eea8a3d296ddaac2e3` (**6 children**, incl. `07e` investor-facing) |
| Launch city/date/budget, growth loops, targets, Path-C pivot triggers | `08` GTM playbook `364d4c6dd86d809a9f01ca61c1fec3e8` (**4 children**) |
| Venue commercial terms, **the Pilot Agreement** | `09` venue pack `364d4c6dd86d809f8792ce7bbfb2c688` |
| Activation definition, retention triggers, marketing budget, trip-wires | `10` marketing psych `364d4c6dd86d80efbeb7ee1544bad417` (1 child) |
| Persona architecture, MVP feature cut | `11` service blueprint `364d4c6dd86d808b8b49cdd7f863b143` (**container only — use v2 `367d4c6dd86d80c6aacdc130d6c92027`**) |
| ~650 features with phase + persona entitlements | `11b` features list `367d4c6dd86d800da438d24eb0928d38` |
| Every tier, price, limit, trial, conversion target | `12a` subscriptions `367d4c6dd86d80819595e363d18d0fc2` |
| 15 revenue streams, fee split, margins, regulatory flags | `12b` revenue streams `379d4c6dd86d80bb8bb6f125019e01e5` |
| The 5-year model — assumptions and P&L | `12c` `37bd4c6dd86d802093e8e9d5ff61f815` + narrative `37cd4c6dd86d80ce8d58e4b06cbf9c6d` |
| MENA benchmarks, sensitivity drivers | "financial model" `364d4c6dd86d800dbb2bc40f28e8b86c` (**container — substance is child "Benchmark Research Report"** `367d4c6dd86d80838e7cec385bf9347b`) |
| 13 weekly sprints with go/no-go gates | `13a` sprint plan `37cd4c6dd86d805a8f16cabc3d49a40c` |
| **The binding launch gate — ten P0 criteria** | `13b` runbook `37dd4c6dd86d805f9602dc53bcd725f5` |
| Store metadata, rejection risks, asset specs | `13c` app store pack `37dd4c6dd86d80558574e81dd0ab598c` |
| 25-organiser beta, QA matrix, beta exit criteria | `13d` beta plan `37dd4c6dd86d8075b7fec4a1fc4a2c80` |
| Persona-grouped launch checklist; **claims to supersede 13a–13c on auth** | `14` checklist `37dd4c6dd86d800da6b5d8ced2e424d3` |
| Sport list (~165), Stage-1 lanes, exclusions | Sport Reference `364d4c6dd86d8074afc8dfc8d1e1223c` (2 children) |

## The Checklist tree is NOT in Business docs — read it separately

Under **Dabbler** (not Business docs) sits **Checklist** `37dd4c6dd86d8039a4ddcfe48d12822c`
(v1, includes a **GUEST section A1–A7**) with child **Updated checklist**
`399d4c6dd86d8021b719c4df6330006e` (**v2, live, last edited 2026-07-18** — supersedes v1;
**deletes the guest section** while still referencing guest mode in I8). Doc `14` in the table
below is a *third* page id. **Discovered 2026-08-29 — my earlier "26 docs, study complete"
claim covered Business docs only, not this tree.** The v2 is the PO's working checklist.

**Its checkmarks are claims, not evidence.** 42 `[x]` dated 2026-07-18; at least five were
disproved by work done 2026-08-27..29 (B14 sign-out, B7–B12 onboarding, D27 following,
D33 report/block, and **D9 account deletion — the exact Apple 5.1.1(v) rejection reason**).
Never read an `[x]` there as verification.

## Traps

- **Several "documents" are empty containers.** `11`, `07`, `06`, `08`, `financial model`
  and `Sport Reference` have no body — the content is in children. Fetching the parent
  returns a link list and looks like an empty doc.
- **`11` has a v1 and a v2.** v2 supersedes; v1 uses "Captain" for "Organiser".
- **`12c` is a Notion rendering of an `.xlsx` that is not in Notion.** Its assumptions tab
  and its narrative disagree on inputs (App Fee AED 1 vs AED 1.3). The spreadsheet is the
  authority and is unavailable.
- **Docs 00–05 are large.** `03` overflows the fetch cap — it lands in a tool-results file
  that must be sliced by character range, not read by line.

See [[corpus-contradictions]] for where these documents disagree, and
[[launch-gate-is-13b]] for the bar any launch verdict is judged against.
