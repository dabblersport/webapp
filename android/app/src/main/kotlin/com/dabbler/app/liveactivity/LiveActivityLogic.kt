// KAN-1007: the pure half of the Android Live Update — content parsing, the
// version rule and the state → display mapping. No Android imports, so the
// JVM unit tests in src/test cover it directly.
package com.dabbler.dabblerapp.liveactivity

/** What the notification shows. Text comes from string resources per value. */
enum class UiState { CHECKIN_OPEN, STARTING_SOON, RUNNING, ENDED, CANCELLED }

/** The status chip (Live Update short critical text). */
enum class ChipKind { CHECK_IN, COUNTDOWN, CHECKED_IN, LIVE, CHANGED, ENDED, CANCELLED }

data class LaContent(
    val state: String,
    val stateVersion: Long,
    val eventId: String,
    val eventType: String,
    val title: String?,
    val startAt: Long,
    val scheduledEndAt: Long?,
    val actualStartedAt: Long?,
    val checkedIn: Boolean,
    val role: String,
    val organiserAction: String?,
    val change: String?,
    val endReason: String?,
) {
    val isOrganiser: Boolean get() = role == "organiser"

    val uiState: UiState
        get() = when {
            state == "cancelled" || endReason == "cancelled" -> UiState.CANCELLED
            state == "ended" || state == "scheduled_time_ended" || endReason != null -> UiState.ENDED
            state == "scheduled_time_running" || state == "started" -> UiState.RUNNING
            checkedIn || state == "checked_in" -> UiState.STARTING_SOON
            else -> UiState.CHECKIN_OPEN
        }

    val isFinal: Boolean get() = uiState == UiState.ENDED || uiState == UiState.CANCELLED

    /** Check in is offered only to a participant who has not checked in. */
    val offersCheckIn: Boolean
        get() = uiState == UiState.CHECKIN_OPEN && !isOrganiser

    /** The end of the running window, when known. */
    val runningEnd: Long? get() = scheduledEndAt

    /** Which chip to show at [nowSec]. */
    fun chip(nowSec: Long): ChipKind = when (uiState) {
        UiState.CANCELLED -> ChipKind.CANCELLED
        UiState.ENDED -> ChipKind.ENDED
        UiState.RUNNING -> ChipKind.LIVE
        else -> when {
            change != null -> ChipKind.CHANGED
            startAt > nowSec -> ChipKind.COUNTDOWN
            uiState == UiState.CHECKIN_OPEN -> ChipKind.CHECK_IN
            else -> ChipKind.CHECKED_IN
        }
    }

    companion object {
        /**
         * Parses a content-state map (CHANNEL_CONTRACT.md). Returns null when a
         * required key is missing or of the wrong type (`invalid_payload`).
         */
        fun fromMap(m: Map<*, *>): LaContent? {
            fun str(k: String): String? = (m[k] as? String)?.takeIf { it.isNotEmpty() }
            fun long(k: String): Long? = when (val v = m[k]) {
                is Number -> v.toLong()
                is String -> v.toLongOrNull()
                else -> null
            }
            val state = str("state") ?: return null
            val version = long("state_version") ?: return null
            val eventId = str("event_id") ?: return null
            val startAt = long("start_at") ?: return null
            return LaContent(
                state = state,
                stateVersion = version,
                eventId = eventId,
                eventType = str("event_type") ?: "game",
                title = str("title"),
                startAt = startAt,
                scheduledEndAt = long("scheduled_end_at") ?: long("end_at"),
                actualStartedAt = long("actual_started_at"),
                checkedIn = m["checked_in"] == true || m["checked_in"] == "true",
                role = str("role") ?: "participant",
                organiserAction = str("organiser_action"),
                change = str("change"),
                endReason = str("end_reason"),
            )
        }
    }
}

object VersionRule {
    /** Apply only a version strictly higher than the one held (none held: apply). */
    fun shouldApply(held: Long?, incoming: Long): Boolean = held == null || incoming > held
}

object ChipText {
    /**
     * The countdown chip's value. Minutes up to 99, then whole hours, so the
     * Arabic form ("بعد 25 د" / "بعد 2 س") stays inside the chip's width.
     */
    fun countdown(nowSec: Long, startAt: Long): Pair<Boolean, Long> {
        val mins = ((startAt - nowSec).coerceAtLeast(0) + 59) / 60
        return if (mins <= 99) false to mins.coerceAtLeast(1) else true to (mins + 59) / 60
    }
}

/** The router path a tap opens; the same routes as the app's other notification taps. */
object LaRoutes {
    fun open(c: LaContent): String =
        if (c.eventType == "meetup") "/meetups/${c.eventId}" else "/game/${c.eventId}"

    fun checkIn(c: LaContent): String = "/check-in/${c.eventId}"

    fun stableNotificationId(sessionId: String): Int {
        val h = sessionId.hashCode() and 0x7fffffff
        return 0x4C000000 or (h and 0x00ffffff)
    }
}

/** The language the Live Update is drawn in: the app's own choice, else the device's. */
object LaLocale {
    val SUPPORTED = setOf("en", "ar")

    /**
     * [pref] is FlutterSharedPreferences `flutter.mock_language`, written by
     * lib/core/providers/locale_provider.dart as a bare language code ("en" / "ar").
     */
    fun pick(pref: String?, deviceLanguage: String?): String {
        val p = pref?.trim()?.lowercase()?.substringBefore('_')?.substringBefore('-')
        if (p != null && p in SUPPORTED) return p
        val d = deviceLanguage?.lowercase()
        return if (d != null && d in SUPPORTED) d else "en"
    }

    fun isRtl(language: String): Boolean = language == "ar"
}
