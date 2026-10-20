window.fichayaConsumePush = async function () {
  try {
    const cache = await caches.open('fichaya-push-open');
    const key = new Request(new URL('/__pending_push', location.origin));
    const response = await cache.match(key);
    if (!response) return '';
    await cache.delete(key);
    const item = await response.json();
    return Date.now() - item.at < 120000 ? JSON.stringify(item.data) : '';
  } catch (_) { return ''; }
};
