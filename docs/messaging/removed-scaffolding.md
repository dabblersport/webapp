# KAN-515 — Removed dead chat scaffolding (Messaging T20)

Manifest written before deletion. The new game chat (`lib/features/messaging/**`,
`gameChatRoute`) is untouched; `FeatureFlags` is untouched.

## Evidence commands (run from repo root)

```bash
# 1. candidate discovery
grep -rli "chat\|conversation" lib/features/social lib/features/misc lib/data lib/core

# 2. importers of each candidate (path-qualified, so the new
#    lib/features/messaging/domain/models/conversation.dart is NOT matched)
for b in chat_remote_data_source chat_datasource chat_repository chat_controller \
         conversation chat_message_model conversation_type message_model \
         chat_message conversation_model; do
  echo "== $b"; grep -rlE "[/'\"]$b\.(dart|g\.dart|freezed\.dart)" lib test
done

# 3. symbol use outside the candidate set and the new messaging feature
grep -rnE "\b(ChatMessage|Conversation|ConversationModel|ChatMessageModel|MessageModel|ConversationType)\b" \
  lib test | grep -v "lib/features/messaging\|test/features/messaging\|lib/data/models/social/\|lib/features/social/data/datasources/chat_\|chat_repository.dart\|chat_controller.dart"

# 4. route references
grep -rn "socialChat" lib test
```

### Results

- (2) Importers found, all of them either another file in this deletion set, the
  barrel `lib/data/models/models.dart` (export lines only), or the path-string
  allowlist in `test/design_system_gate_test.dart`:
  - `chat_remote_data_source`, `chat_datasource`, `chat_repository`, `message_model`: **0 importers**.
  - `chat_controller`: only `test/design_system_gate_test.dart` (GateAllow path string).
  - `chat_message_model`: the 4 dead social chat files, `conversation_model.dart`, `models.dart` barrel, gate allowlist.
  - `conversation_type`: the 4 dead social chat files, `conversation.dart`, `conversation_model.dart`, `models.dart` barrel.
  - `chat_message`: `chat_message_model.dart`, `message_model.dart`, `models.dart` barrel.
  - `conversation_model`: the 4 dead social chat files, `models.dart` barrel.
  - `social/conversation.dart`: `models.dart` barrel only (the `conversation.dart` hits under
    `lib/features/messaging` / `test/features/messaging` are the NEW
    `features/messaging/domain/models/conversation.dart`, a different file).
- (3) Symbol use outside the set: **0 lines**.
- (4) `socialChatList`: referenced only by its route getter and the `app_router.dart`
  registration → dead. `socialChat`: **live** — `user_profile_screen.dart:487` pushes
  `${RoutePaths.socialChat}/$userId` from the profile "Message" action.

## (a) Deleted

| File | Lines |
|---|---|
| lib/features/social/data/datasources/chat_remote_data_source.dart | 254 |
| lib/features/social/data/datasources/chat_datasource.dart | 550 |
| lib/features/social/domain/repositories/chat_repository.dart | 230 |
| lib/features/social/presentation/controllers/chat_controller.dart | 745 |
| lib/data/models/social/chat_message_model.dart | 571 |
| lib/data/models/social/conversation_model.dart | 672 |
| lib/data/models/social/message_model.dart | 183 |
| lib/data/models/social/chat_message.dart | 38 |
| lib/data/models/social/conversation.dart | 34 |
| lib/data/models/social/conversation_type.dart | 3 |

Edits accompanying the deletions:
- `lib/data/models/models.dart`: the 5 export lines of the deleted social chat models.
- `lib/app/app_router.dart`: `socialChatListRoute` registration removed.
- `lib/app/routes/platform_routes.dart`: `socialChatListRoute` getter (the 'Chat List'
  placeholder) removed — the route getters live here, not in `app_router.dart`.
- `lib/utils/constants/route_constants.dart`: `RoutePaths.socialChatList` and
  `RouteNames.socialChatList` removed (no other reference).
- `test/app/route_inventory.golden.txt`: `/social-chat-list` line removed
  (regenerated with `UPDATE_ROUTE_GOLDEN=true flutter test test/app/route_inventory_test.dart`).
- `test/design_system_gate_test.dart`: 3 `GateAllow` entries naming the deleted
  `chat_message_model.dart` / `chat_controller.dart` removed (allowlist rows for files
  that no longer exist; no rule weakened).

No stale unit tests of the deleted files existed (grep (2) found none under `test/`
other than the gate allowlist).

Total deleted: see "Line count" below.

## (b) Kept

| Item | Live reference | Reason |
|---|---|---|
| `socialChatConversationIdRoute`, `RoutePaths.socialChat`, `RouteNames.socialChat` | `lib/features/profile/presentation/screens/profile/user_profile_screen.dart:487` | Profile "Message" pushes it; with `FeatureFlags.messaging` false its redirect sends home. Removing it would turn that tap into a GoRouter error page (behaviour change) and fixing the caller is a forbidden profile edit. |
| `socialMessagesRoute` | flag-gated route, `RoutePaths.socialMessages` | Not chat-conversation scaffolding in scope; gated by `FeatureFlags.messaging`. |
| `gameChatRoute`, `lib/features/messaging/**` | `app_router.dart` | New game chat, read-only. |
| `FeatureFlags.messaging` / chat comment in `feature_flags.dart` | flags file | Forbidden to touch. |
| `lib/data/models/social/*` other models (comment, post, friend, block_record …) | many | Not chat. |

## Line count

`git diff --shortstat` (tracked changes, before the manifest is added):

```
17 files changed, 2 insertions(+), 3317 deletions(-)
```

Deleted Dart files alone: 3,280 lines (sum of table (a)). Route count in
`test/app/route_inventory_test.dart` changed 92 -> 91 to match the regenerated golden.
