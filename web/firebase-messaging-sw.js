/* Firebase Cloud Messaging service worker for Dabbler web push.
 * Registered automatically by the firebase_messaging Flutter web plugin
 * (default path: /firebase-messaging-sw.js).
 *
 * Messages that carry a `notification` payload (which is what the
 * send-push-notification edge function sends) are displayed automatically
 * by the SDK while the app is in the background or closed. This file only
 * needs to initialize the SDK and handle notification clicks.
 */

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

// Web app config for project dabblersportapp (public identifiers, safe here;
// keep in sync with FirebaseOptions.web in lib/firebase_options.dart).
firebase.initializeApp({
  apiKey: 'AIzaSyAcJpgCu3WnLOitf8jgkatM8DNj4xGQOrE',
  appId: '1:836345375454:web:77395477902ca7f1bf304f',
  messagingSenderId: '836345375454',
  projectId: 'dabblersportapp',
  authDomain: 'dabblersportapp.firebaseapp.com',
  storageBucket: 'dabblersportapp.firebasestorage.app',
  measurementId: 'G-RXQHPW85NV',
});

const messaging = firebase.messaging();

// Deep-link into the app at the notification's action_route (the app uses
// path URL strategy, so origin + route is a directly loadable URL).
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const fcmMsg = event.notification && event.notification.data
    ? event.notification.data.FCM_MSG
    : null;
  const route = (fcmMsg && fcmMsg.data && fcmMsg.data.action_route) || '/';
  const url = self.location.origin + (route.startsWith('/') ? route : '/' + route);

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        for (const client of windowClients) {
          if (client.url.startsWith(self.location.origin) && 'focus' in client) {
            client.navigate(url);
            return client.focus();
          }
        }
        return clients.openWindow(url);
      })
  );
});
