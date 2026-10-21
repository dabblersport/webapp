# KAN-581: private image sharing in chats

Status: **code and tests authored on branch `alpha-luxor`; nothing is provisioned, deployed or applied.** No R2 bucket, no live D1 migration, no secret, no deploy and no paid resource was created or requested by this change. Images only: no video, audio, documents or voice notes.

Ownership, as the CEO clarified on 2026-10-20: Cloudflare D1 holds message text and the attachment records; a **private** Cloudflare R2 bucket holds the image bytes; the Messaging Worker does every upload and read; Supabase stays identity, membership and the registry. Supabase Storage is not used and no Supabase bucket was added.

## 1. The flow (ticket check 5)

```
Flutter                         Worker (src/attachments.ts)                      Stores
-------                         ----------------------------                     ------
pick image (OS picker)
  checked on device: real type + size (a convenience, not the authority)

POST /v1/conversations/{id}/attachments   raw bytes, Authorization, Idempotency-Key
                                1. cheap refusals from headers: Content-Length required, <= max  -> 413
                                2. msg_authorize (Supabase RPC, caller's own bearer): member who may SEND
                                   (non-member/removed/read-only/blocked -> typed refusal, nothing else runs)
                                3. kill switch MESSAGING_UPLOADS, R2 binding present                     -> 503
                                4. repeat of the same Idempotency-Key -> same attachment, no second object
                                5. per-user upload limit (D1 rate_limits, scope 'upload_hour')          -> 429
                                6. read the bytes, real type from the BYTES (JPEG/PNG/WebP), real size,
                                   declared Content-Type must match the bytes                           -> 415
                                7. put object  m/<conversation_id>/<attachment_id>        -------------> R2 (private)
                                8. insert record (unbound)                                -------------> D1 message_attachments
                         <-- 201 { attachment: { id, mime_type, byte_size, width, height } }   (no URL)

POST /v1/conversations/{id}/messages   { body?, attachment_ids: [id] }  Idempotency-Key
                                msg_authorize again; every id must be the caller's own, in THIS conversation,
                                unbound (or already bound to this very key on a retry); then the message is
                                inserted and the ids are bound in order (D1)
                         <-- message with attachments: [{ id, ... }]

GET /v1/attachments/{id}        Authorization
                                msg_authorize on EVERY read for the attachment's conversation; a left member
                                sees only up to their boundary; a sender the viewer blocked is hidden;
                                an unsent attachment is readable only by its uploader; every other denial is a
                                plain 404 (a signed-out caller is 401)
                         <-- bytes, Content-Type from the record, Cache-Control: private, nosniff
```

The app stores only the attachment id. There is no public bucket, no permanent signed URL and no provider secret in Flutter. A short-lived URL alone is **not** the authorisation: the Worker authorises each upload and each read against Supabase membership. The Flutter side reads with `DabblerImage(url: /v1/attachments/{id}, headers: bearer)`.

### Resources (ticket check 5)

| | Value | State |
|---|---|---|
| Worker | `dabbler-messaging-staging` (`[env.production]` in `workers/messaging/wrangler.toml`) | exists (KAN-566 evidence), free tier |
| D1 | `dabbler-messaging-staging`, binding `DB` | exists; migration `0005_message_attachments.sql` is **authored, not applied** |
| R2 bucket | proposed name `dabbler-messaging-media` | **does not exist.** Evidence: no `[[r2_buckets]]` in `wrangler.toml`, `live-worker-kan566.md` says "no R2", the architecture draft recorded 0 buckets on 2026-10-13. Read from the repo and the PM ledger only; no Cloudflare API call was made by this ticket, so operations should re-check the account read-only before creating anything |
| Binding | `MEDIA` (declared in `Env`, `src/auth.ts`) | not in `wrangler.toml` on purpose: declaring a bucket that does not exist would fail the next deploy |
| Kill switch | `MESSAGING_UPLOADS` (`off` refuses new uploads; reads keep working) | variable name only; set in the dashboard like `MESSAGING_ACCESS_MODE` |

What operations adds when approved (not committed, shown for review):

```toml
[[env.production.r2_buckets]]
binding = "MEDIA"
bucket_name = "dabbler-messaging-media"   # private; no public access, no custom domain
```

## 2. Provider boundary (ticket check 6)

* No Supabase messaging-media bucket, no Supabase copy of a message body. `test/attachments.test.ts` "provider boundary" fails the build if any Worker source file mentions Supabase Storage (`storage/v1`, `.storage.from`, signed or public URL helpers). `test/static_guard.test.ts` still bans R2 everywhere except the three files that declare or use the `MEDIA` binding.
* Authorisation is preserved on both paths: upload needs `allowed_action = send` (so a removed, blocked, suspended or read-only member cannot upload); read needs any allowed action plus the history boundary and block rules the text list already applies.
* A time-limited URL is never the authorisation. None is issued.
* The wake-up after a send is unchanged: `msg_notify` receives only the conversation id and `seq` (`src/notify.ts`). No image or caption content is in any push or realtime payload (ticket check 4).

## 3. Unresolved choices, with recommendations (ticket check 7)

None of these is approved. The numbers in the code are **provisional** and live in one file per side (`workers/messaging/src/media_policy.ts`, `lib/features/messaging/domain/image_policy.dart`); a test pins them equal. No earlier documented, approved limit was found (the Messaging brief and the architecture draft name only "size, type and count policy").

| # | Choice | Enforced now (provisional) | Recommendation |
|---|---|---|---|
| 1 | Formats | JPEG, PNG, WebP, decided from the bytes | Keep. HEIC is not accepted by the server: the OS picker is expected to turn an iOS HEIC photo into JPEG when the app asks it to downscale (not yet verified on a device). A HEIC file chosen through the file picker is refused with the unsupported-type line |
| 2 | Maximum size | 10 MiB per image, after a client downscale | Keep 10 MiB. The picker already shrinks photos to 2048 px at quality 85, which is far below it |
| 3 | Count | 4 images waiting in the tray; the Worker accepts 1 to 4 ids per message | The thread draws one image per message (the design system's Message has one attachment slot), so a tray of N is sent as N messages, caption on the first. Decide whether a multi-image message is wanted before any gallery layout is designed |
| 4 | Compression | the OS picker downscales to 2048 px, JPEG 85 | Keep. No server-side re-encode (Workers have no image library without a paid add-on) |
| 5 | Metadata (EXIF, location) | the picker's re-encode is expected to drop most EXIF (unverified on a device); the server does not strip | Confirm on a device. If a guarantee is wanted, it needs a paid image service or a client-side strip |
| 6 | Dimension cap | none (width/height are recorded, not limited) | Add a pixel cap only if decoding cost on old phones shows up |
| 7 | Quota | 40 uploads per user per hour; 20 sends per minute per conversation (existing) | Add a per-conversation daily byte quota before launch if R2 spend is a concern; the draft estimated about $22 a month with quotas against about $450 without |
| 8 | Upload lifecycle | an upload not bound to a message in a day is an orphan; **no cleanup job exists** | Needs a CEO rule (draft D25): recommend a daily Worker cron deleting unbound objects older than 24 hours. A cron trigger is not authorised here |
| 9 | Retention of sent images | none (matches "no automatic deletion yet") | Follow the message retention rule when one is approved; legal hold already pins a reported message, and its attachment rows follow it |
| 10 | Spend posture | none set | See section 4 |

Design questions Q1 to Q12, only the ones this ticket meets: Q4 is rows 1 to 4 above (not decided). Q5: the library and camera are the OS pickers and no in-app gallery is built (confirm). Q6: the GIF provider is GIPHY and the existing picker (`showGifPickerSheet`, KAN-582) is reused behind the "Search GIFs" row; the design project's missing Posts picker is not evidence the app lacks one. Q7: the viewer overflow (save, forward, report) is **not drawn**. Q9: retry is manual only. Q11: the composer keeps `ChatComposerInset` (KAN-578); the tray sits in the same bottom bar above the field, so the inset is applied once, not twice. Q1, Q2, Q3, Q8, Q10 and Q12 do not touch this ticket and were not decided.

## 4. Approvals still required, separate from UI and API readiness (ticket check 8)

**Ready to merge as code:** Worker routes, D1 migration file, Flutter client, tests. Nothing below blocks code review.

**Needed before any image can actually be sent in a deployed build** (each is an operations or CEO action; none was done or requested here):

1. **CEO approval to create R2.** The 2026-10-14 approval (`cloudflare-messaging-approval`) covered Workers and D1 only and explicitly deferred R2 and photo storage. R2 is the one product that can bill automatically (the draft: above 10 GB-month, 1 M Class A and 10 M Class B operations a month); a budget alert only notifies. Needs the CEO's spend posture (card limit, alert threshold, whether the Pages project shares the account).
2. **Operations creates the private bucket** `dabbler-messaging-media` with public access off, and adds the `MEDIA` binding block above. Bucket access is by Worker binding, so **no new secret and no S3 access key** is needed; the draft's "bucket-scoped token" is not required by this design.
3. **Operations applies** `workers/messaging/migrations/0005_message_attachments.sql` to the live D1 (needs-ops: `workers/messaging/migrations/0005_message_attachments.sql`; additive, no DROP) **before** the Worker is deployed.
4. **Operations deploys** the Worker (`npx wrangler deploy --env production`).
5. **CEO decisions** on rows 1 to 10 above (formats, size, count, compression, metadata, quota, orphan cleanup).
6. Web: Flutter web ignores image request headers (`DabblerImage` notes this), so an image will not load on the web build. Native Android and iOS are unaffected. A web path needs either a short-lived, attachment-scoped read token (a new HMAC secret, needs approval) or a design-system image that takes bytes (`DabblerImage.bytes`).

## 5. API additions

Not in `openapi.yaml` (the contract test pins its six operations); documented here.

* `POST /v1/conversations/{id}/attachments`. Headers `Authorization`, `Idempotency-Key` (UUID), `Content-Type` (must equal the sniffed type), `Content-Length`. Body: the image bytes. `201` created, `200` the same key repeated. Errors: `400 invalid_request`, `401`, `403 not_in_pilot | not_a_member | removed | suspended`, `409 game_ended | game_cancelled`, `403 left_read_only | blocked`, `413 payload_too_large`, `415 unsupported_media_type`, `429 rate_limited` (+ `Retry-After`), `503` (no bucket or kill switch).
* `POST /v1/conversations/{id}/messages` additionally accepts `attachment_ids` (1 to 4 UUIDs); `body` may then be empty. A message with images returns `attachments: [{id, mime_type, byte_size, width, height}]` (the key is omitted for text).
* `GET /v1/attachments/{id}`. `200` bytes, `401` signed out, `404` anything else.

## 6. Evidence

* Worker: `cd workers/messaging && npx vitest run` (389 tests; `test/attachments.test.ts` covers upload, limits, bad types, retry, binding, unauthorised and unsent reads, left members, blocks, kill switch, the provider boundary).
* Flutter: `test/features/messaging/images/image_repository_test.dart` (policy, wire shape, streamed upload, progress, cancel, offline, typed refusals) and `image_chat_screen_test.dart` (Share drawer, gallery, camera, file, refused picks, tray, progress and cancel, failure and retry without a duplicate, settled image, viewer; group and direct; English light and Arabic dark). Screenshots: `/Users/moataz/Desktop/Dabbler-Alpha-Plan/kan581-images/` (outside the repo).
* Not run: any device (Android emulator, iOS simulator), the real camera and photo permissions, the real OS pickers, a live Worker, R2 or D1.

## 7. Known gaps (not hidden)

* The Messages list preview of a conversation whose last message is an image comes from the `msg_my_conversations` RPC, which carries the (empty) body: it shows no text for an image-only message. Needs its own ticket and a string.
* The design's circular upload dial, the composer's own attachment strip and enabled-Send-with-photos, the dark full-screen viewer and a bytes-capable image are design-system gaps. This change composes the existing parts (linear progress bar, a tray with its own Send, a content sheet for the viewer, `Image.memory` for the local preview) and records each deviation in code. Two narrow gate allowances were added for the local preview.
* Copy: the Share drawer and upload strings come from the design; the remaining error and accessibility strings (EN and AR) are provisional and need the content seat's review.
