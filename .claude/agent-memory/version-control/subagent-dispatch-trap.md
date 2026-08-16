---
name: subagent-dispatch-trap
description: The Agent tool silently falls back to general-purpose when subagent_type is unrecognised, and the agent registry is scoped to the session's working directory
metadata:
  type: project
---

Discovered 2026-08-16. The Agent tool **silently falls back to a general-purpose agent when `subagent_type` is unrecognised**. No error is raised, no warning is printed, and the spawn reports success exactly as it would for a real match.

Compounding this, the agent registry is **scoped to the session's working directory**. Agents defined in this repo (`.claude/agents/*.md`) do not exist in a session opened against a different project — so the same `subagent_type: "version-control"` that resolves correctly here resolves to nothing, and therefore to a generic agent, in a session rooted elsewhere.

**Why:** on 2026-08-16 a session running from a different repo appeared to use the `version-control` agent successfully. It was a generic agent the entire time, and only produced correct work because the topology — branch flow, build command, commit identity — was hand-fed to it in the prompt. Every signal that would normally indicate success was present: the spawn returned cleanly, the agent answered in role, and the output looked right. The only thing missing was the agent itself.

**How to apply:** never trust a successful spawn. Verify by asking the subagent to state a fact that exists **only** in its own definition, with no file reads permitted and no hint of the answer in the question. For this agent the reliable probe is the commit identity email (`244900353+dabblersport@users.noreply.github.com`) — it appears in `.claude/agents/version-control.md` and in no CLAUDE.md, so a generic fallback cannot produce it. Do not probe with the branch flow or the Cloudflare build command: both are also written in the project CLAUDE.md, so any agent can answer them correctly and the test proves nothing. See [[canary-pipeline-incident]] for the same shape of failure at the deploy layer — a green success signal that was never evidence of the thing it appeared to confirm.
