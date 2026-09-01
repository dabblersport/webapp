---
name: spa-fallback-200-trap
description: canary/app .dabbler.pro return HTTP 200 + index.html for EVERY unmatched path; a 200 on /assets/.env or any sensitive path is not evidence the file exists
metadata:
  type: project
---

Cloudflare Pages serves the Flutter SPA fallback for every path that does not match a
real build artifact. `/assets/.env`, `/.env`, and `/assets/.totally-not-real-xyz123` all
return the **byte-identical** 1800-byte `index.html` with `content-type: text/html`.

**Why:** single-page-app routing — the client router needs to receive index.html for
arbitrary deep links. This is correct behaviour for this app, not a misconfiguration.

**How to apply:** an HTTP 200 on a sensitive-looking URL on `*.dabbler.pro` proves
nothing. Before escalating any "file X is exposed" finding on this host, run the
three-way discriminator:

```
curl -sS -o /dev/null -w "%{http_code} %{content_type} %{size_download}\n" URL
```

against (a) the suspect path, (b) a random nonexistent path, (c) a known real asset
(`/flutter_bootstrap.js` → `200 application/javascript 13094`). If (a) matches (b) in
size and content-type, nothing is served. Compare hashes to be certain.

**Confirmed 2026-08-29** on a qa-tester passive finding of `/assets/.env` → 200.
Verdict: **NOT A FINDING**, severity zero, no ticket filed. Corroborating repo facts:
`pubspec.yaml` declares no `assets:` section at all, and `.env` is gitignored
(`.gitignore:5`), so no `.env` can reach `build/web`.

See [[verification-lessons]] — this is the same class of error as a grep proving an
absence: the check must be able to distinguish the positive from the negative case.
