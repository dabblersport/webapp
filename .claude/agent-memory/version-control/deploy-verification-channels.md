---
name: deploy-verification-channels
description: The Cloudflare Pages build result IS readable from the CLI via the GitHub check run on the commit; three other signals look like failure but are not
metadata:
  type: project
---

Discovered 2026-08-27. **The Cloudflare Pages build result can be read from
this session without any Cloudflare credentials.** Pages posts a check run
named `Cloudflare Pages` onto the pushed commit:

```
gh api repos/dabblersport/webapp/commits/<sha>/check-runs \
  --jq '.check_runs[]|"\(.name) \(.status) \(.conclusion) \(.output.title)"'
```

It goes `in_progress` → `completed` with `conclusion=success` and title
`Deployed successfully`, and `output.summary` carries a dashboard link
containing the deployment id. A docs-only build took **3m36s**.

This **supersedes** the standing instruction that there are no Cloudflare
credentials here so the PO must read the dashboard. That is still true of
the *build log* — the log itself is only in the dashboard — but the
**pass/fail verdict is readable from here.** Poll the check run first; send
the PO to the dashboard only for the log after a `conclusion=failure`.

`gh` is authenticated as `dabblersport`.

**Three signals that look like a failed deploy and are not:**

1. `WebFetch` on canary.dabbler.pro returns **403** — the WAF blocks
   automated fetchers. Inconclusive, not a failure.
2. The **GitHub deployments API is empty** for this repo — Pages does not
   post deployment objects, only check runs. An absent channel, not a
   negative result.
3. A **blank first screenshot** — Flutter web takes ~8s to boot, then
   self-routes to `/landing`. Screenshotting early reports a healthy deploy
   as broken.

The `flutter_bootstrap.js` fingerprint check does work — it changed
`949829bd295c` → `137122dfdfcf` on a docs-only build — but it is a lagging
signal (it only moves once the CDN serves the new build) and it cannot
distinguish "build failed" from "build still running". The check run
distinguishes all three states, so prefer it.

**How to apply:** after every push to `Canary`, poll the check run for the
pushed SHA until `status=completed`, and report its `conclusion`. Use the
fingerprint as corroboration that the CDN is actually serving the new build,
not as the primary verdict. See [[canary-pipeline-incident]] for why the
deploy, never the push, is the thing to verify.
