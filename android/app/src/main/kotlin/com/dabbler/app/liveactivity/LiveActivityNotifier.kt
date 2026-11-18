// KAN-1007: draws the Live Update. On Android 16+ (API 36) it asks for
// promotion (EXTRA_REQUEST_PROMOTED_ONGOING + ProgressStyle + a short critical text
// chip); Android decides whether to promote it. Everywhere else, or when
// promotion is not allowed, it is a standard ongoing notification on its own
// silent channel. No custom layout, no score, ETA or location.
package com.dabbler.dabblerapp.liveactivity

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.text.BidiFormatter
import android.text.format.DateFormat
import com.dabbler.dabblerapp.MainActivity
import com.dabbler.dabblerapp.R
import java.util.Date
import java.util.Locale

class LiveActivityNotifier(private val appContext: Context) {
    private val nm = appContext.getSystemService(NotificationManager::class.java)

    /** The app's chosen language (not only the device's); every string and RTL come from it. */
    private val language: String = LaLocale.pick(
        appContext.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .let { runCatching { it.getString(LANG_KEY, null) }.getOrNull() },
        @Suppress("DEPRECATION") appContext.resources.configuration.locale?.language,
    )
    // Named appLocale: inside Configuration.apply {} a bare `locale` is the
    // Configuration's own (device) field.
    private val appLocale = Locale(language)
    private val context: Context = appContext.createConfigurationContext(
        Configuration(appContext.resources.configuration).apply {
            setLocale(appLocale)
            setLayoutDirection(appLocale)
        },
    )

    fun permissionGranted(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        if (!nm.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = nm.getNotificationChannel(CHANNEL_ID)
            if (ch != null && ch.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    /** Whether this device may show it promoted (Android 16+ and the user allows it). */
    fun canPromote(): Boolean =
        Build.VERSION.SDK_INT >= 36 && nm.canPostPromotedNotifications()

    fun isShowing(id: Int): Boolean =
        nm.activeNotifications.any { it.id == id && it.tag == TAG }

    fun cancel(id: Int) = nm.cancel(TAG, id)

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        // Default importance: visible in the status bar (promotion needs more
        // than MIN), but no sound or vibration — updates arrive silently, so the
        // 30-minute reminder push stays the only alert (F-5).
        val ch = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.la_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.la_channel_description)
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        nm.createNotificationChannel(ch)
    }

    /** Draws [c] for [sessionId] as notification [id]. Returns false when permission is missing. */
    fun show(sessionId: String, id: Int, c: LaContent, dismissAtSec: Long? = null): Boolean {
        if (!permissionGranted()) return false
        ensureChannel()
        val nowSec = System.currentTimeMillis() / 1000
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID)
        else @Suppress("DEPRECATION") Notification.Builder(context)

        b.setSmallIcon(R.drawable.ic_status_bar)
            .setContentTitle(title(c))
            .setContentText(statusLine(c))
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_EVENT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(activityIntent(id, 0, LaRoutes.open(c), c, "open"))
            .setDeleteIntent(dismissIntent(sessionId, id))
        changeLine(c)?.let { b.setSubText(it) }

        // Chronometer: count down to the start, then to the scheduled end.
        val target = when {
            c.isFinal -> null
            c.startAt > nowSec -> c.startAt
            c.uiState == UiState.RUNNING -> c.runningEnd?.takeIf { it > nowSec }
            else -> null
        }
        if (target != null) {
            b.setWhen(target * 1000).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= 24) b.setChronometerCountDown(true)
        } else {
            b.setShowWhen(false)
        }

        if (c.isFinal) {
            // Ended / cancelled: swipe to dismiss, then removed.
            b.setOngoing(false).setAutoCancel(true)
            val until = (dismissAtSec ?: (nowSec + FINAL_LINGER_SEC)) - nowSec
            if (Build.VERSION.SDK_INT >= 26) b.setTimeoutAfter(until.coerceAtLeast(1) * 1000)
        } else {
            b.setOngoing(true).setAutoCancel(false)
            b.addAction(action(R.string.la_action_open, activityIntent(id, 1, LaRoutes.open(c), c, "open")))
            if (c.offersCheckIn) {
                b.addAction(action(R.string.la_action_check_in, activityIntent(id, 2, LaRoutes.checkIn(c), c, "open")))
            } else if (c.isOrganiser && c.organiserAction != null) {
                val label = if (c.organiserAction == "start") R.string.la_action_start else R.string.la_action_confirm_end
                b.addAction(action(label, activityIntent(id, 3, "/attendance/${c.eventId}", c, c.organiserAction)))
            }
        }

        // Only ask for promotion where the user allows it; otherwise it stays a
        // standard ongoing notification.
        if (canPromote()) promote(b, c, nowSec)

        nm.notify(TAG, id, b.build())
        return true
    }

    private fun promote(b: Notification.Builder, c: LaContent, nowSec: Long) {
        b.setShortCriticalText(chip(c, nowSec))
        if (c.isFinal) return
        b.addExtras(android.os.Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
        val (from, to) = when {
            c.uiState == UiState.RUNNING && c.runningEnd != null -> (c.actualStartedAt ?: c.startAt) to c.runningEnd!!
            else -> (c.startAt - CHECKIN_WINDOW_SEC) to c.startAt
        }
        val span = (to - from).coerceAtLeast(1)
        val done = ((nowSec - from).coerceIn(0, span) * 100 / span).toInt()
        b.setStyle(
            Notification.ProgressStyle()
                .setProgressSegments(listOf(Notification.ProgressStyle.Segment(100)))
                .setProgress(done),
        )
    }

    fun chip(c: LaContent, nowSec: Long): String = when (c.chip(nowSec)) {
        ChipKind.CHECK_IN -> context.getString(R.string.la_chip_check_in)
        ChipKind.CHECKED_IN -> context.getString(R.string.la_chip_checked_in)
        ChipKind.LIVE -> context.getString(R.string.la_chip_live)
        ChipKind.CHANGED -> context.getString(R.string.la_chip_changed)
        ChipKind.ENDED -> context.getString(R.string.la_chip_ended)
        ChipKind.CANCELLED -> context.getString(R.string.la_chip_cancelled)
        ChipKind.COUNTDOWN -> {
            val (hours, n) = ChipText.countdown(nowSec, c.startAt)
            context.getString(if (hours) R.string.la_chip_in_hours else R.string.la_chip_in_minutes, n)
        }
    }

    private fun title(c: LaContent): String {
        // H.3-e: names stay as entered; isolate them so mixed-direction text
        // does not reorder inside the RTL layout.
        val t = c.title ?: return context.getString(
            if (c.eventType == "meetup") R.string.la_title_meetup else R.string.la_title_game,
        )
        return BidiFormatter.getInstance(appLocale).unicodeWrap(t)
    }

    private fun time(sec: Long): String = DateFormat.getTimeFormat(context).format(Date(sec * 1000))

    private fun statusLine(c: LaContent): String = when (c.uiState) {
        UiState.CHECKIN_OPEN -> context.getString(R.string.la_status_checkin_open, time(c.startAt))
        UiState.STARTING_SOON -> context.getString(R.string.la_status_starting_soon, time(c.startAt))
        UiState.RUNNING -> c.runningEnd?.let { context.getString(R.string.la_status_running_until, time(it)) }
            ?: context.getString(R.string.la_status_running)
        UiState.ENDED -> context.getString(R.string.la_status_ended)
        UiState.CANCELLED -> context.getString(R.string.la_status_cancelled)
    }

    private fun changeLine(c: LaContent): String? = when (c.change) {
        "time" -> context.getString(R.string.la_change_time)
        "venue" -> context.getString(R.string.la_change_venue)
        else -> null
    }

    private fun action(label: Int, pi: PendingIntent): Notification.Action =
        Notification.Action.Builder(null, context.getString(label), pi).build()

    private fun activityIntent(id: Int, slot: Int, route: String, c: LaContent, action: String): PendingIntent {
        val i = Intent(Intent.ACTION_VIEW, Uri.parse(DEEP_LINK_PREFIX + route), context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_EVENT_ID, c.eventId)
            .putExtra(EXTRA_ACTION, action)
        return PendingIntent.getActivity(context, id * 4 + slot, i, PI_FLAGS)
    }

    private fun dismissIntent(sessionId: String, id: Int): PendingIntent {
        val i = Intent(context, LiveActivityDismissReceiver::class.java)
            .setAction(ACTION_DISMISSED)
            .putExtra(EXTRA_SESSION_ID, sessionId)
            .putExtra(EXTRA_NOTIFICATION_ID, id)
        return PendingIntent.getBroadcast(context, id, i, PI_FLAGS)
    }

    companion object {
        const val CHANNEL_ID = "dabbler_live_activity"
        // Notification.EXTRA_REQUEST_PROMOTED_ONGOING (API 36.1); the key is
        // spelled out because compileSdk 36 does not expose the constant, and
        // NotificationCompat.Builder.setRequestPromotedOngoing is not available:
        // this module has no direct androidx.core dependency and the builder
        // here is the platform Notification.Builder.
        const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
        const val TAG = "live_activity"
        // shared_preferences stores Dart keys in this file with a "flutter." prefix.
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val LANG_KEY = "flutter.mock_language"
        const val DEEP_LINK_PREFIX = "dabbler://app"
        const val EXTRA_EVENT_ID = "la_event_id"
        const val EXTRA_ACTION = "la_action"
        const val EXTRA_SESSION_ID = "la_session_id"
        const val EXTRA_NOTIFICATION_ID = "la_notification_id"
        const val ACTION_DISMISSED = "pro.dabbler.live_activity.DISMISSED"
        const val CHECKIN_WINDOW_SEC = 30 * 60L
        const val FINAL_LINGER_SEC = 15 * 60L
        private const val PI_FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    }
}
