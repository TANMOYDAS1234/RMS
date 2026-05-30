// ─── Waiter QR Assist Scanner ────────────────────────────────────────────────
//
// Waiter taps a button → opens the camera → scans a table QR → routes
// to one of:
//   - QrOrderingScreen     (lets the waiter help the customer order)
//   - NewOrderScreen       (waiter takes the order themselves)
//   - error toast          (URL doesn't match the /t/{id}?branch=… shape)
//
// Camera permission is requested on first scan; the mobile_scanner plugin
// handles that automatically. On a denied permission the user gets the
// scanner UI's built-in error overlay.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/config/app_theme.dart';
import 'qr_ordering_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _consumed = false; // dedup: routing more than once would re-enter

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_consumed) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null || raw.isEmpty) continue;
      // Accept both full URLs and the /t/<id>?branch=<bid> shorthand.
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      final segs = uri.pathSegments;
      String? tableId;
      String? branchId;
      final tIdx = segs.indexOf('t');
      if (tIdx >= 0 && tIdx + 1 < segs.length) {
        tableId = segs[tIdx + 1];
      }
      branchId = uri.queryParameters['branch'];
      if (tableId != null && tableId.isNotEmpty && branchId != null && branchId.isNotEmpty) {
        _consumed = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QrOrderingScreen(
              tableId: tableId!,
              branchId: branchId!,
            ),
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan table QR'),
        backgroundColor: Colors.black,
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (_, state, __) => IconButton(
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () => _controller.toggleTorch(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          // Aiming reticle.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: copperAccent, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Hold the camera over a table QR code',
                style: TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
