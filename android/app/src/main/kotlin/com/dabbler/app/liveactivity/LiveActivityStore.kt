// KAN-1007: the persisted per-session map (version held, notification id,
// last content) and the queue of events Dart has not heard yet.
//
// ONE instance per process (LiveActivityStore.of): every lock below is on that
// instance, so the version check-and-set in applyIfNewer is atomic across the
// FCM service thread, the method channel and the main looper.
package com.dabbler.dabblerapp.liveactivity

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

data class LaSession(
    val sessionId: String,
    val eventId: String,
    val version: Long,
    val notificationId: Int,
    val contentJson: String,
    /** False when the push was recorded while notifications were off and nothing is drawn yet. */
    val shown: Boolean = true,
)

/** The storage the store needs; SharedPreferences in the app, a map in JVM tests. */
interface LaKv {
    fun getString(key: String): String?
    fun getLong(key: String): Long?
    fun getBoolean(key: String): Boolean
    fun keys(): Set<String>
    fun edit(block: LaKvEditor.() -> Unit)
}

interface LaKvEditor {
    fun putString(key: String, value: String)
    fun putLong(key: String, value: Long)
    fun putBoolean(key: String, value: Boolean)
    fun remove(key: String)
}

private class PrefsKv(private val prefs: SharedPreferences) : LaKv {
    override fun getString(key: String) = prefs.getString(key, null)
    override fun getLong(key: String) = if (prefs.contains(key)) prefs.getLong(key, -1) else null
    override fun getBoolean(key: String) = prefs.getBoolean(key, false)
    override fun keys(): Set<String> = prefs.all.keys
    override fun edit(block: LaKvEditor.() -> Unit) {
        val e = prefs.edit()
        object : LaKvEditor {
            override fun putString(key: String, value: String) { e.putString(key, value) }
            override fun putLong(key: String, value: Long) { e.putLong(key, value) }
            override fun putBoolean(key: String, value: Boolean) { e.putBoolean(key, value) }
            override fun remove(key: String) { e.remove(key) }
        }.block()
        e.apply()
    }
}

class LiveActivityStore internal constructor(private val kv: LaKv) {

    @Synchronized
    fun get(sessionId: String): LaSession? {
        val raw = kv.getString(KEY + sessionId) ?: return null
        return runCatching {
            val o = JSONObject(raw)
            LaSession(
                sessionId, o.getString("e"), o.getLong("v"), o.getInt("n"), o.getString("c"),
                o.optBoolean("s", true),
            )
        }.getOrNull()
    }

    @Synchronized
    fun put(s: LaSession) {
        val o = JSONObject()
            .put("e", s.eventId).put("v", s.version).put("n", s.notificationId).put("c", s.contentJson)
            .put("s", s.shown)
        kv.edit { putString(KEY + s.sessionId, o.toString()) }
    }

    /** The version only, kept after the notification is gone so a late older push stays ignored. */
    @Synchronized
    fun heldVersion(sessionId: String): Long? =
        get(sessionId)?.version ?: kv.getLong(VKEY + sessionId)?.takeIf { it >= 0 }

    /**
     * Runs [block] only when [version] is strictly higher than the held one,
     * with the store locked for the whole check-and-set. Returns null when the
     * version was not newer, else what [block] returned.
     */
    @Synchronized
    fun <T> applyIfNewer(sessionId: String, version: Long, block: (held: LaSession?) -> T): T? {
        if (!VersionRule.shouldApply(heldVersion(sessionId), version)) return null
        return block(get(sessionId))
    }

    @Synchronized
    fun forget(sessionId: String) {
        val v = get(sessionId)?.version
        kv.edit {
            remove(KEY + sessionId)
            if (v != null) putLong(VKEY + sessionId, v)
        }
    }

    @Synchronized
    fun isDismissed(sessionId: String): Boolean = kv.getBoolean(DKEY + sessionId)

    @Synchronized
    fun markDismissed(sessionId: String, dismissed: Boolean) {
        kv.edit { if (dismissed) putBoolean(DKEY + sessionId, true) else remove(DKEY + sessionId) }
    }

    @Synchronized
    fun all(): List<LaSession> = kv.keys()
        .filter { it.startsWith(KEY) }
        .mapNotNull { get(it.removePrefix(KEY)) }

    @Synchronized
    fun bySessionForNotification(id: Int): LaSession? = all().firstOrNull { it.notificationId == id }

    @Synchronized
    fun enqueue(event: Map<String, Any?>) {
        val arr = JSONArray(kv.getString(PENDING) ?: "[]")
        arr.put(JSONObject(event.filterValues { it != null }))
        while (arr.length() > 50) arr.remove(0)
        kv.edit { putString(PENDING, arr.toString()) }
    }

    @Synchronized
    fun drain(): List<Map<String, Any?>> {
        val arr = JSONArray(kv.getString(PENDING) ?: "[]")
        kv.edit { remove(PENDING) }
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            o.keys().asSequence().associateWith { o.get(it) }
        }
    }

    companion object {
        private const val KEY = "s:"
        private const val VKEY = "v:"
        private const val DKEY = "d:"
        private const val PENDING = "pending_events"

        @Volatile private var instance: LiveActivityStore? = null

        /** The process-wide store, created once from the application context. */
        fun of(context: Context): LiveActivityStore = instance ?: synchronized(this) {
            instance ?: LiveActivityStore(
                PrefsKv(
                    context.applicationContext
                        .getSharedPreferences("dabbler_live_activity", Context.MODE_PRIVATE),
                ),
            ).also { instance = it }
        }
    }
}
