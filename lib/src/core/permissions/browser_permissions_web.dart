import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:js_interop_unsafe';

String? browserCameraError;

@JS('fichaYaNextCamera')
external JSPromise<JSString> _selectNextCamera();

Future<String?> selectNextCamera() async {
  try {
    return (await _selectNextCamera().toDart).toDart;
  } catch (_) {
    return null;
  }
}

Future<bool?> browserPermission(String name) async {
  try {
    final status = await web.window.navigator.permissions
        .query({'name': name}.jsify()! as JSObject)
        .toDart;
    // "prompt" is not a denial. Safari may report it after a one-time grant.
    return switch (status.state) {
      'granted' => true,
      'denied' => false,
      _ => null,
    };
  } catch (_) {
    // Older Safari versions cannot query every permission.
    return null;
  }
}

Future<bool> requestBrowserCamera() async {
  browserCameraError = null;
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(
            video: {
              'facingMode': {'ideal': 'environment'},
            }.jsify()!,
            audio: false.toJS,
          ),
        )
        .toDart;
    // Release the camera before the QR scanner opens its own stream.
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    return true;
  } catch (error) {
    String name = 'UnknownError';
    try {
      name = (error as JSObject).getProperty<JSString>('name'.toJS).toDart;
    } catch (_) {}
    browserCameraError = switch (name) {
      'NotAllowedError' =>
        'El navegador o el sistema bloquearon la cámara. (CAM_PERMISSION_DENIED)',
      'NotReadableError' || 'AbortError' =>
        'No se pudo iniciar la cámara. Cerrá otras pestañas o apps que la estén usando y reintentá. (CAM_BUSY)',
      'OverconstrainedError' || 'NotFoundError' =>
        'La cámara seleccionada no está disponible. Probá otra con Cambiar cámara. (CAM_NOT_FOUND)',
      'NotSupportedError' =>
        'Este navegador no permite abrir la cámara. (CAM_UNSUPPORTED)',
      _ => 'Falló el acceso a la cámara en el navegador. (CAM_BROWSER_ERROR)',
    };
    return false;
  }
}
