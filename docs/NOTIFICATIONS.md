# Dabbler Notifications — Current Capabilities

> Status snapshot as of 2026-07-11 (branch `Canary`). Covers **in-app notifications** and **push notifications** only.
> Supabase project `wtncuzcskpigqpmnxwws` · Firebase project `dabblersportapp`.

## What the system can do today

### Delivery channels
| Channel | Status | How |
|---|---|---|
| In-app feed | ✅ Live | `notifications` table → realtime + paginated feed in `NotificationsScreenV2` |
| Push (iOS/Android) | ✅ Live | DB trigger → `send-push-notification` edge function → FCM HTTP v1 |
| Broadcast (all users) | ✅ Live | Admin-only `broadcast-notification` edge function → FCM topic **and** in-app feed rows |
| Email / SMS | ❌ Not implemented | Columns/toggles exist (`notification_settings`) but nothing sends |
| Web push (Chrome) | ✅ Live | FCM web push: VAPID token via `push_notification_service_web.dart`, background delivery + click deep-linking via `web/firebase-messaging-sw.js`; tokens stored with `platform: 'web'`. No topic subscriptions on web, so broadcasts reach web users in-app only. |

### Notification types that fire automatically
Every type below is created **server-side by a database trigger** — the app never inserts notifications (client INSERT is blocked by RLS).

| Event | Kind | Push? |
|---|---|---|
| New user signs up (profile created) | `auth.welcome` | ✅ (usually in-app only — no FCM token yet) |
| Friend request sent / accepted | `friend.requested` / `friend.accepted` | ✅ |
| Someone likes your post / comment | `social.post_liked` / `social.comment_liked` | ✅ (aggregated) |
| Someone comments on your post | `social.post_commented` | ✅ |
| Someone reacts to your post | `social.post_reacted` | ✅ |
| Mentioned in a post / comment | `social.mentioned_in_post` / `social.mentioned_in_comment` | ✅ |
| New follower | `social.followed` | ✅ |
| Someone joins your circle | `social.circle_joined` | in-app only |
| Game invite | `game.invited` | ✅ |
| Game join request | `game.join_request` | ✅ |
| Player joined your game / meetup | `game.player_joined` / `meetup.player_joined` | ✅ |
| Game updated / cancelled | `game.updated` | ✅ |
| Promoted from game waitlist | `game.waitlist_promoted` | ✅ |
| Meetup / squad invite | `meetup.invited` / `squad.invited` | ✅ |
| Badge earned | `reward.badge_awarded` | in-app only |
| Admin broadcast | `system.announcement` | ✅ (via FCM topic) + in-app row per active user |
| Content report / user block (to admins) | `moderation.report_submitted` / `moderation.user_blocked` | report: ✅ / block: in-app |

Registered but **not yet wired** (no trigger attached): `arena.payment_required` (payment-required bookings), `game.reminder` (game starts soon — kind exists, no scheduler).

### Smart delivery (server-side, automatic)
- **Aggregation** — bursty kinds (e.g. likes) coalesce per (user, kind, entity) within a rules-driven window (`notification_aggregation_rules`); a pg_cron job flushes expired windows every 10 seconds into single "N people liked…" notifications.
- **Spam guard** — 10-second dedup window per (user, kind, entity, actor); unique index prevents duplicate post-like notifications.
- **Self-notification suppression** — you never get notified about your own actions.
- **Block enforcement** — pushes between blocked users are skipped.
- **Invalid token pruning** — FCM tokens rejected as UNREGISTERED/invalid are deleted automatically.
- **Title generation** — server generates human titles ("Sara liked your post") from the actor's display name; the app can re-localize titles (EN/AR) from `kind_key` + payload.

### User preferences (enforced server-side before any push)
Backed by `notification_settings`, editable in **Settings → Notifications**:
- Master **push on/off** toggle (also email/SMS toggles — stored, not yet acted on).
- **Per-kind mutes**, grouped in the UI as Game / Social / Connections.
- **Quiet hours** — start/end times, timezone-aware (default `Asia/Dubai`), wraps midnight; with two escape hatches: *allow urgent only* (high/urgent priority) or *allow all*.
- Muting only suppresses the **push** — the in-app row is always created.

### In-app feed capabilities (Flutter)
- Paginated feed (keyset, 20/page) with **live realtime inserts** (Supabase Realtime on `notifications`, auto re-subscribe on app resume).
- **Unread count badge** (caps at 99+), mark-one-read, **mark-all-read**, click tracking (atomic RPC bumps `interaction_count` + `clicked_at`).
- Filter chips by domain (game / bookings / social / rewards) via `kind_key` prefix.
- **Deep-linking**: tapping a notification routes via `action_route` (or a per-kind fallback map) — post detail, user profile, game detail, friends list, rewards.
- Localized titles (EN/AR) and per-kind icons/colors.
- Feed route is gated by `FeatureFlags.notifications` (currently **on**).

### Push capabilities (device side)
- FCM tokens stored per (user, platform) in `fcm_tokens`; refreshed automatically on token rotation.
- **Foreground** pushes shown as local notifications (Android channel `default_channel`, max importance — created at init and declared in the manifest for background delivery).
- **Background/terminated** taps deep-link into the app (`action_route` in the data payload).
- Topic subscriptions: `announcements` + platform topic (`ios`/`android`) for broadcasts.
- Permission UX: silent OS request at launch, plus a "Stay Updated" prompt drawer on Home (allow / remind in 72h / never) and a real permission step in social onboarding.
- iOS: APNs wired via `FirebaseApp.configure()` + `aps-environment` entitlement; Android 13+ `POST_NOTIFICATIONS` permission declared.

### Scheduled local notifications
- Daily **check-in streak reminder** (24h out, timezone-correct) — local only, used by the rewards feature.

## Security model (summary)
- RLS everywhere: users can only read/update/delete **their own** notifications, tokens, and settings; client-side inserts are impossible.
- Push dispatch is server-to-server: DB trigger → edge function authenticated by a Vault-stored shared secret (constant-time compared); FCM uses OAuth2 service-account (HTTP v1).
- Broadcast requires an authenticated **admin** (`is_admin` RPC); its in-app fan-out RPC is executable by `service_role` only.

## Known limits (honest list)
- No email/SMS delivery despite stored toggles.
- No web push.
- No game-reminder scheduler (`game.reminder` kind is dormant) and no `arena.payment_required` trigger attached.
- Background FCM handler does no work (no badge-count updates while backgrounded).
- Android status-bar icon uses the app launcher icon — a proper white silhouette asset (`ic_notification`) is still needed from design.
- Welcome push usually lands in-app only (token doesn't exist yet at signup).

## Key references
| Layer | Where |
|---|---|
| Schema snapshot (source of truth copy) | `supabase/schema/snapshots/notification_schema_snapshot.sql` |
| Fan-out engine SQL | `supabase/schema/migrations/baseline_notification_engine.sql` (+ later migrations in same dir) |
| Edge functions | `supabase/functions/send-push-notification/`, `supabase/functions/broadcast-notification/` |
| Feed / settings UI | `lib/features/notifications/`, `lib/features/profile/.../settings/notification_settings_screen.dart` |
| Push service | `lib/services/notifications/push_notification_service_mobile.dart` |
| Table/RPC name constants | `lib/core/config/supabase_config.dart` |
