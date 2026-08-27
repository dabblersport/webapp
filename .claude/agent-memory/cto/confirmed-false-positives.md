---
name: confirmed-false-positives
description: Findings verified as NOT defects — PostGIS system views, Firebase/anon public keys, absent password rules, no cert pinning. Never re-flag these.
metadata:
  type: project
---

Verified non-defects. Re-flagging these wastes a review cycle each time.

- **`geography_columns` / `geometry_columns`** are anon-readable definer views and **PostGIS system views**. They appear in the "19 anon-readable definer views" count. Not a defect.
- **Supabase anon/publishable key, Firebase client keys, `GOOGLE_WEB_CLIENT_ID`** are public by design. GitHub secret scanning's 3 open `google_api_key` alerts are all this — dismiss them. Note secret scanning did **not** catch the Play signing password, which was the real one.
- **Absence of password rules** — accounts are passwordless by design (decision `002`).
- **No certificate pinning** — deliberate, recorded as [[T-006]] / `DECISIONS.md` T-006. Not an open gap.
- **`.env` does not ship in the APK/IPA** — deliberately not a Flutter asset; secrets arrive via `--dart-define`.
- **No client-side authorization decisions anywhere in `lib/`** — verified by grep for owner/creator comparisons and `canEdit`/`isOwner` getters. Decision `014` held on the client side.

**Why:** each of these was investigated at length during KAN-39 and cost real time.
**How to apply:** check here before opening a security finding; cite this file to close one.

See [[kan39-launch-readiness]].
