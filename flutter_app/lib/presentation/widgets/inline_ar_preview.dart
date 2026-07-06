// Cross-platform "inline 3D preview" entry point. The conditional import
// picks the web or the IO implementation at compile time so the same
// call site works everywhere:
//
//   InlineArPreview(modelUrl: item.glbUrl!, itemName: item.name)

import 'package:flutter/widgets.dart';
import 'inline_ar_preview_stub.dart'
    if (dart.library.js_interop) 'inline_ar_preview_web.dart'
    if (dart.library.io) 'inline_ar_preview_io.dart';

class InlineArPreview extends StatelessWidget {
  final String modelUrl;
  final String itemName;
  const InlineArPreview({
    super.key,
    required this.modelUrl,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context) =>
      buildInlineArPreview(modelUrl: modelUrl, itemName: itemName);
}
