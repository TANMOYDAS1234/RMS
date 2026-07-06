// Web variant of the inline 3D preview.
//
// Embeds an <iframe> that loads /ar.html (model-viewer page). Uses
// HtmlElementView with a per-URL view factory so the admin can see the
// uploaded GLB rotating right next to the photo — no button-tap, no
// tab-switch, both media assets visible for one-glance verification.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import '../../core/config/app_config.dart';

final Set<String> _registered = <String>{};

Widget buildInlineArPreview({
  required String modelUrl,
  required String itemName,
}) {
  final encodedModel = Uri.encodeComponent(modelUrl);
  final encodedName = Uri.encodeComponent(itemName);
  final src = '${AppConfig.baseUrl}/ar.html'
      '?model=$encodedModel&name=$encodedName&autoplay=1';

  // View factories are keyed by an identifier; use the URL hash so each
  // item's iframe registers exactly once. Re-registering the same
  // viewType throws in newer engine builds — guard with a Set.
  final viewType = 'ar-iframe-${src.hashCode}';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = src
        ..allow = 'autoplay; xr-spatial-tracking; fullscreen'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = '#000';
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewType);
}
