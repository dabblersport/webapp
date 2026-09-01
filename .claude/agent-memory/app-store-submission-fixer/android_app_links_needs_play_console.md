---
name: android-app-links-needs-play-console
description: assetlinks.json SHA-256 fingerprint must come from Play Console App Signing (not the upload keystore) — cannot be derived locally
metadata:
  type: reference
---

`web/.well-known/assetlinks.json` needs a SHA-256 cert fingerprint for Android App Links (autoVerify) to work for `app.dabbler.pro/game/*`. Dabbler uses Google Play App Signing (per KAN-57 history — Google holds a separate app-signing key; the dev only holds the upload key). The value needed is the **App signing key certificate** SHA-256, found at Play Console → app → Setup → App integrity → App signing key certificate. It is NOT derivable from the local `upload-keystore-new.jks` (that's the upload key, a different cert).

**Why this matters:** guessing or using the wrong (upload-key) SHA-256 would still fail Digital Asset Links verification while looking fixed — worse than leaving the honest placeholder.

As of 2026-08-31 (KAN-63 item 2) this is still blocked on the PO pulling that value from Play Console. iOS AASA is correct and unaffected — only Android is broken.

**2026-08-31 update:** PO pasted a SHA-256 into assetlinks.json anyway, sourced from the same session's earlier upload-key rotation fingerprint rather than fresh from Play Console. Verified with `keytool -list -v` against `android/app/upload-keystore-new.jks` directly: the pasted value (`56:02:0F:19:D4:F5:02:B7:19:86:E4:33:A3:55:29:99:FD:6D:3E:9D:40:90:25:EF:17:94:4C:65:47:9B:8E:59`) is an **exact match to the upload key's SHA-256**, not the App Signing key — confirming this memory's warning was correct. Do not accept a fingerprint for this file unless its source is explicitly stated as Play Console → App integrity → App signing key certificate. The only clean way to verify after deploy without Play Console access is Google's Digital Asset Links Statement List Generator (https://developers.google.com/digital-asset-links/tools/generator) — it fails cleanly on a wrong cert.

See also [[ios-release-entitlements-split]].
