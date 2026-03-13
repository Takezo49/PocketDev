import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/connection.dart';
import '../theme/colors.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback onPaired;

  const ScanScreen({super.key, required this.onPaired});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _showManual = false;
  bool _scanned = false;
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();

  void _handleBarcode(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final data = barcode.rawValue ?? '';
    if (!data.startsWith('devbox://')) return;

    _scanned = true;
    try {
      final encoded = data.replaceFirst('devbox://', '');
      final payload = jsonDecode(utf8.decode(base64Decode(encoded)));
      final conn = context.read<DevBoxConnection>();
      conn.connect(
        payload['host'] as String,
        payload['port'] as int,
        payload['secret'] as String,
      );
      widget.onPaired();
    } catch (e) {
      _scanned = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code')),
      );
    }
  }

  void _handleManualConnect() {
    if (_hostCtrl.text.isEmpty || _portCtrl.text.isEmpty || _secretCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all fields')),
      );
      return;
    }
    final conn = context.read<DevBoxConnection>();
    final port = int.tryParse(_portCtrl.text);
    if (port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid port number')),
      );
      return;
    }
    conn.connect(_hostCtrl.text, port, _secretCtrl.text);
    widget.onPaired();
  }

  @override
  Widget build(BuildContext context) {
    if (_showManual) return _buildManual();
    return _buildScanner();
  }

  Widget _buildScanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Scan QR Code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            const Text('Point at the QR code on your desktop',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: MobileScanner(onDetect: _handleBarcode),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() => _showManual = true),
              child: const Text('Connect manually instead',
                  style: TextStyle(color: AppColors.accent, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManual() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Manual Connect',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 24),
            _input(_hostCtrl, 'Host (e.g. 192.168.1.100)'),
            const SizedBox(height: 12),
            _input(_portCtrl, 'Port (e.g. 7777)', keyboard: TextInputType.number),
            const SizedBox(height: 12),
            _input(_secretCtrl, 'Pairing secret'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleManualConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Connect',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _showManual = false),
              child: const Text('Scan QR instead',
                  style: TextStyle(color: AppColors.accent, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Widget _input(TextEditingController ctrl, String hint,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
