import 'dart:js_interop';

@JS('fichayaConsumePush')
external JSPromise<JSString> _consume();
Future<String> consumeWebPush() async {
  try {
    return (await _consume().toDart).toDart;
  } catch (_) {
    return '';
  }
}
