import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/attendance_service.dart';
import 'package:smart_mess/screens/attendance_view_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _generateQR();
  }

  Future<void> _generateQR() async {
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
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 16),
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
                          '15 minutes',
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildQRCode(),
                        SizedBox(height: 16),
                        Text(
                          'QR Code ID: ${(_currentQR?['qrCodeId'] as String?)?.substring(0, 8) ?? "N/A"}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Instructions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
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
                        '4. Generate a new one for the next batch',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade900,
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
                    backgroundColor: Color(0xFF6200EE),
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
              color: Colors.grey[600],
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
        color: Colors.grey[200],
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final qrPayload = jsonEncode(_currentQR);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
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

