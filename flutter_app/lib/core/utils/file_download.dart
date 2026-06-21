// ─── Platform-conditional CSV/byte download helper ──────────────────────────
//
// On web → spawns a Blob, anchor tag with `download` attribute, click, revoke.
// On mobile/desktop → share_plus' shareXFiles which writes to a temp file and
// pops the OS share sheet ("Save to Downloads" is one option).
//
// Conditional export keeps dart:html out of the mobile build.
//
// Public API (implemented per-platform):
//   Future<void> downloadBytes({
//     required Uint8List bytes,
//     required String filename,
//     required String mimeType,
//   });

export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
