package com.dabbler.dabblerapp

import android.content.Intent
import android.os.Bundle
import com.dabbler.dabblerapp.liveactivity.LiveActivityEngine
import com.dabbler.dabblerapp.liveactivity.LiveActivityNotifier
import com.dabbler.dabblerapp.liveactivity.LiveActivityPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // KAN-1007: the Live Activity channels (CHANNEL_CONTRACT.md).
        flutterEngine.plugins.add(LiveActivityPlugin())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) reportLiveActivityTap(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        reportLiveActivityTap(intent)
    }

    // The deep link itself (dabbler://app/game/<id>, /meetups/<id>, /check-in/<id>)
    // is routed by Flutter like every other notification tap; Dart also hears `tap`.
    private fun reportLiveActivityTap(intent: Intent?) {
        val eventId = intent?.getStringExtra(LiveActivityNotifier.EXTRA_EVENT_ID) ?: return
        LiveActivityEngine.emit(applicationContext, mapOf(
            "type" to "tap",
            "event_id" to eventId,
            "action" to intent.getStringExtra(LiveActivityNotifier.EXTRA_ACTION),
        ))
        intent.removeExtra(LiveActivityNotifier.EXTRA_EVENT_ID)
    }
}
