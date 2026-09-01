---
name: self-contradictory-trace-citation
description: A hop-by-hop trace can assert "no X exists" in one sentence and cite an X one sentence later without noticing — read both halves of a finding, not just the headline claim.
metadata:
  type: feedback
---

Found on KAN-42 (2026-08-30, master-analyst's §15b admin/moderation flow trace). The doc said
"no `.rpc(` call site exists anywhere under `lib/features/admin/**` or
`lib/features/moderation/**`," then in the same breath cited "`rpc('is_admin')` at the screen
(`moderation_queue_screen.dart:22`)" — which *is* an `.rpc(` call site under that exact path. The
underlying substance (admin/moderation reads via a definer view, gated by an RPC-based
authorization check, not by a data-fetching RPC) was correct and important (feeds SEC-03), but
the sentence built to support it contradicted its own citation, and the actual persistence hop
(`lib/services/moderation_service.dart:818,822`) was never cited at all.

**Why: "measured, not estimated" claims still need a coherence check**, not just a grep-for-truth
check. A number or file:line can be individually verifiable and the sentence around it still be
false. This is the same failure class as the aggregate-vs-per-item gap
([[aggregate-updated-per-view-not]]) — a document can be locally accurate and globally
inconsistent.

**How to apply:** when a finding makes a negative claim ("no X exists," "X was never called"),
check the very next citation in the same paragraph against that claim before accepting either. If
a trace's AC requires "repository → RPC/table, file:line at each hop," a paragraph that names only
an authorization gate and asserts no data-access RPC exists is missing the hop, not just imprecise
— grep for the actual read (`.from(`, `.rpc(` for reads, service-layer file) before passing it.
