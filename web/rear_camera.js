// FichaYa uses the rear camera for its web camera flows, including the QR
// library, which otherwise sends only a preferred facingMode to Safari.
(() => {
  const devices = navigator.mediaDevices;
  if (!devices || !devices.getUserMedia) return;
  const getUserMedia = devices.getUserMedia.bind(devices);
  let selectedRearId = null;
  globalThis.fichaYaUseRearCamera = async () => {
    const cameras = (await devices.enumerateDevices()).filter(device =>
      device.kind === 'videoinput' && device.deviceId &&
      /\b(back|rear|trasera|posterior|arrière|rückkamera)\b/i.test(device.label || '') &&
      !/\b(front|frontal|user|avant)\b/i.test(device.label || ''));
    if (!cameras.length) return false;
    const index = cameras.findIndex(camera => camera.deviceId === selectedRearId);
    selectedRearId = cameras[(index + 1) % cameras.length].deviceId;
    return true;
  };
  devices.getUserMedia = async (constraints) => {
    if (!constraints || !constraints.video) return getUserMedia(constraints);
    const video = typeof constraints.video === 'object' ? {...constraints.video} : {};
    // Do not retain a previously selected front-camera device ID.
    delete video.deviceId;
    video.facingMode = {exact: 'environment'};
    function verify(stream, selectedId, exactFacingAccepted = false) {
      const tracks = stream.getVideoTracks();
      const valid = tracks.length > 0 && tracks.every(track => {
        const settings = track.getSettings();
        if (/\b(front|frontal|user|avant)\b/i.test(track.label || '')) return false;
        if (settings.facingMode === 'user') return false;
        // A fulfilled mandatory constraint is authoritative. Some browsers
        // omit facingMode and camera labels from the returned track settings.
        if (!settings.facingMode && exactFacingAccepted) return true;
        return settings.facingMode === 'environment' ||
          (selectedId && settings.deviceId === selectedId) ||
          /\b(back|rear|trasera|posterior|arrière|rückkamera)\b/i.test(track.label || '');
      });
      if (!valid) {
        stream.getTracks().forEach(track => track.stop());
        throw new DOMException('No se pudo identificar una cámara trasera.', 'OverconstrainedError');
      }
      return stream;
    }
    try {
      if (selectedRearId) {
        const selectedVideo = {...video, deviceId: {exact: selectedRearId}};
        delete selectedVideo.facingMode;
        return verify(await getUserMedia({...constraints, video: selectedVideo}), selectedRearId);
      }
      const supportsFacing = devices.getSupportedConstraints().facingMode === true;
      return verify(await getUserMedia({...constraints, video}), undefined, supportsFacing);
    } catch (error) {
      // Never retry a permission rejection or a busy-camera error.
      if (!['OverconstrainedError', 'NotFoundError', 'NotSupportedError'].includes(error.name)) throw error;
      if (!devices.enumerateDevices) throw error;
      const cameras = (await devices.enumerateDevices()).filter(device =>
        device.kind === 'videoinput' && device.deviceId &&
        /\b(back|rear|trasera|posterior|arrière|rückkamera)\b/i.test(device.label || '') &&
        !/\b(front|frontal|user|avant)\b/i.test(device.label || ''));
      // Some Safari versions expose the rear device but reject facingMode.
      // Select only explicitly identified rear cameras, never a default camera.
      let lastError = error;
      for (const camera of cameras) {
        try {
          const byDevice = {...video, deviceId: {exact: camera.deviceId}};
          delete byDevice.facingMode;
          return verify(await getUserMedia({...constraints, video: byDevice}), camera.deviceId);
        } catch (nextError) {
          lastError = nextError;
          if (!['OverconstrainedError', 'NotFoundError'].includes(nextError.name)) throw nextError;
        }
      }
      throw lastError;
    }
  };
})();
