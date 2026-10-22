# Share / copy-link entry points — KAN-597 rework (CEO test on alpha.dabbler.pro)

## What the CEO saw
Copying a post copied the post id, not a link. Root cause (code, read from the branch): `post_detail_screen.dart`
`_copyLink` did `Clipboard.setData(ClipboardData(text: post.id))`. The link builder (`ShareLinks`, `DeepLinks`) and the
routes for the five types existed, but not every entry point used them.

## Deployed config read (read-only, no writes)
- Web uses path URLs (`lib/url_strategy_web.dart`: `usePathUrlStrategy()`), and Cloudflare Pages serves `index.html` for
  unknown paths (no `_redirects`/404 override in `web/`), so `https://alpha.dabbler.pro/post/<id>` reaches the router.
- Routes that open the links: `/post/:postId`, `/u/:profileId` (`profile_social_routes.dart`), `/venue/:venueId`,
  `/game/:gameId` (`play_places_routes.dart`), `/meetups/:meetupId` (`meetups_routes.dart`).
- Origin: `ShareLinks.origin()` uses the browser origin on web when it is a Dabbler origin, so Alpha shares Alpha links.
- Not exercised here: no browser run on alpha (the fix is not deployed yet); no device run.

## Entry points changed
| Item | Where | Before | Now |
|---|---|---|---|
| Post | `post_detail_screen.dart` `_copyLink` (menu "Copy link" and the row's share action) | copied `post.id` | copies `ShareLinks.post(id, sharerProfileId)` |
| Venue | `venue_detail_screen.dart` share button | "Sharing coming soon" | web: copies `ShareLinks.venue(...)` + "Link copied"; native: share sheet with the link (copy if sharing fails) |
| Profile | `user_profile_screen.dart` "More" sheet | no share/copy at all | new "Copy link" copies `ShareLinks.profile(profileId, sharer)` |

Already correct, unchanged: game (detail share, listing card share) and meetup (detail, listing card) use
`RoutePaths.gameLink` / `meetupLink` → `ShareLinks`. The home feed's share glyph is the repost menu, not a link.
Own profile has no share control (not added; outside this rework's list).

No new strings: the existing `post_detail_copy_link` ("Copy link") and `sfx_link_copied` ("Link copied") keys are used (EN + AR exist).

## Click-by-click test for the CEO (after Alpha redeploys)
1. On the phone open alpha.dabbler.pro, signed in. Open any post. Tap the share arrow on the post (or ⋯ → Copy link). "Link copied" shows.
2. Paste into Notes or a chat: it must read `https://alpha.dabbler.pro/post/<long id>?sp=<your id>`, not a bare id.
3. Open that pasted link in a new browser tab: the same post opens (signed out: log in, then the post).
4. Open a venue → tap the share icon on the top right: "Link copied". Paste: `https://alpha.dabbler.pro/venue/<id>?sp=…`. Open it: the venue opens.
5. Open another player's profile → ⋯ → Copy link. Paste: `https://alpha.dabbler.pro/u/<id>?sp=…`. Open it: that profile opens.
6. Game and meetup: tap their share; the link is `…/game/<id>` and `…/meetups/<id>` on alpha.dabbler.pro; open each.
7. Repeat once in Arabic + Dark.
