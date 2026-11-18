// KAN-1007: one place that starts, updates and ends a Live Update, used by the
// FCM data path (app killed / background / foreground), the method channel and
// the debug intent. It applies the strictly-higher state_version rule against
// the persisted per-session map, and queues events for Dart.
package com.dabbler.dabblerapp.liveactivity

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

class LaError(val code: String, message: String) : Exception(message)

object LiveActivityEngine {
    // ------------------------------------------------------------ event bridge
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var sink: EventChannel.EventSink? = null

    fun attachSink(context: Context, s: EventChannel.EventSink?) {
        main.post {
            sink = s
            if (s != null) {
                reconcile(context)
                LiveActivityStore.of(context).drain().forEach { s.success(it) }
            }
        }
    }

    /** Sends to Dart when the engine listens, else keeps it for the next listen. */
    fun emit(context: Context, event: Map<String, Any?>) {
        val clean = event.filterValues { it != null }
        main.post {
            val s = sink
            if (s != null) s.success(clean) else LiveActivityStore.of(context).enqueue(clean)
        }
    }

    // ------------------------------------------------------------------ actions
    fun activityId(sessionId: String) = "la_$sessionId"

    /** Handles an FCM data message. Returns true when it was a Live Activity message. */
    fun handleData(context: Context, data: Map<String, String>): Boolean {
        if (data["type"] != "live_activity") return false
        val sessionId = data["session_id"] ?: return true
        val content = runCatching { jsonToMap(JSONObject(data["content"] ?: "{}")) }.getOrNull() ?: return true
        val version = data["state_version"]?.toLongOrNull()
        val withVersion = if (version != null) content + ("state_version" to version) else content
        runCatching {
            when (data["la_event"]) {
                "start", "update" -> apply(context, sessionId, withVersion, fromServer = true)
                "end" -> end(context, sessionId, withVersion, dismissAtSec = null, fromServer = true)
            }
        }
        return true
    }

    /**
     * Shows or updates [sessionId] with [contentMap]. Returns the held session,
     * or null when the content was older than the held version (ignored).
     */
    fun apply(context: Context, sessionId: String, contentMap: Map<*, *>, fromServer: Boolean): LaSession? {
        val c = LaContent.fromMap(contentMap) ?: throw LaError("invalid_payload", "content-state is incomplete")
        val store = LiveActivityStore.of(context)
        val notifier = LiveActivityNotifier(context)
        // Not newer (or nothing drawn): the held session, as it is.
        return store.applyIfNewer(sessionId, c.stateVersion) { held ->
            // The user swiped it away: the server does not bring it back (Dart's own start may).
            if (fromServer && held == null && store.isDismissed(sessionId)) return@applyIfNewer null
            val id = held?.notificationId ?: LaRoutes.stableNotificationId(sessionId)
            val json = mapToJson(contentMap).toString()
            if (!notifier.permissionGranted()) {
                if (!fromServer) throw LaError("permission_denied", "notifications are off")
                // Keep the newest state so re-enabling + the next app start
                // (listActive -> reconcile) can draw it.
                store.put(LaSession(sessionId, c.eventId, c.stateVersion, id, json, shown = false))
                return@applyIfNewer null
            }
            notifier.show(sessionId, id, c)
            store.markDismissed(sessionId, false)
            val s = LaSession(sessionId, c.eventId, c.stateVersion, id, json)
            store.put(s)
            if (held == null || !held.shown) {
                emit(context, mapOf(
                    "type" to "activity_token", "event_id" to c.eventId, "session_id" to sessionId,
                    "activity_id" to activityId(sessionId), "token" to id.toString(),
                ))
            }
            s
        } ?: store.get(sessionId)?.takeIf { it.shown }
    }

    fun end(context: Context, sessionId: String, contentMap: Map<*, *>?, dismissAtSec: Long?, fromServer: Boolean) {
        val store = LiveActivityStore.of(context)
        val notifier = LiveActivityNotifier(context)
        val held = store.get(sessionId)
        if (held == null) {
            if (fromServer) return
            throw LaError("not_found", "no activity for $sessionId")
        }
        val c = contentMap?.let { LaContent.fromMap(it) }
        if (c != null && !VersionRule.shouldApply(held.version, c.stateVersion)) return
        val nowSec = System.currentTimeMillis() / 1000
        val final = c ?: LaContent.fromMap(jsonToMap(JSONObject(held.contentJson)))
        val lingers = final != null && (fromServer || (dismissAtSec != null && dismissAtSec > nowSec))
        if (lingers && final != null) {
            val shown = if (final.isFinal) final else final.copy(state = "ended")
            notifier.show(sessionId, held.notificationId, shown, dismissAtSec)
        } else {
            notifier.cancel(held.notificationId)
        }
        // The version stays held so a late older push cannot bring it back.
        store.put(held.copy(version = c?.stateVersion ?: held.version))
        store.forget(sessionId)
    }

    /** User swipe-dismissed the notification. */
    fun onUserDismissed(context: Context, sessionId: String) {
        val store = LiveActivityStore.of(context)
        val held = store.get(sessionId) ?: return
        store.forget(sessionId)
        store.markDismissed(sessionId, true)
        emit(context, mapOf(
            "type" to "activity_ended", "event_id" to held.eventId, "session_id" to sessionId,
            "activity_id" to activityId(sessionId), "reason" to "user_dismissed",
        ))
    }

    /** A held session whose notification the system removed (e.g. app notifications cleared). */
    fun reconcile(context: Context) {
        val store = LiveActivityStore.of(context)
        val notifier = LiveActivityNotifier(context)
        for (s in store.all()) {
            if (!s.shown) {
                // Recorded while notifications were off: draw it once they are back.
                if (!notifier.permissionGranted()) continue
                val c = LaContent.fromMap(jsonToMap(JSONObject(s.contentJson))) ?: continue
                notifier.show(s.sessionId, s.notificationId, c)
                store.put(s.copy(shown = true))
                val token = mapOf(
                    "type" to "activity_token", "event_id" to s.eventId, "session_id" to s.sessionId,
                    "activity_id" to activityId(s.sessionId), "token" to s.notificationId.toString(),
                )
                val sk = sink
                if (sk != null) sk.success(token) else store.enqueue(token)
                continue
            }
            if (notifier.isShowing(s.notificationId)) continue
            store.forget(s.sessionId)
            val event = mapOf(
                "type" to "activity_ended", "event_id" to s.eventId, "session_id" to s.sessionId,
                "activity_id" to activityId(s.sessionId), "reason" to "system",
            )
            val sk = sink
            if (sk != null) sk.success(event) else store.enqueue(event)
        }
    }

    // --------------------------------------------------------------------- json
    fun jsonToMap(o: JSONObject): Map<String, Any?> =
        o.keys().asSequence().associateWith { k -> unwrap(o.get(k)) }

    private fun unwrap(v: Any?): Any? = when (v) {
        JSONObject.NULL -> null
        is JSONObject -> jsonToMap(v)
        is JSONArray -> (0 until v.length()).map { unwrap(v.get(it)) }
        else -> v
    }

    fun mapToJson(m: Map<*, *>): JSONObject {
        val o = JSONObject()
        m.forEach { (k, v) -> if (k is String && v != null) o.put(k, wrap(v)) }
        return o
    }

    private fun wrap(v: Any?): Any? = when (v) {
        is Map<*, *> -> mapToJson(v)
        is List<*> -> JSONArray(v.map { wrap(it) })
        else -> v
    }
}
