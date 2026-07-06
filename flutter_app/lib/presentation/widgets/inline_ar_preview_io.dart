// Mobile/desktop variant of the inline 3D preview — uses webview_flutter
// (Android/iOS/desktop native surface). Web is served by the sibling
// _web.dart file via conditional import.

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/config/app_config.dart';

Widget buildInlineArPreview({
  required String modelUrl,
  required String itemName,
}) {
  final encodedModel = Uri.encodeComponent(modelUrl);
  final encodedName = Uri.encodeComponent(itemName);
  // embed=1 strips the customer chrome (title bar, hint, AR button,
  // install banner) and disables the AR-launch intent so the admin
  // card only shows the rotating model.
  final viewerUrl = '${AppConfig.baseUrl}/ar.html'
      '?model=$encodedModel&name=$encodedName&autoplay=1&embed=1';
  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(viewerUrl));
  return WebViewWidget(controller: controller);
}
