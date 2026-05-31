// ─── Per-Table QR Sheet ──────────────────────────────────────────────────────
//
// Opens from the manager Tables tab. Renders the table's customer-facing
// QR (linking to <QR_WEB_URL>/t/<tableId>?branch=<branchId>) and lets
// the manager:
//   - Copy the URL to clipboard
//   - Share the QR image (share_plus)
//   - Print/save as PDF (printing package)
//
// The PNG bytes are rendered off-screen with RepaintBoundary so the
// shared/printed image is crisp at any size, not a screenshot.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../../core/config/app_theme.dart';
import '../../core/config/system_config_provider.dart';

class TableQrSheet extends ConsumerStatefulWidget {
  final String tableId;
  final String tableLabel;
  final String branchId;
  final String? branchName;
  const TableQrSheet({
    super.key,
    required this.tableId,
    required this.tableLabel,
    required this.branchId,
    this.branchName,
  });

  @override
  ConsumerState<TableQrSheet> createState() => _TableQrSheetState();
}

class _TableQrSheetState extends ConsumerState<TableQrSheet> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _busy = false;

  /// Resolved from the runtime config provider, which itself falls back
  /// to the page origin (web) or AppConfig (mobile) when the server
  /// hasn't responded yet. Either way every code path here gets a
  /// usable URL — no build-time --dart-define needed.
  String get _url {
    final base = ref
        .read(runtimeQrWebBaseUrlProvider)
        .replaceFirst(RegExp(r'/+$'), '');
    return '$base/t/${widget.tableId}?branch=${widget.branchId}';
  }

  /// Render the off-screen QR widget to a high-res PNG. We use a fixed
  /// pixel ratio so the image is sharp at any print size.
  Future<Uint8List?> _renderPng() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _renderPng();
      if (png == null) {
        _snack('Failed to render QR.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/qr-${widget.tableLabel.replaceAll(' ', '_')}.png');
      await f.writeAsBytes(png);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'image/png')],
        text: 'Scan to order — ${widget.tableLabel}',
      ));
    } catch (e) {
      _snack('Share failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _renderPng();
      if (png == null) {
        _snack('Failed to render QR.');
        return;
      }
      // Single-page A4 PDF: big QR centered, label + branch above, URL
      // below. The receipt-style 58mm sheet is wrong here — these stickers
      // get printed on a real printer and stuck on the table.
      final doc = pw.Document();
      final mem = pw.MemoryImage(png);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(widget.branchName ?? 'DINE OPS',
                    style: pw.TextStyle(
                        fontSize: 26, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Table ${widget.tableLabel}',
                    style: pw.TextStyle(
                        fontSize: 20, color: PdfColors.grey700)),
                pw.SizedBox(height: 24),
                pw.Container(
                  width: 380,
                  height: 380,
                  child: pw.Image(mem),
                ),
                pw.SizedBox(height: 24),
                pw.Text('Scan to view menu, order, and pay',
                    style: pw.TextStyle(
                        fontSize: 16, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text(_url,
                    style: pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey500)),
              ],
            ),
          ),
        ),
      );
      final bytes = await doc.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      _snack('Print failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: _url));
    _snack('URL copied to clipboard');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        Text('Table ${widget.tableLabel} QR',
            style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
            'Print this and stick it on the table. Customers scan with their phone camera — no app install required.',
            style: TextStyle(color: textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        // RepaintBoundary so we can render the white-on-black QR to PNG
        // at print-quality resolution.
        RepaintBoundary(
          key: _repaintKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: QrImageView(
              data: _url,
              size: 240,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: slateSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(
              child: Text(_url,
                  style: const TextStyle(
                      color: textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined,
                  color: copperAccent, size: 18),
              tooltip: 'Copy URL',
              onPressed: _copyUrl,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('Share PNG'),
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                side: BorderSide(color: textSecondary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800),
              ),
              onPressed: _busy ? null : _share,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: copperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800),
              ),
              onPressed: _busy ? null : _print,
            ),
          ),
        ]),
      ]),
    );
  }
}
