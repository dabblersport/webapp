// KAN-1007: the user swiped the Live Update away → activity_ended(user_dismissed).
package com.dabbler.dabblerapp.liveactivity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LiveActivityDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != LiveActivityNotifier.ACTION_DISMISSED) return
        val sid = intent.getStringExtra(LiveActivityNotifier.EXTRA_SESSION_ID) ?: return
        LiveActivityEngine.onUserDismissed(context, sid)
    }
}
