---
name: canary-pipeline-incident
description: Every Canary preview build failed silently for months with "ERROR: Missing SUPABASE_URL" because Cloudflare Pages Preview variables were empty
metadata:
  type: project
---

Discovered 2026-08-16. Every `Canary` preview build had been failing for months with `ERROR: Missing SUPABASE_URL`, and nobody noticed. Cloudflare Pages keeps Production and Preview variables in **two completely separate environments**; only Production had ever been populated, so the Preview environment was empty and `scripts/cloudflare-build.sh` hard-failed on its required-variable check for every single Canary deploy.

Fixed by populating the Preview environment with the five required build variables: `APP_NAME`, `ENVIRONMENT`, `GOOGLE_WEB_CLIENT_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

**Why:** a green `git push` says nothing about whether the deploy succeeded. The pushes were all fine — git reported success every time — while canary.dabbler.pro quietly served a stale build for months. The gap between "push succeeded" and "deploy succeeded" is where this hid.

**How to apply:** whenever a build variable is added or changed, add it to **BOTH** the Production and Preview environments in Cloudflare Pages — never just one. And after any push to `Canary`, verify the deployment itself (poll https://canary.dabbler.pro for HTTP 200 and a changed build fingerprint) instead of treating the push as the finish line.
