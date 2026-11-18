// KAN-1007: the Android half of CHANNEL_CONTRACT.md (KAN-1005).
package com.dabbler.dabblerapp.liveactivity

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LiveActivityPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, METHODS).also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, EVENTS).also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        LiveActivityEngine.attachSink(context, null)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) =
        LiveActivityEngine.attachSink(context, sink)

    override fun onCancel(arguments: Any?) = LiveActivityEngine.attachSink(context, null)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getCapabilities" -> result.success(capabilities())
                "start" -> result.success(start(call))
                "update" -> { update(call); result.success(null) }
                "end" -> { end(call); result.success(null) }
                "listActive" -> result.success(listActive())
                else -> result.notImplemented()
            }
        } catch (e: LaError) {
            result.error(e.code, e.message, null)
        } catch (e: Exception) {
            result.error("internal", e.message, null)
        }
    }

    private fun capabilities(): Map<String, Any> {
        val granted = runCatching { LiveActivityNotifier(context).permissionGranted() }.getOrDefault(false)
        return mapOf(
            "supported" to true,
            "permission" to if (granted) "granted" else "denied",
            "push_to_start" to false,
        )
    }

    private fun sessionId(call: MethodCall): String =
        call.argument<String>("session_id")?.takeIf { it.isNotEmpty() }
            ?: throw LaError("invalid_payload", "session_id is missing")

    private fun content(call: MethodCall): Map<*, *> =
        call.argument<Map<*, *>>("content") ?: throw LaError("invalid_payload", "content is missing")

    private fun start(call: MethodCall): Map<String, Any> {
        val sid = sessionId(call)
        val raw = content(call)
        val attrs = call.argument<Map<*, *>>("attributes") ?: emptyMap<String, Any>()
        // Attributes fill keys the content-state may lack (event_id, event_type, title).
        val merged = attrs.filterKeys { it is String && raw[it] == null } + raw
        if (!LiveActivityNotifier(context).permissionGranted()) throw LaError("permission_denied", "notifications are off")
        val s = LiveActivityEngine.apply(context, sid, merged, fromServer = false)
            ?: throw LaError("permission_denied", "notifications are off")
        return mapOf("activity_id" to LiveActivityEngine.activityId(sid), "android_notification_id" to s.notificationId)
    }

    private fun update(call: MethodCall) {
        val sid = sessionId(call)
        val store = LiveActivityStore.of(context)
        val held = store.get(sid) ?: throw LaError("not_found", "no activity for $sid")
        val old = LiveActivityEngine.jsonToMap(org.json.JSONObject(held.contentJson))
        LiveActivityEngine.apply(context, sid, old + content(call).mapKeys { it.key as String }, fromServer = false)
    }

    private fun end(call: MethodCall) {
        val sid = sessionId(call)
        val dismissal = (call.argument<Any>("dismissal_date") as? Number)?.toLong()
        LiveActivityEngine.end(context, sid, call.argument<Map<*, *>>("content"), dismissal, fromServer = false)
    }

    private fun listActive(): List<Map<String, Any>> {
        LiveActivityEngine.reconcile(context)
        return LiveActivityStore.of(context).all().map {
            mapOf("session_id" to it.sessionId, "activity_id" to LiveActivityEngine.activityId(it.sessionId), "state_version" to it.version)
        }
    }

    companion object {
        const val METHODS = "pro.dabbler/live_activity"
        const val EVENTS = "pro.dabbler/live_activity/events"
    }
}
