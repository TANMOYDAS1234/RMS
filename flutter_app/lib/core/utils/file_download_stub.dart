// Mobile/desktop implementation — writes bytes to a temp file then pops the
// OS share sheet via share_plus. The user can pick "Save to Downloads",
// email, etc.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    subject: filename,
  );
}
