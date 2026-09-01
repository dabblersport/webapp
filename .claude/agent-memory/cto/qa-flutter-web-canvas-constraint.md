---
name: qa-flutter-web-canvas-constraint
description: Dabbler's Flutter web build is CanvasKit — the DOM is empty, so DOM/accessibility-based browser tools return nothing; QA must be vision-driven. Measured 2026-08-29.
metadata:
  type: project
---

Dabbler's Flutter web build renders via **CanvasKit**, so the page has no
readable DOM. A browser agent must drive it by **screenshot + coordinates**,
never by `read_page` / `get_page_text` / `find`.

**Why:** measured live against https://canary.dabbler.pro on 2026-08-29, not
inferred. Commands and results:

- `grep -o 'renderer[^;]*' build/web/flutter_bootstrap.js` -> `"renderer":"canvaskit"`
- `mcp__claude-in-chrome__read_page {filter:"interactive"}` -> a single node,
  `generic [ref_1]`. Zero interactive elements.
- In-page JS: `document.body.innerText.length` = **0**;
  `flt-semantics` nodes = **0**; `[aria-label]` = **0**;
  `flt-semantics-host` exists but `children.length` = **0**.
- The `flt-semantics-placeholder` exists, but a synthetic `.click()` does NOT
  populate the tree — the placeholder is consumed and the host stays empty.
- `grep -rln "Semantics(" lib/ | wc -l` -> **6** files. Even with semantics
  forced on, almost nothing carries a label, so the tree would not be a
  usable oracle.

**What DOES work, verified in the same session:** `computer` screenshots
(full visual fidelity, text legible), coordinate clicking, `read_console_messages`
(app logs surface through `main.dart.js`), and `read_network_requests`
(28 requests captured with method + status).

**Trap:** `read_network_requests` only starts capturing **when first called**.
An agent that acts first and reads after will see nothing and wrongly report
"no request was made". Arm it before the action, then act, then read.

**Dart MCP is not an alternative here.** It is absent from `.mcp.json`, and
upstream `dart-lang/ai#356` (open, filed 2026-02-21) documents that there is
no working device option combining Dart MCP (`get_widget_tree`, `hot_reload`,
runtime errors) with browser automation: `-d chrome` gives DTD but an isolated
Chrome the extension cannot attach to; `-d web-server` is browsable but DTD
fails to connect.

**How to apply:** any QA/UX agent spec for the web surface must be built on
vision + console + network, and must never be told to "find the button in the
accessibility tree". See [[verification-lessons]] — this is another case where
the obvious search proves nothing about what exists.
