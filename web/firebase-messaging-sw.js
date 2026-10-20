/* Public Firebase configuration. No credentials or user JWTs belong in this file. */
self.addEventListener('notificationclick', (event) => {
  const data = event.notification.data?.FCM_MSG?.data || event.notification.data || {};
  event.stopImmediatePropagation();
  event.notification.close();

  const route = '/';
  // nginx.conf.template serves index.html for these application routes.
  const url = new URL(route, self.location.origin).href;
  event.waitUntil((async () => {
    // Keep receipt signatures out of URLs, navigation history and server logs.
    const cache = await caches.open('fichaya-push-open');
    await cache.put(new Request(new URL('/__pending_push', self.location.origin)), new Response(JSON.stringify({data, at: Date.now()}), {headers: {'Content-Type': 'application/json'}}));
    const windows = await clients.matchAll({type: 'window', includeUncontrolled: true});
    for (const client of windows) {
      if (new URL(client.url).origin === self.location.origin) {
        await client.navigate(url);
        return client.focus();
      }
    }
    return clients.openWindow(url);
  })());
});
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');
firebase.initializeApp({
  apiKey: 'AIzaSyDPUGAHFogiVfr8kWrbrJR4o2sqGByPsvI',
  authDomain: 'fichaya-917d5.firebaseapp.com',
  projectId: 'fichaya-917d5',
  storageBucket: 'fichaya-917d5.firebasestorage.app',
  messagingSenderId: '885761435547',
  appId: '1:885761435547:web:d9d260b374b68eeccfe33e'
});
firebase.messaging();
