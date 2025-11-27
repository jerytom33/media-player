import 'dart:html' as html;
import 'dart:convert';
import 'dart:js' as js;

void registerDJControls(Map<String, dynamic> data) {
  try {
    // Pass JS object to window.registerDJControls or fallback to storing in a global variable
    final jsObj = js.JsObject.jsify(data);
    if (js.context.hasProperty('registerDJControls')) {
      js.context.callMethod('registerDJControls', [jsObj]);
    } else {
      html.window.localStorage['djControls'] = jsonEncode(data);
    }
  } catch (e) {
    // ignore
    print('registerDJControls failed: $e');
  }
}

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
