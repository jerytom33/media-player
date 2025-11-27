// Conditional import that uses the web implementation when available

export 'web_bridge_stub.dart'
    if (dart.library.html) 'web_bridge_html.dart';
