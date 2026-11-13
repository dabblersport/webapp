# GIF picker on the deployed web build — KAN-582

Status 2026-10-20: **the picker shows "GIFs aren't available right now" on alpha.dabbler.pro because the build has no GIPHY key. This commit makes the build pass the key; the key itself is a Cloudflare Pages variable the CEO must set. No secret is in the repository.**

## Cause (read-only evidence)
- The picker (`lib/features/social/presentation/widgets/gif_picker_sheet.dart`, shared by the post composer and the chat) reads `Environment.giphyApiKey`, which comes from `--dart-define=GIPHY_API_KEY` or a local `.env`. If it is empty the picker goes straight to its unavailable state and **sends no request** (so this is not CORS and not request shape).
- `scripts/cloudflare-build.sh` passed SUPABASE_*, APP_NAME, ENVIRONMENT, GOOGLE_WEB_CLIENT_ID and MESSAGING_API_BASE_URL, but **not GIPHY_API_KEY**, and it writes `.env` empty (`: > .env`). So every web build, Production and Preview, compiled the key as empty.
- Deployed bundle check: `https://alpha.dabbler.pro/main.dart.js` contains the picker's start-up code reading `GIPHY_API_KEY` from the (empty) dotenv map only, with no compile-time value, then `if(s.length===0){state = unavailable; return}` before any request. The request shape (`api_key`, `limit=30`, `rating=pg-13`, `bundle=messaging_non_clips`) is present, so the build is current.
- **The post composer GIF picker is the same widget with the same key, so it is also unavailable on alpha** (it was before KAN-582 too; the old picker showed a generic error).

## Fix in this commit
`scripts/cloudflare-build.sh` now adds `--dart-define=GIPHY_API_KEY="${GIPHY_API_KEY:-}"`. The variable is optional: unset, the build still succeeds and the picker shows its unavailable state (composer text still works). Test: `test/core/config/web_build_giphy_define_test.dart`.

## What the CEO must do (not done by Luxor; no secret was added or read)
Add the Cloudflare Pages build variable **`GIPHY_API_KEY`** to **both** the Preview environment (this is what alpha.dabbler.pro uses) **and** Production (the two do not share values; see CLAUDE.md "Build Variables"), using the existing GIPHY key the Posts picker was meant to use. It is a client-side key (GIPHY web keys are public by design), but treat it as a normal Pages variable. Then re-deploy Alpha (push or "Retry deployment").

Not covered by this commit (report only): `.github/workflows/ios-release.yml` and `android-release.yml` also do not pass `GIPHY_API_KEY`, so store builds would show the same unavailable state until they do.

## Click-by-click test for the CEO on alpha.dabbler.pro (after the variable is set and Alpha is redeployed)
1. Open alpha.dabbler.pro on the phone (fresh load). Messages → open a 1:1 chat.
2. Tap the attach (paperclip/plus) control next to the message box. The GIF picker opens and trending GIFs load, with the GIPHY credit visible.
3. Type a word (for example "cat"). Results change. Tap one: it is sent and shows in the chat as a GIF with a "GIF · GIPHY" badge.
4. Search `qzxqzxqzx`: the empty-results message shows.
5. Turn on airplane mode, open the picker: the offline message with Try again. Turn it off and tap Try again: results load.
6. On a second account in the same chat: the GIF shows with the badge.
7. Repeat in a group chat, then in Arabic + Dark.
8. Also check Posts → new post → Search GIFs: it now works too.
If step 2 still shows "isn't available", the variable is not set in the Preview environment or the site was not redeployed after setting it.
