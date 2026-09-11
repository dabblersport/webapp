# docs/RESEARCH.md — Research

**Owner:** master-analyst (write) · all agents (read)
**One living file. Never a dated snapshot per session.** When research updates a
finding, **edit the finding in place** and note the change in the changelog. A folder
of `2026-08-27-topic.md` files is a folder nobody reads and no one can tell which is
current.

Covers both halves: **what we learned about building our agents**, and **what we
learned about the product and its market**.

---

## 1. THE ORG STRUCTURE THIS SERVES

Stated by the PO, 2026-08-27.

```
  MOATAZ — owner. Final decision. Not always available.
      ↓
  ASSISTANT — discusses, rephrases, executes the intent correctly
      ↓
  LEADERSHIP — Analyst · CPO (product AND protect) · CTO · CFO (later)
      think · negotiate · stay aware · understand
      MAY give orders downward · MAY reject with reasons
      ↓
  EXECUTIVES — code writers, task doers. Not initiators. Understand and execute.
```

**The structure is the permission.** A leadership agent acting inside it is not acting
without authority. What it may not do is act outside it, or decide something reserved
to the owner.

**Design consequence:** `master-analyst` was built read-only, escalating everything.
Correct for an auditor, **wrong for a CTO**. Leadership must be able to reject an
executive's work with reasons and direct the fix. Build that in from the start.

---

## 2. SKILLS BY AGENT — current state

### CPO (product AND protect) — **built and running.** See `docs/AGENTS.md` for its charter.

| Purpose | Skills |
|---|---|
| **Audit incoming ideas** — the core job | `incoming-request-advisor` · `derisk-measurement-advisor` · `feature-investment-advisor` · `prioritization-advisor` · `opportunity-solution-tree` · `cpo-review` |
| **Work unsupervised** | `autonomous-investigation` — evidence labels, search-plan gates. Serves "they act while I am not here" |
| **Strategy** | `cpo-advisor` (PMF, BCG portfolio, invest-maintain-kill, board reporting) · `product-strategy` (Christensen JTBD) · `product-innovation` (Lean Startup) · `strategy-growth` (Crossing the Chasm) · `product-strategy-session` · `problem-framing-canvas` · `positioning-statement` · `recommendation-canvas` · `jobs-to-be-done` · `ansoff-matrix` · `swot-analysis` |
| **Money** | `business-health-diagnostic` · `saas-revenue-growth-metrics` · `saas-economics-efficiency-metrics` · `tam-sam-som-calculator` |
| **Market & persuasion** | `competitive-analysis-process` · `marketing-cro` (StoryBrand) · `sales-influence` (Cialdini — Venue Partner Deck, investor pitch) |
| **Writing** | `prd-development` |

### CTO — **built and running.** See `docs/AGENTS.md` for its charter.

Roughly 70% equipped before anything new: `codebase-design` · `domain-modeling` ·
`diagnosing-bugs` · `tdd` · `code-review` · `research` · `grill-peer` ·
`writing-for-agents` · **29 dart-flutter skills** · the **Dart MCP server**
(`hot_reload`, `widget_inspector`, `run_tests`, `analyze_files`, `get_runtime_errors`).

Added:

| Purpose | Skills |
|---|---|
| **Leadership** | `cto-advisor` · `cto-review` · `cto-architecture-decision-skill` · `cto-engineering-metrics-skill` (DORA) · `cto-technology-roadmap-skill` · `cto-risk-resilience-skill` |
| **Engineering craft** | `systems-architecture` (Designing Data-Intensive Applications) · `code-craftsmanship` (Clean Code) |
| **Mobile security** — maps onto live open issues | `masvs-checklist` · `privacy-audit` (→ the anon leak, KAN-37) · `secure-storage-audit` (→ storage bucket policy gaps, KAN-27) · `auth-assessment` (→ passwordless auth) · `crypto-review` · `network-security-check` · `mobile-threat-model` · `secure-mobile-dev-guide` |

**ADRs live in `docs/DECISIONS.md`.** Never start a parallel ADR store, whatever a
skill's template suggests.

### Analyst · task-auditor · version-control — built, see `docs/AGENTS.md`

---

## 3. THE GAP NO MARKET SKILL FILLS

Every product skill surveyed assumes you are **creating** strategy. Dabbler already has
**26 business documents** — brand bible, monetization architecture, investment
memorandum, governance white paper, GTM playbook, 5-year financial model, subscription
architecture, competitor analysis.

What is needed is **alignment judgement against a fixed corpus**: does this new idea
match what we already committed to, and where exactly does it conflict?

**Build it.** Methodology: *AI Agents-as-Judge* (arXiv 2506.22485) — modular agents,
one criterion each (accuracy, consistency, completeness, clarity), 99% information
accuracy and 95% agreement with human experts. One criterion per lens, verdicts with
citations, never one agent grading everything at once.

Same move as `grill-peer` and `grill-po`: when a market skill assumes the wrong reader,
write the sibling rather than bend the original.

---

## 4. DECLINED — so nobody re-litigates

| Source | Why not |
|---|---|
| **Anthropic's 31 "Claude for small business" skills** | Operator skills for a business already running — QuickBooks AR/AP, Stripe cash flow, payroll, invoice chasing, HubSpot pipelines, ticket deflection. Dabbler is pre-launch: no revenue ledger, no CRM, no customers, no connectors. **Revisit at launch:** `/margin-analyzer` + `/price-check` (→ `12a`/`12b` pricing docs), `/contract-review` (→ `09` Venue Partner pack), the three briefing skills |
| **745 Python files in `alirezarezvani/claude-skills`** | Took 4 skills as markdown; excluded the scripts. ~96KB of unread executable code is not worth the trust surface for arithmetic. Each skill annotated to apply frameworks directly |
| **`coreyhaines31/marketingskills`** (50) | Execution layer. `10 Marketing Psychology` and the GTM playbook exist; the CPO audits against them rather than authoring campaigns. Marketplace registered — install when GTM execution starts |
| **Anthropic PPTX skill** | Would serve `05 pitch deck script`, but needs Node `pptxgenjs`, `markitdown`, Pillow, LibreOffice. Heavy chain for one document |
| **`founderjourney/claude-skills`** | Cited for SaaS financial projections — a direct hit against `12c 5yr model` and `03 Investment Memorandum`. **Repo 404s.** Citation stale. **Gap still open** |
| **Anthropic skill-creator** | `skill-builder` + `writing-for-agents` cover it |
| **Snyk Fix, trailofbits** | Need external MCP / heavy security tooling. Revisit if the CTO takes on a real audit |
| **57 of 77 `pm-skills`** | EOL processes, PM career coaching, workshop facilitation. Real skills, no current use. On the marketplace when they earn a place |
| **4 of 12 mobile-security skills** | `mobile-pentest-plan`, `resilience-assessment`, `platform-interaction-review`, `code-quality-scan` — no current use |

---

## 5. SKILL SPRAWL — CLOSED 2026-08-27

**73 project skills, 29 plugins, 7 agents.** The cure was not one router but two,
because there are two different loads (`writing-for-agents`, "The two loads").

**Context load — the agents.** Each of the 7 agents carries its own **SKILL REFLEXES**
table: a `moment → skill` mapping bound to a moment, not a topic, and where it matters
bound to a gate the agent cannot pass. An agent never chooses from 73; it reads its own
short list. Scoped per agent beats a shared router, because the CPO should never see
the mobile-security set and the app-store agent should never see portfolio strategy.

**Cognitive load — the PO.** `/front-door` is a user-invoked router naming the **10
skills only he can start** and the usual order through them
(`/grill-me` → `/to-spec` → `/to-tickets` → `/implement`). It also says which skills
route themselves, so he never picks one on an agent's behalf, and which agent to ask
when a person is the better answer than a skill.

**Two defects found while closing this:**

1. `masvs-checklist` and `mobile-threat-model` were **user-invoked** while sitting in
   the CTO's reflex table — instructions to fire a skill the agent could not reach.
   Both flipped to model-invoked. Model-invocation *adds* agent reach without removing
   the human's, so the flip costs only the description's context load.
2. The first reachability check was written in zsh, which does not word-split unquoted
   variables. It concatenated every skill name into one string, tested nothing, and
   **reported a clean pass.** Re-run under bash: 0 unreachable, 0 not found. A check
   that prints a conclusion it did not compute is worse than no check.

**Standing rule:** a skill named in a reflex table must be model-invocable and must
exist. Verify after every roster change, under bash.

## 6. OPEN — FOR THE PO

1. **CFO agent** — deferred. `business-investment-advisor` (DCF) and the pricing/
   commercial skills sit in `alirezarezvani` when it is time.
2. **Do leadership agents get write authority over executives' work, or only
   reject-with-reasons?** Decides whether the CTO edits code or only orders a fix.
3. **Where does the CPO's verdict land** — a Jira comment, a `docs/` file, or both?
4. **SaaS financial projection skill** — the one identified gap with no source.

## Changelog

| Date | Change |
|---|---|
| 2026-08-27 | Created as the single living research file, absorbing the dated file that preceded it. 43 skills installed across CPO/CTO, all project-scoped, zero Python. |
| 2026-08-27 | `cpo` and `cto` agents built. Sprawl closed: reflex tables on all 7 agents + `/front-door` for the PO. Two unreachable skills fixed. |
