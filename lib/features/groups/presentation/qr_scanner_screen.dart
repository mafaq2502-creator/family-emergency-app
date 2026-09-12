import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../notifications/presentation/notification_bell_button.dart';

import '../../../core/domain/invite_code_policy.dart';
import '../../../core/theme/app_colors.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, this.controller});
  final MobileScannerController? controller;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller =
      widget.controller ?? MobileScannerController();
  bool _processing = false;
  String? _message;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (InviteCodePolicy.validate(raw) != null) {
      if (mounted) {
        setState(
          () => _message = 'This QR does not contain a valid invitation.',
        );
      }
      return;
    }
    _processing = true;
    await _controller.stop();
    if (mounted) Navigator.pop(context, InviteCodePolicy.normalize(raw));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Scan Invitation QR'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: const [NotificationBellButton()],
    ),
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detected,
            errorBuilder: (context, error) =>
                _CameraError(onRetry: () => _controller.start()),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: kEmerald, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _message ?? 'Place the Family Emergency invitation QR inside the frame.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              color: Colors.white,
              size: 52,
            ),
            const SizedBox(height: 14),
            const Text(
              'Camera access is unavailable. Allow camera access in system settings, then retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry Camera'),
            ),
          ],
        ),
      ),
    ),
  );
}
