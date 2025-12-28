import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/attendance_service.dart';
import 'package:smart_mess/screens/attendance_view_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class QRGeneratorScreen extends StatefulWidget {
  final String mealType;

  const QRGeneratorScreen({
    Key? key,
    required this.mealType,
  }) : super(key: key);

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  bool _isGenerating = false;
  Map<String, dynamic>? _currentQR;
  String? _error;
  Timer? _expiryTimer;
  Duration? _timeLeft;

  @override
  void initState() {
    super.initState();
    _generateQR();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateQR() async {
    if (_isGenerating) {
      return;
    }
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    final authProvider = context.read<UnifiedAuthProvider>();

    try {
      final qrData = await _attendanceService.generateQRCode(
        authProvider.messId ?? '',
        widget.mealType,
        authProvider.userId ?? '',
      );

      if (mounted) {
        setState(() {
          _currentQR = qrData;
          _isGenerating = false;
        });
        _startExpiryCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}';
          _isGenerating = false;
        });
      }
    }
  }

  void _startExpiryCountdown() {
    _expiryTimer?.cancel();
    final expiresAtRaw = _currentQR?['expiresAt'] as String?;
    if (expiresAtRaw == null) {
      return;
    }

    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) {
      return;
    }

    setState(() {
      _timeLeft = expiresAt.difference(DateTime.now());
    });

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = expiresAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        timer.cancel();
        setState(() {
          _timeLeft = Duration.zero;
        });
        _generateQR();
      } else {
        setState(() {
          _timeLeft = remaining;
        });
      }
    });
  }

  String _formatTimeLeft() {
    final remaining = _timeLeft;
    if (remaining == null) {
      return '15:00';
    }
    if (remaining.isNegative) {
      return '00:00';
    }
    final totalSeconds = remaining.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate QR - ${widget.mealType.toUpperCase()}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger, fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generateQR,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (_isGenerating)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40),
                      CircularProgressIndicator(),
                      SizedBox(height: 24),
                      Text('Generating QR code...'),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              if (_currentQR != null && !_isGenerating) ...[
                Card(
                  elevation: 2,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR Code Ready',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow('Meal Type', widget.mealType.toUpperCase()),
                        _buildInfoRow('Status', 'Active'),
                        _buildInfoRow(
                          'Expires In',
                          _formatTimeLeft(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outline, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildQRCode(),
                        SizedBox(height: 16),
                        Text(
                          'QR Code ID: ${(_currentQR?['qrCodeId'] as String?)?.substring(0, 8) ?? "N/A"}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Instructions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        '1. Display this QR code on screen or print it\n'
                        '2. Students scan with their phones\n'
                        '3. QR expires in 15 minutes\n'
                        '4. A fresh QR is generated automatically after expiry',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Generate New QR'),
                  onPressed: _generateQR,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: Icon(Icons.people),
                  label: Text('View Attendance'),
                  onPressed: () {
                    final authProvider = context.read<UnifiedAuthProvider>();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => AttendanceViewScreen(
                        messId: authProvider.messId ?? '',
                        mealType: widget.mealType,
                        date: (_currentQR?['date'] as String?) ??
                            DateTime.now().toIso8601String().split('T').first,
                        qrCodeId: _currentQR?['qrCodeId'] as String?,
                      ),
                    ));
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.inkMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode() {
    if (_currentQR == null) {
      return Container(
        width: 240,
        height: 240,
        color: AppColors.outlineSubtle,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final qrPayload = AttendanceService.encodeQrPayload(_currentQR!);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.ink),
      ),
      child: QrImageView(
        data: qrPayload,
        version: QrVersions.auto,
        size: 240.0,
        gapless: true,
      ),
    );
  }
}


