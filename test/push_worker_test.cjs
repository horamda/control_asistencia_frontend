const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
(async () => {
  const entries = new Map();
  const cache = {
    async put(key, value) { entries.set(key.url, value); },
    async match(key) { return entries.get(key.url); },
    async delete(key) { return entries.delete(key.url); },
  };
  let click, opened, work;
  const context = {
    self: {location: {origin: 'https://app.test'}, addEventListener: (name, callback) => { if (name === 'notificationclick') click = callback; }},
    caches: {open: async () => cache},
    clients: {matchAll: async () => [], openWindow: async url => { opened = url; }},
    importScripts() {}, firebase: {initializeApp() {}, messaging() {}},
    URL, Request, Response, Date, JSON,
  };
  vm.runInNewContext(fs.readFileSync('web/firebase-messaging-sw.js', 'utf8'), context);
  const data = {tipo: 'vacaciones_equipo', ruta: '/equipo/vacaciones/12', envio_id: '3', acuse: 'test-signature'};
  click({notification: {data: {FCM_MSG: {data}}, close() {}}, stopImmediatePropagation() {}, waitUntil: p => { work = p; }});
  await work;
  assert.equal(opened, 'https://app.test/');
  assert.ok(!opened.includes(data.acuse));
  const page = {window: {}, caches: context.caches, location: {origin: 'https://app.test'}, URL, Request, Date, JSON};
  vm.runInNewContext(fs.readFileSync('web/push_navigation.js', 'utf8'), page);
  assert.deepEqual(JSON.parse(await page.window.fichayaConsumePush()), data);
  assert.equal(await page.window.fichayaConsumePush(), '');
  console.log('Push web: destino, acuse privado y consumo único verificados.');
})().catch(error => { console.error(error); process.exitCode = 1; });
