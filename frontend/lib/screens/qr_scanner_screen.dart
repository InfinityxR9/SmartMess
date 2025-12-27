import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/attendance_service.dart';
import 'package:smart_mess/utils/meal_time.dart';
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

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController cameraController;
  final AttendanceService _attendanceService = AttendanceService();
  bool _isProcessing = false;
  String? _message;
  bool _isSuccess = false;
  String? _enrollmentId;
  bool _isStartingCamera = false;
  bool _isRequestingPermission = false;
  String? _cameraError;
  PermissionStatus? _cameraPermissionStatus;

  bool get _cameraPermissionGranted {
    final status = _cameraPermissionStatus;
    return status == PermissionStatus.granted || status == PermissionStatus.limited;
  }

  bool get _isSecureContext {
    if (!kIsWeb) {
      return true;
    }
    final uri = Uri.base;
    final host = uri.host;
    return uri.scheme == 'https' || host == 'localhost' || host == '127.0.0.1';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      returnImage: false,
      autoStart: false,
      facing: CameraFacing.back,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (_cameraPermissionGranted) {
        _startCameraPreview();
      } else if (!kIsWeb) {
        _requestPermissionAndStart();
      }
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      cameraController.stop();
    }
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

        final qrData = barcode.rawValue ?? barcode.displayValue ?? '';
        final decodedData = AttendanceService.decodeQrPayload(qrData);

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

        if (messId == null || mealType == null || qrCodeId == null) {
          setState(() {
            _message = 'QR code missing required data';
            _isSuccess = false;
            _isProcessing = false;
          });
          return;
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

        final validationDate = (qrDate?.trim().isNotEmpty ?? false)
            ? qrDate!.trim()
            : DateTime.now().toIso8601String().split('T').first;
        var validatedQR = await _attendanceService.validateQRCode(
          messId: messId,
          mealType: mealType,
          qrCodeId: qrCodeId,
          dateStr: validationDate,
        );

        if (validatedQR == null) {
          if (_isQrPayloadActive(decodedData)) {
            validatedQR = decodedData;
          } else {
            setState(() {
              _message = 'This QR code is no longer active. Please scan the latest QR.';
              _isSuccess = false;
              _isProcessing = false;
            });
            return;
          }
        }

        final generatedAt = validatedQR['generatedAt'] as String?;
        final expiresAt = validatedQR['expiresAt'] as String?;

        final alreadyMarked = await _attendanceService.isAlreadyMarked(
          messId,
          slot.type,
          enrollmentId: authProvider.enrollmentId,
          studentId: authProvider.userId,
        );

        if (alreadyMarked) {
          setState(() {
            _message = 'Duplicate Attendance is not Allowed';
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

  bool _isQrPayloadActive(Map<String, dynamic> payload) {
    final expiresAtRaw = payload['expiresAt'] as String?;
    if (expiresAtRaw == null || expiresAtRaw.trim().isEmpty) {
      return false;
    }
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().isBefore(expiresAt);
  }

  Future<void> _bootstrapCamera() async {
    if (kIsWeb && !_isSecureContext) {
      setState(() {
        _cameraError = 'Camera access requires HTTPS or localhost.';
      });
      return;
    }

    try {
      final status = await Permission.camera.status;
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraPermissionStatus = status;
      });
      if (_cameraPermissionGranted) {
        await _startCameraPreview();
      } else if (!kIsWeb) {
        await _requestPermissionAndStart();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError = 'Unable to check camera permissions.';
      });
    }
  }

  String _permissionMessage(PermissionStatus status) {
    if (status.isPermanentlyDenied || status.isRestricted) {
      return kIsWeb
          ? 'Camera access is blocked in browser settings. Allow access and refresh.'
          : 'Camera permission is blocked. Open settings to allow access.';
    }
    if (status.isDenied) {
      return kIsWeb
          ? 'Camera permission denied. Click below and allow access in your browser.'
          : 'Camera permission denied. Tap below to allow access.';
    }
    return 'Camera permission not granted.';
  }

  Future<void> _requestPermissionAndStart() async {
    if (_isRequestingPermission || _isStartingCamera) {
      return;
    }

    if (kIsWeb && !_isSecureContext) {
      setState(() {
        _cameraError = 'Camera access requires HTTPS or localhost.';
      });
      return;
    }

    setState(() {
      _isRequestingPermission = true;
      _cameraError = null;
    });

    PermissionStatus status;
    try {
      status = await Permission.camera.status;
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.camera.request();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError = 'Unable to request camera permission.';
        _isRequestingPermission = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _cameraPermissionStatus = status;
      _isRequestingPermission = false;
    });

    if (_cameraPermissionGranted) {
      await _startCameraPreview();
    } else {
      setState(() {
        _cameraError = _permissionMessage(status);
      });
    }
  }

  Future<void> _startCameraPreview() async {
    if (_isStartingCamera) {
      return;
    }
    setState(() {
      _isStartingCamera = true;
      _cameraError = null;
    });

    try {
      await cameraController.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError = 'Unable to start camera. Check permissions and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStartingCamera = false;
        });
      }
    }
  }

  Widget _buildCameraGate() {
    final status = _cameraPermissionStatus;
    final isSecure = _isSecureContext;
    final isPermissionBlocked = status?.isPermanentlyDenied == true || status?.isRestricted == true;
    final canRequestCamera = !isPermissionBlocked && (!kIsWeb || isSecure);
    final infoText = _cameraError ??
        (kIsWeb && !isSecure
            ? 'Camera access on web requires HTTPS or localhost.'
            : status == null
                ? 'We need camera access to scan QR codes.'
                : _cameraPermissionGranted
                    ? 'Starting camera...'
                    : _permissionMessage(status));

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 48, color: Color(0xFF6200EE)),
              const SizedBox(height: 16),
              const Text(
                'Enable Camera to Scan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                infoText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: (_isRequestingPermission || _isStartingCamera)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  (_isRequestingPermission || _isStartingCamera) ? 'Starting...' : 'Enable Camera',
                ),
                onPressed: (!canRequestCamera || _isRequestingPermission || _isStartingCamera)
                    ? null
                    : _requestPermissionAndStart,
              ),
              if (!kIsWeb && isPermissionBlocked) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  onPressed: openAppSettings,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR - ${widget.mealType.toUpperCase()}'),
        elevation: 0,
        backgroundColor: const Color(0xFF6200EE),
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: 'Switch Camera',
              icon: const Icon(Icons.cameraswitch),
              onPressed: () async {
                try {
                  await cameraController.switchCamera();
                } catch (_) {}
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleBarcode,
            placeholderBuilder: (context, child) {
              return _buildCameraGate();
            },
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
                        onPressed: _requestPermissionAndStart,
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
