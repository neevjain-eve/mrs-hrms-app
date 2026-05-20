import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _scanned = false;
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned || _processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() { _scanned = true; _processing = true; });
    controller.stop();

    try {
      final raw = barcode!.rawValue!;
      final data = Map<String, dynamic>.from(
        (raw.startsWith('{')) ? {} : {'code': raw}
      );

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (_) {}

      final result = await ref.read(apiServiceProvider).checkIn(
        lat: pos?.latitude,
        lng: pos?.longitude,
        source: 'qr',
        qrCode: data['code'] ?? raw,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'QR Check-in successful!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
        await Future.delayed(const Duration(seconds: 1));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('QR Error: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() { _scanned = false; _processing = false; });
        controller.start();
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Attendance')),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          // Overlay
          CustomPaint(painter: _ScanOverlayPainter(), child: const SizedBox.expand()),
          // Instructions
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _processing ? 'Processing...' : 'Point camera at attendance QR code',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          if (_processing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    const box = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: box, height: box);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Corner accents
    final accent = Paint()..color = AppTheme.primary..strokeWidth = 4..style = PaintingStyle.stroke;
    const r = 16.0; const len = 28.0;
    final tl = rect.topLeft;
    final tr = rect.topRight;
    final bl = rect.bottomLeft;
    final br = rect.bottomRight;
    for (final corner in [(tl, 1.0, 1.0), (tr, -1.0, 1.0), (bl, 1.0, -1.0), (br, -1.0, -1.0)]) {
      final (c, sx, sy) = corner;
      canvas.drawLine(c.translate(sx * r, 0), c.translate(sx * (r + len), 0), accent);
      canvas.drawLine(c.translate(0, sy * r), c.translate(0, sy * (r + len)), accent);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
