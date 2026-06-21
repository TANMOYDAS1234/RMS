// Web implementation — Blob + anchor tag click + revokeObjectUrl.
// Only compiled for web (dart.library.html guard in file_download.dart).

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Browser keeps the URL alive until next GC otherwise; revoke now to free.
  html.Url.revokeObjectUrl(url);
}
