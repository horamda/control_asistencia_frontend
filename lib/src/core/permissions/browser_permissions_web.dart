import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:js_interop_unsafe';

String? browserCameraError;

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
              'facingMode': {'exact': 'environment'},
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
        'Safari o el sistema bloquearon la cámara. (CAM_PERMISSION_DENIED)',
      'NotReadableError' || 'AbortError' =>
        'No se pudo iniciar la cámara. Cerrá otras pestañas o apps que la estén usando y reintentá. (CAM_BUSY)',
      'OverconstrainedError' || 'NotFoundError' =>
        'Safari no pudo seleccionar una cámara trasera. No se abrió la frontal. (CAM_REAR_NOT_FOUND)',
      'NotSupportedError' =>
        'Este navegador no permite seleccionar la cámara trasera. (CAM_UNSUPPORTED)',
      _ => 'Falló el acceso a la cámara en el navegador. (CAM_BROWSER_ERROR)',
    };
    return false;
  }
}
