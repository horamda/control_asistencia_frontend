(() => {
  const start = document.getElementById('start');
  const stop = document.getElementById('stop');
  const preview = document.getElementById('preview');
  const result = document.getElementById('result');
  let stream;
  let run = 0;
  function close() {
    run++;
    if (stream) stream.getTracks().forEach(track => track.stop());
    stream = null;
    preview.srcObject = null;
    preview.hidden = true;
    stop.hidden = true;
    start.disabled = false;
  }
  function report(value) { result.textContent += '\n' + value; }
  start.onclick = async () => {
    close();
    const currentRun = run;
    start.disabled = true;
    stop.hidden = false;
    result.textContent = 'Diagnóstico 1\nHTTPS: ' + window.isSecureContext + '\nNavegador: ' + navigator.userAgent;
    try {
      const devices = navigator.mediaDevices;
      if (!devices?.getUserMedia) throw new Error('getUserMedia no disponible');
      report('Selección por orientación: ' + Boolean(devices.getSupportedConstraints().facingMode));
      const acquired = await devices.getUserMedia({video: {facingMode: {exact: 'environment'}}, audio: false});
      if (run !== currentRun) { acquired.getTracks().forEach(track => track.stop()); return; }
      stream = acquired;
      const track = acquired.getVideoTracks()[0];
      const settings = track.getSettings();
      report('Solicitud aceptada.\nCámara: ' + (track.label || '(sin nombre)') + '\nOrientación: ' + (settings.facingMode || '(no informada)'));
      // Do not display a stream reported as front-facing.
      if (settings.facingMode === 'user') { close(); report('El navegador devolvió la frontal: se cerró.'); return; }
      preview.srcObject = acquired;
      preview.hidden = false;
      await preview.play();
      report('Vista previa abierta. Confirmá visualmente que sea la cámara trasera.');
    } catch (error) {
      if (run !== currentRun) return;
      report('Error original: ' + error.name + '\nDetalle: ' + error.message + '\nRestricción: ' + (error.constraint || '(ninguna)'));
      close();
    }
    if (run !== currentRun && stream) return;
    try {
      const cameras = (await navigator.mediaDevices.enumerateDevices()).filter(device => device.kind === 'videoinput');
      report('Cámaras visibles: ' + cameras.length);
      cameras.forEach((device, index) => report((index + 1) + '. ' + (device.label || '(nombre oculto por el navegador)')));
    } catch (error) { report('No se pudo listar cámaras: ' + error.name); }
    start.disabled = false;
  };
  stop.onclick = close;
  window.addEventListener('pagehide', close);
  document.getElementById('copy').onclick = async () => {
    try {
      await navigator.clipboard.writeText(result.textContent);
      document.getElementById('copy-status').textContent = 'Copiado. Pegá el resultado en la conversación.';
    } catch (_) {
      document.getElementById('copy-status').textContent = 'No se pudo copiar. Podés enviar una captura del resultado.';
    }
  };
})();
