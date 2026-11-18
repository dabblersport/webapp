# Live Activity channel contract (KAN-1005)

The Swift (KAN-1006) and Kotlin (KAN-1007) halves implement exactly this. Dart side:
`live_activity_service_mobile.dart`. Server side: the payload table in
`supabase/migrations/20261118140810_kan1004b_live_activity_fixes.sql`.

## Channels

| Kind | Name |
|---|---|
| MethodChannel | `pro.dabbler/live_activity` |
| EventChannel | `pro.dabbler/live_activity/events` |

Standard message codec. All keys are snake_case strings.

## Encoding rules

- **Dates are Unix seconds** (integer). Never ISO strings, never milliseconds. Swift: decode as `Int` /
  `TimeInterval` since 1970, not as `Date` (ActivityKit's default `Date` decoding is seconds since 2001).
- **Null keys are omitted**, both from the server and across the channel. Treat a missing key as null.
- `content` is the server's content-state, passed through unchanged.

## content-state

| Key | Type | Notes |
|---|---|---|
| `state` | string | `checkin_open` `checked_in` `scheduled_time_running` `started` `cancelled` `ended` `scheduled_time_ended` |
| `state_version` | int | strictly increasing per session |
| `event_id` | string | uuid |
| `event_type` | string | `game` \| `meetup` |
| `title` | string? | |
| `start_at` | int | Unix seconds |
| `end_at`, `scheduled_end_at`, `actual_started_at` | int? | Unix seconds |
| `checked_in` | bool | |
| `role` | string | `participant` \| `organiser` |
| `organiser_action` | string? | `start` \| `confirm_end` (organiser only) |
| `change` | string? | `time` \| `venue` (update only) |
| `end_reason` | string? | `cancelled` `event_ended` `scheduled_time_ended` `left` `removed` `signed_out` `opted_out` `access_lost` |
| `lang` | string? | `en` \| `ar`: the app's chosen language (SharedPreferences `mock_language`). The native views pick their strings and layout direction from it; absent, they follow the device language. Dart adds it to every local `start`, `update` and `end` content (and to the start `attributes`); the server will include it in its pushes (separate backend task). |

## Version rule

Ignore any content whose `state_version` is not strictly higher than the last one applied to that session.
Native applies it to pushes it receives directly (APNs update, FCM data); Dart applies it to what it reads
from `rpc_live_activity_sessions`. Native reports the version it holds in `listActive`.

## Methods (Dart calls native)

| Method | Arguments | Returns |
|---|---|---|
| `getCapabilities` | none | `{supported: bool, permission: "granted"\|"denied"\|"unsupported", push_to_start: bool}` |
| `start` | `{session_id, attributes: {event_id, event_type, title?}, content}` | `{activity_id: string, push_token?: string, android_notification_id?: int}` |
| `update` | `{session_id, activity_id, content}` | null |
| `end` | `{session_id, activity_id, content?, dismissal_date?: int}` | null |
| `listActive` | none | `[{session_id, activity_id, state_version: int}]` |

- iOS: `attributes` is `DabblerActivityAttributes` (`event_id`, `event_type`, `title`); `content` is its
  `ContentState`. Start with `pushType: .token`. `push_to_start` is true on iOS 17.2+ only; below that the
  server returns the session as `needs_local_start` and Dart calls `start`.
- Android: `activity_id` is a stable string for the ongoing notification; `android_notification_id` is its
  notification id. `push_token` is absent.
- `start` for a session already shown returns the existing activity (idempotent).
- `end` with no `dismissal_date` dismisses immediately.

## Events (native sends to Dart)

Each event is a map with `type`:

| type | Keys | Dart does |
|---|---|---|
| `push_to_start_token` | `token` | `rpc_live_activity_register_push_to_start(installation_id, token)` |
| `activity_token` | `event_id, activity_id, token` (`session_id` optional) | maps event_id to a session (below), then `rpc_live_activity_register(session_id, activity_id, token, null)` |
| `activity_ended` | `event_id, activity_id?, reason: "user_dismissed"\|"system"\|"expired"` (`session_id` optional) | maps it, forgets the activity; `user_dismissed` is remembered (below). iOS: `system` when it ended without the app ending it; `expired` when it is dismissed after a server or system end (nothing after an app end); `user_dismissed` only when dismissed while still active. An app-initiated end sends nothing. |
| `tap` | `event_id, action?: "open"\|"start"\|"confirm_end"` (`session_id` optional) | reserved for routing |

Send `push_to_start_token` and each `activity_token` on every value and every rotation.

### event_id to session

An activity started by push-to-start carries only its attributes (`event_id`, `event_type`, `title`), and the
content-state has no `session_id`, so native cannot know the session. Native sends `event_id` (and
`activity_id`) in `activity_token`, `activity_ended` and `tap`. Dart maps `event_id` to `session_id` using its
last `rpc_live_activity_sessions` result for this installation. If the event is not in that result, Dart
re-reads `rpc_live_activity_sessions` once; if it is still not there, the event is dropped. Then Dart calls
`rpc_live_activity_register(session_id, activity_id, token)`. When native does send `session_id`, Dart uses it.

### Dismissed activities

On `activity_ended` with reason `user_dismissed`, Dart stores that `session_id` per installation
(SharedPreferences key `live_activity_dismissed:<installation_id>`). Sync never starts a dismissed session
locally again. Sign-out does not clear the set.

### Sync and auth

Sync runs only with a signed-in session: at app start, on sign-in (`initialSession` / `signedIn`) and on resume
(at most once per 30 s, `NotificationTiming.liveActivityResumeThrottle`). Concurrent calls share one run. A
register that fails after a local `start` is retried on the next sync. On sign-out Dart calls `end` for every
local activity and forgets them.

## Errors

`start`, `update`, `end` and `listActive` fail with a `FlutterError` / `PlatformException` whose code is one of:

| Code | When | Dart Failure category |
|---|---|---|
| `unsupported` | OS or device cannot show it | cancelled |
| `permission_denied` | user turned Live Activities off | forbidden |
| `not_found` | no activity with that `activity_id` | notFound |
| `invalid_payload` | a key missing or of the wrong type | validation |
| `limit_reached` | the OS refused (too many activities) | rateLimited |
| `internal` | anything else | unknown |

A missing plugin is mapped to `unsupported`. `getCapabilities` never fails: report `supported: false`.

## Android data message (for KAN-1007)

`{"type":"live_activity","la_event":"start|update|end","session_id":string,"state_version":string,
"content":<content-state as a JSON string>}`. Native draws it, applying the version rule.

## Server RPCs Dart calls

- `rpc_live_activity_sessions(p_installation_id)` on start and resume.
- `rpc_live_activity_register(p_session_id, p_activity_id, p_push_token, p_android_notification_id)`.
- `rpc_live_activity_register_push_to_start(p_installation_id, p_token)`.
- `rpc_live_activity_opt_out(p_installation_id, p_opted_out)`.
