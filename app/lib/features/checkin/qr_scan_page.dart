import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/checkin/qr_scan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef QrScannerSurfaceBuilder = Widget Function(
  BuildContext context,
  ValueChanged<String> onScan,
);

final qrScannerSurfaceBuilderProvider = Provider<QrScannerSurfaceBuilder>(
  (Ref ref) => (BuildContext context, ValueChanged<String> onScan) {
    return _LiveQrScannerSurface(onScan: onScan);
  },
);

class QrScanPage extends ConsumerStatefulWidget {
  const QrScanPage({
    super.key,
    this.initialQrToken,
  });

  final String? initialQrToken;

  @override
  ConsumerState<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends ConsumerState<QrScanPage> {
  late final TextEditingController _manualController;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.initialQrToken ?? '');

    final initialQrToken = widget.initialQrToken;
    if (initialQrToken != null && initialQrToken.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToSessionConfirm(initialQrToken.trim());
      });
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _handlePayload(String rawPayload) async {
    final qrToken = ref
        .read(qrScanControllerProvider.notifier)
        .resolvePayload(rawPayload);
    if (qrToken == null || !mounted) {
      return;
    }
    _goToSessionConfirm(qrToken);
  }

  void _goToSessionConfirm(String qrToken) {
    if (_hasNavigated || !mounted) {
      return;
    }
    _hasNavigated = true;
    final encodedToken = Uri.encodeQueryComponent(qrToken);
    context.go('${AppRoutePaths.publicSessionConfirm}?qrToken=$encodedToken');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(qrScanControllerProvider);
    final scannerSurface = ref.watch(qrScannerSurfaceBuilderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public QR session entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            'Scan the FaceCheck session QR code',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'This route stays anonymous. It only lets you enter one session, capture one check-in photo, and view this attempt result.',
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 320,
              child: scannerSurface(context, _handlePayload),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'If the emulator camera is unavailable, paste the QR payload or raw qrToken below.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'QR payload or qrToken',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _handlePayload(_manualController.text),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Load session'),
          ),
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveQrScannerSurface extends StatefulWidget {
  const _LiveQrScannerSurface({
    required this.onScan,
  });

  final ValueChanged<String> onScan;

  @override
  State<_LiveQrScannerSurface> createState() => _LiveQrScannerSurfaceState();
}

class _LiveQrScannerSurfaceState extends State<_LiveQrScannerSurface> {
  bool _handledDetection = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        MobileScanner(
          fit: BoxFit.cover,
          onDetect: (BarcodeCapture capture) {
            if (_handledDetection) {
              return;
            }
            final rawValue = capture.barcodes
                .map((Barcode barcode) => barcode.rawValue)
                .whereType<String>()
                .cast<String?>()
                .firstWhere(
                  (String? value) => value != null && value.trim().isNotEmpty,
                  orElse: () => null,
                );
            if (rawValue == null) {
              return;
            }
            _handledDetection = true;
            widget.onScan(rawValue);
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.qr_code_scanner,
              size: 72,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
