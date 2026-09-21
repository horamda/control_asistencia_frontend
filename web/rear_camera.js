// FichaYa uses the rear camera for its web camera flows, including the QR
// library, which otherwise sends only a preferred facingMode to Safari.
(() => {
  const devices = navigator.mediaDevices;
  if (!devices || !devices.getUserMedia) return;
  const getUserMedia = devices.getUserMedia.bind(devices);
  devices.getUserMedia = async (constraints) => {
    if (!constraints || !constraints.video) return getUserMedia(constraints);
    if (!devices.getSupportedConstraints().facingMode) {
      throw new DOMException('No se puede seleccionar la cámara trasera en este navegador.', 'NotSupportedError');
    }
    const video = typeof constraints.video === 'object' ? {...constraints.video} : {};
    // Do not retain a previously selected front-camera device ID.
    delete video.deviceId;
    video.facingMode = {exact: 'environment'};
    const stream = await getUserMedia({...constraints, video});
    if (stream.getVideoTracks().some(track => track.getSettings().facingMode === 'user')) {
      stream.getTracks().forEach(track => track.stop());
      throw new DOMException('El navegador seleccionó la cámara frontal. Se requiere la trasera.', 'NotReadableError');
    }
    return stream;
  };
})();
