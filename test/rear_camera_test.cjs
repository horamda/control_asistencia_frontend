const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const source = readFileSync(require('node:path').join(__dirname, '../web/rear_camera.js'), 'utf8');

function setup(getUserMedia, supported = true) {
  const devices = {getUserMedia, getSupportedConstraints: () => ({facingMode: supported})};
  const context = {navigator: {mediaDevices: devices}, DOMException};
  vm.runInNewContext(source, context);
  devices.selectRear = () => context.fichaYaUseRearCamera();
  return devices;
}

test('scanner preferences are replaced with mandatory rear camera', async () => {
  let received;
  const devices = setup(async constraints => {
    received = constraints;
    return {getVideoTracks: () => [{getSettings: () => ({facingMode: 'environment'})}]};
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
  await assert.rejects(devices.getUserMedia({video: true}), {name: 'OverconstrainedError'});
  assert.ok(stopped);
});
test('permission rejection is not retried', async () => {
  let calls = 0;
  const denied = setup(async () => {calls++; throw new DOMException('denied', 'NotAllowedError');});
  await assert.rejects(denied.getUserMedia({video: true}), {name: 'NotAllowedError'});
  assert.equal(calls, 1);
});
test('Safari rear camera is selected by ID when facingMode fails', async () => {
  const calls = [];
  const devices = setup(async constraints => {
    calls.push(constraints);
    if (constraints.video.facingMode) throw new DOMException('constraint', 'OverconstrainedError');
    return {getVideoTracks: () => [{getSettings: () => ({deviceId: 'rear-id'})}]};
  }, false);
  devices.enumerateDevices = async () => [
    {kind: 'videoinput', deviceId: 'front-id', label: 'Front Camera'},
    {kind: 'videoinput', deviceId: 'rear-id', label: 'Back Camera'}
  ];
  await devices.getUserMedia({video: true});
  assert.equal(calls.length, 2);
  assert.equal(calls[1].video.deviceId.exact, 'rear-id');
  assert.equal(calls[1].video.facingMode, undefined);
});
test('unidentified cameras never become a default fallback', async () => {
  let calls = 0;
  const devices = setup(async () => {calls++; throw new DOMException('constraint', 'OverconstrainedError');});
  devices.enumerateDevices = async () => [{kind: 'videoinput', deviceId: 'unknown', label: ''}];
  await assert.rejects(devices.getUserMedia({video: true}), {name: 'OverconstrainedError'});
  assert.equal(calls, 1);
});
test('audio-only requests are unchanged', async () => {
  const constraints = {audio: true};
  const devices = setup(async value => value);
  assert.equal(await devices.getUserMedia(constraints), constraints);
});

test('manual rear button selects an identified rear device, never front', async () => {
  const ids = [];
  const devices = setup(async constraints => {
    const id = constraints.video.deviceId.exact;
    ids.push(id);
    return {getVideoTracks: () => [{getSettings: () => ({deviceId: id})}]};
  });
  devices.enumerateDevices = async () => [
    {kind: 'videoinput', deviceId: 'front', label: 'Front Camera'},
    {kind: 'videoinput', deviceId: 'rear1', label: 'Back Camera'},
    {kind: 'videoinput', deviceId: 'rear2', label: 'Back Wide Camera'},
  ];
  assert.equal(await devices.selectRear(), true);
  await devices.getUserMedia({video: true});
  assert.equal(await devices.selectRear(), true);
  await devices.getUserMedia({video: true});
  assert.deepEqual(ids, ['rear1', 'rear2']);
});

test('successful exact rear constraint does not require optional track metadata', async () => {
  const devices = setup(async constraints => {
    assert.equal(constraints.video.facingMode.exact, 'environment');
    return {getVideoTracks: () => [{getSettings: () => ({})}]};
  });
  await devices.getUserMedia({video: true});
});
