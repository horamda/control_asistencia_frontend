import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool?> browserPermission(String name) async {
  try {
    final status = await web.window.navigator.permissions
        .query({'name': name}.jsify()! as JSObject)
        .toDart;
    return status.state == 'granted';
  } catch (_) {
    // Older Safari versions cannot query every permission.
    return null;
  }
}

Future<bool> requestBrowserCamera() async {
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(video: true.toJS, audio: false.toJS),
        )
        .toDart;
    // Release the camera before the QR scanner opens its own stream.
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    return true;
  } catch (_) {
    return false;
  }
}
