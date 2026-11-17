/// KAN-993 / KAN-992: the one de-dup key shared by the in-app pop-up and the
/// foreground push, so the user never sees both for one notification.
///
/// **The contract with KAN-992** (its side is `PushPresence` and
/// `pushDedupeKey` in `lib/services/notifications/`):
///
/// * A notification is named by its `notifications.id` and, when it has one,
///   its `dedupe_key`. [NotificationPresentationKey.of] makes the keys
///   `id:<notification_id>` and `dedupe:<dedupe_key>`; a push carries the
///   same two values in its data (`notification_id`, `dedupe_key`), read by
///   [NotificationPresentationKey.fromPushData]. A match on either key is the
///   same notification. KAN-992's `pushDedupeKey` (dedupe_key, else
///   notification_id) is always one of these keys.
/// * In the **foreground** the pop-up owns the alert: while the presenter is
///   mounted it sets `PushPresence.inAppBannerShows`, so the push layer skips
///   its system alert and reports the push on `foregroundPushes`. A push
///   reported with `alerted: true` (it did alert) is recorded here as shown,
///   so its Realtime row never pops too.
/// * The pop-up calls [NotificationPresentationLedger.claimPopup] before it
///   shows: false means the notification was already shown.
/// * In the **background** the push alerts as usual; the app sees no Realtime
///   row then, so there is nothing to pop.
///
/// This file has no Flutter or feature imports on purpose.
library;

/// The keys of one notification.
class NotificationPresentationKey {
  const NotificationPresentationKey._(this.keys);

  /// The keys for [notificationId] and [dedupeKey]; blank values are left out.
  factory NotificationPresentationKey.of({
    String? notificationId,
    String? dedupeKey,
  }) {
    final String id = (notificationId ?? '').trim();
    final String dedupe = (dedupeKey ?? '').trim();
    return NotificationPresentationKey._(<String>[
      if (id.isNotEmpty) 'id:$id',
      if (dedupe.isNotEmpty) 'dedupe:$dedupe',
    ]);
  }

  /// The keys from a push data payload (`notification_id`, `dedupe_key`).
  factory NotificationPresentationKey.fromPushData(Map<String, dynamic> data) {
    String? s(String k) => data[k] is String ? data[k] as String : null;
    return NotificationPresentationKey.of(
      notificationId: s('notification_id') ?? s('id'),
      dedupeKey: s('dedupe_key'),
    );
  }

  final List<String> keys;

  /// No key at all: the notification cannot be de-duplicated.
  bool get isEmpty => keys.isEmpty;
}

/// Who showed a notification.
enum NotificationSurface { popup, systemAlert }

/// Remembers which notifications were shown, by key, for this app session.
/// Bounded: the oldest keys are forgotten past [capacity].
class NotificationPresentationLedger {
  NotificationPresentationLedger({this.capacity = 256});

  /// The app's ledger.
  static final NotificationPresentationLedger instance =
      NotificationPresentationLedger();

  final int capacity;
  final Map<String, NotificationSurface> _shown =
      <String, NotificationSurface>{};

  /// Who showed [key]'s notification, or null when nobody did.
  NotificationSurface? shownBy(NotificationPresentationKey key) {
    for (final String k in key.keys) {
      final NotificationSurface? s = _shown[k];
      if (s != null) return s;
    }
    return null;
  }

  void _record(NotificationPresentationKey key, NotificationSurface by) {
    for (final String k in key.keys) {
      _shown.remove(k);
      _shown[k] = by;
    }
    while (_shown.length > capacity) {
      _shown.remove(_shown.keys.first);
    }
  }

  /// The pop-up may show [key]'s notification: true once, then false. A
  /// notification without keys always shows (nothing to match it against).
  bool claimPopup(NotificationPresentationKey key) {
    if (key.isEmpty) return true;
    if (shownBy(key) != null) return false;
    _record(key, NotificationSurface.popup);
    return true;
  }

  /// Whether the pop-up presenter is mounted (it owns foreground alerts).
  bool popupPresenterMounted = false;

  /// The push may raise a system alert for [key]. Never in the foreground
  /// while the pop-up presenter is mounted (it owns the alert there); in the
  /// background, or with no presenter, unless already shown.
  bool claimSystemAlert(
    NotificationPresentationKey key, {
    required bool foreground,
  }) {
    if (foreground && popupPresenterMounted) return false;
    if (key.isEmpty) return true;
    if (shownBy(key) != null) return false;
    _record(key, NotificationSurface.systemAlert);
    return true;
  }

  /// Records that a system alert showed [key]'s notification.
  void recordSystemAlert(NotificationPresentationKey key) {
    if (!key.isEmpty) _record(key, NotificationSurface.systemAlert);
  }

  /// Forgets everything (sign-out, tests).
  void clear() => _shown.clear();
}
