// Stub — never actually loaded; the conditional import in
// inline_ar_preview.dart resolves to the web or io variant. This file
// exists so the analyzer has a concrete symbol when compiling for
// platforms neither branch covers (e.g. tooling paths).

import 'package:flutter/widgets.dart';

Widget buildInlineArPreview({
  required String modelUrl,
  required String itemName,
}) =>
    const SizedBox.shrink();
