// KAN-1007, debug builds only: deliver a fake Live Activity data message.
//   adb shell am broadcast -n com.dabbler.dabblerapp/.liveactivity.LiveActivityDebugReceiver \
//     -a pro.dabbler.live_activity.DEBUG --es la_event start --es session_id s1 \
//     --es state_version 1 --es content '{"state":"checkin_open",...}'
package com.dabbler.dabblerapp.liveactivity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LiveActivityDebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "pro.dabbler.live_activity.DEBUG") return
        val data = mutableMapOf("type" to "live_activity")
        for (k in listOf("la_event", "session_id", "state_version", "content")) {
            intent.getStringExtra(k)?.let { data[k] = it }
        }
        LiveActivityEngine.handleData(context, data)
    }
}
