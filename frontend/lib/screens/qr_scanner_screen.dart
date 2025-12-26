import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/attendance_service.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class QRScannerScreen extends StatefulWidget {
  final String mealType;

  const QRScannerScreen({
    Key? key,
    required this.mealType,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late MobileScannerController cameraController;
  final AttendanceService _attendanceService = AttendanceService();
  bool _isProcessing = false;
  String? _message;
  bool _isSuccess = false;
  String? _enrollmentId;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      returnImage: false,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      try {
        setState(() => _isProcessing = true);
        final slot = getCurrentMealSlot();
        if (slot == null) {
          setState(() {
            _message = 'Outside meal hours. Attendance can only be marked during meal times.';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        if (slot.type != widget.mealType) {
          setState(() {
            _message = 'Attendance is only allowed for ${slot.label} right now.';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        final qrData = barcode.rawValue ?? '';
        final decodedData = jsonDecode(qrData) as Map<String, dynamic>?;

        if (decodedData == null) {
          setState(() {
            _message = 'Invalid QR code';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        final messId = decodedData['messId'] as String?;
        final mealType = decodedData['mealType'] as String?;
        final qrCodeId = decodedData['qrCodeId'] as String?;
        final qrDate = decodedData['date'] as String?;
        final generatedAt = decodedData['generatedAt'] as String?;
        final expiresAt = decodedData['expiresAt'] as String?;

        if (messId == null || mealType == null) {
          setState(() {
            _message = 'QR code missing required data';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        if (expiresAt != null) {
          final expiry = DateTime.tryParse(expiresAt);
          if (expiry != null && DateTime.now().isAfter(expiry)) {
            setState(() {
              _message = 'This QR code has expired. Please scan a new one.';
              _isSuccess = false;
              _isProcessing = false;
            });
            return;
          }
        }

        if (qrDate != null) {
          final now = DateTime.now();
          final todayStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          if (qrDate != todayStr) {
            setState(() {
              _message = 'This QR code is for a different date.';
              _isSuccess = false;
              _isProcessing = false;
            });
            return;
          }
        }

        final authProvider = context.read<UnifiedAuthProvider>();

        if (messId != authProvider.messId) {
          setState(() {
            _message = 'ERROR: This QR code is for a different mess!';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        if (mealType != slot.type) {
          setState(() {
            _message = 'QR code is for ${mealType.toUpperCase()}, not ${slot.type.toUpperCase()}';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        final alreadyMarked = await _attendanceService.isAlreadyMarked(
          messId,
          authProvider.userId ?? '',
          slot.type,
        );

        if (alreadyMarked) {
          setState(() {
            _message = 'Already marked for ${mealType.toUpperCase()} today!';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        final success = await _attendanceService.markAttendanceViaQR(
          messId: messId,
          studentId: authProvider.userId ?? '',
          mealType: slot.type,
          enrollmentId: authProvider.enrollmentId ?? '',
          studentName: authProvider.userName ?? '',
          qrCodeId: qrCodeId,
          qrGeneratedAt: generatedAt,
          qrExpiresAt: expiresAt,
        );

        if (mounted) {
          setState(() {
            if (success) {
              _message = 'Attendance marked!\n${authProvider.userName}';
              _enrollmentId = authProvider.enrollmentId;
              _isSuccess = true;

              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            } else {
              _message = 'Error marking attendance.';
              _isSuccess = false;
            }
            _isProcessing = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _message = 'Error: ${e.toString()}';
            _isSuccess = false;
            _isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR - ${widget.mealType.toUpperCase()}'),
        elevation: 0,
        backgroundColor: const Color(0xFF6200EE),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Error',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kIsWeb
                            ? 'Browser camera access needed. Enable HTTPS and camera permissions.'
                            : 'Please enable camera permissions in settings',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => cameraController.start(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_message != null)
            Container(
              color: Colors.black.withValues(alpha: 0.95),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.cancel,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _message ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      if (_enrollmentId != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'ID: $_enrollmentId',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_isProcessing && _message == null)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Processing QR code...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_message == null && !_isProcessing)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.qr_code_2, size: 48, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Point camera at QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Automatic scanning in progress',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
