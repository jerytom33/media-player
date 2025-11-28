import 'dart:html' as html;
import 'dart:js' as js;

void addToolbarMessageListener(void Function(Map<String, dynamic>) callback) {
  try {
    html.window.onMessage.listen((event) {
      final d = event.data;
      if (d is Map) {
        // We expect messages targeted for flutter to identify them via target: 'flutter'
        if (d['target'] == 'flutter') {
          callback(Map<String, dynamic>.from(d));
        }
      }
    });
  } catch (e) {
    print('addToolbarMessageListener failed: $e');
  }
}

void sendMessageToToolbar(Map<String, dynamic> data) {
  try {
    final jsObj = js.JsObject.jsify(data);
    if (js.context.hasProperty('onFlutterMessage')) {
      js.context.callMethod('onFlutterMessage', [jsObj]);
    } else {
      html.window.postMessage(data, '*');
    }
  } catch (e) {
    print('sendMessageToToolbar failed: $e');
  }
}
