// Shared camera selection for permission requests and the QR scanner.
(() => {
  const devices = navigator.mediaDevices;
  if (!devices || !devices.getUserMedia) return;
  const getUserMedia = devices.getUserMedia.bind(devices);
  let selectedId = null;
  let activeId = null;
  globalThis.fichaYaNextCamera = async () => {
    const cameras = (await devices.enumerateDevices()).filter(device =>
      device.kind === 'videoinput' && device.deviceId);
    if (!cameras.length) return '';
    const index = cameras.findIndex(camera => camera.deviceId === (selectedId || activeId));
    const next = (index + 1) % cameras.length;
    selectedId = cameras[next].deviceId;
    return cameras[next].label || ('Camara ' + (next + 1) + ' de ' + cameras.length);
  };
  devices.getUserMedia = async (constraints) => {
    if (!constraints || !constraints.video) return getUserMedia(constraints);
    const video = typeof constraints.video === 'object' ? {...constraints.video} : {};
    if (selectedId) {
      delete video.facingMode;
      video.deviceId = {exact: selectedId};
    } else {
      delete video.deviceId;
      video.facingMode = {ideal: 'environment'};
    }
    // An explicit selection is never silently replaced with another device.
    // Failed IDs remain selected so the next tap advances to the next camera.
    const stream = await getUserMedia({...constraints, video});
    const track = stream.getVideoTracks()[0];
    if (track) activeId = track.getSettings().deviceId || selectedId;
    return stream;
  };
})();
