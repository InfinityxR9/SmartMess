import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/attendance_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class QRScannerScreen extends StatefulWidget {
  final String mealType; // breakfast, lunch, or dinner

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
  String? _studentName;
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

        // Parse QR data
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

        if (messId == null || mealType == null) {
          setState(() {
            _message = 'QR code missing required data';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        // Get auth provider
        final authProvider = context.read<UnifiedAuthProvider>();

        // CRITICAL: Verify mess isolation - student can only scan for their own mess
        if (messId != authProvider.messId) {
          setState(() {
            _message = 'ERROR: This QR code is for a different mess!\nYou cannot mark attendance here.';
            _isSuccess = false;
            _isProcessing = false;
          });
          // Security: Log mess mismatch attempts internally
          return;
        }

        // CRITICAL: Verify meal type matches
        if (mealType != widget.mealType) {
          setState(() {
            _message = 'QR code is for ${mealType.toUpperCase()}, not ${widget.mealType.toUpperCase()}';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        // Check if already marked
        final alreadyMarked = await _attendanceService.isAlreadyMarked(
          messId,
          authProvider.userId ?? '',
          mealType,
        );

        if (alreadyMarked) {
          setState(() {
            _message = 'You have already marked attendance for ${mealType.toUpperCase()} today!';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
        }

        // Mark attendance
        final success = await _attendanceService.markAttendanceViaQR(
          messId,
          authProvider.userId ?? '',
          mealType,
          authProvider.enrollmentId ?? '',
          authProvider.userName ?? '',
        );

        if (mounted) {
          setState(() {
            if (success) {
              _message = '✓ Attendance marked successfully!\n${authProvider.userName}';
              _studentName = authProvider.userName;
              _enrollmentId = authProvider.enrollmentId;
              _isSuccess = true;

              // Auto-close after 2 seconds
              Future.delayed(Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            } else {
              _message = 'Error marking attendance.\nPlease try again.';
              _isSuccess = false;
            }
            _isProcessing = false;
          });
        }
      } catch (e) {
        // Handle parsing and processing errors silently, show to user
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
        backgroundColor: Color(0xFF6200EE),
      ),
      body: Stack(
        children: [
          // Camera view
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
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Camera Error',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        kIsWeb 
                          ? 'Please ensure your browser has camera permissions enabled and you are accessing via HTTPS.'
                          : 'Please check camera permissions in settings',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          cameraController.start();
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                );
              };
            },
          ),

          // Processing overlay with student details
          if (_message != null)
            Container(
              color: Colors.black.withValues(alpha: 0.95),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(32),
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
                      SizedBox(height: 24),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      if (_studentName != null) ...[
                        SizedBox(height: 16),
                        Text(
                          'ID: ${_enrollmentId ?? "N/A"}',
                          style: TextStyle(
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

          // Loading indicator
          if (_isProcessing && _message == null)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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

          // Instructions overlay
          if (_message == null && !_isProcessing)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
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
                        color: Colors.grey[300],
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
