// KAN-1007: replaces firebase_messaging's FlutterFirebaseMessagingService (see
// AndroidManifest.xml). It draws Live Activity data messages natively, so they
// work with the app killed. Every message still reaches the Flutter handler
// unchanged: firebase_messaging delivers to Dart from its own broadcast
// receiver, not from this service, and a Live Activity message has no
// title/body, so Dart draws nothing for it.
package com.dabbler.dabblerapp.liveactivity

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class DabblerMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        if (LiveActivityEngine.handleData(applicationContext, remoteMessage.data)) return
        super.onMessageReceived(remoteMessage)
    }
}
