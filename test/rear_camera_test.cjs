const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const source = readFileSync(require('node:path').join(__dirname, '../web/rear_camera.js'), 'utf8');

function setup(getUserMedia, supported = true) {
  const devices = {getUserMedia, getSupportedConstraints: () => ({facingMode: supported})};
  vm.runInNewContext(source, {navigator: {mediaDevices: devices}, DOMException});
  return devices;
}

test('scanner preferences are replaced with mandatory rear camera', async () => {
  let received;
  const devices = setup(async constraints => {
    received = constraints;
    return {getVideoTracks: () => []};
  });
  await devices.getUserMedia({video: {facingMode: 'user', deviceId: 'front', width: 640}, audio: false});
  assert.equal(received.video.facingMode.exact, 'environment');
  assert.equal(received.video.deviceId, undefined);
  assert.equal(received.video.width, 640);
  assert.equal(received.audio, false);
});
test('front stream is stopped and rejected', async () => {
  let stopped = false;
  const track = {getSettings: () => ({facingMode: 'user'}), stop: () => {stopped = true;}};
  const devices = setup(async () => ({getVideoTracks: () => [track], getTracks: () => [track]}));
  await assert.rejects(devices.getUserMedia({video: true}), {name: 'NotReadableError'});
  assert.ok(stopped);
});
test('no fallback on unsupported rear selection or denied access', async () => {
  let calls = 0;
  const devices = setup(async () => {calls++;}, false);
  await assert.rejects(devices.getUserMedia({video: true}), {name: 'NotSupportedError'});
  assert.equal(calls, 0);
  const denied = setup(async () => {calls++; throw new DOMException('denied', 'NotAllowedError');});
  await assert.rejects(denied.getUserMedia({video: true}), {name: 'NotAllowedError'});
  assert.equal(calls, 1);
});
test('audio-only requests are unchanged', async () => {
  const constraints = {audio: true};
  const devices = setup(async value => value);
  assert.equal(await devices.getUserMedia(constraints), constraints);
});
