import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';

class ConnectScreen extends StatefulWidget {
  final VoidCallback onConnected;
  const ConnectScreen({super.key, required this.onConnected});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _showManual = false;
  bool _scanned = false;
  bool _loading = false;
  bool _pressed = false;
  String? _error;
  final _codeCtrl = TextEditingController();

  void _handleBarcode(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final data = barcode.rawValue ?? '';
    if (!data.startsWith('devbox://')) return;

    _scanned = true;
    setState(() { _loading = true; _error = null; });
    HapticFeedback.heavyImpact();

    try {
      final encoded = data.replaceFirst('devbox://', '');
      final payload = jsonDecode(utf8.decode(base64Decode(encoded)));
      final auth = context.read<AuthService>();

      if (payload['relay'] != null && payload['code'] != null) {
        await auth.setRelayUrl(payload['relay'] as String);
        final err = await auth.pairDevice(payload['code'].toString());
        if (!mounted) return;
        if (err != null) {
          setState(() { _loading = false; _error = err; _scanned = false; });
        } else {
          widget.onConnected();
        }
        return;
      }
      setState(() { _loading = false; _error = 'Unrecognized QR format'; _scanned = false; });
    } catch (e) {
      _scanned = false;
      setState(() { _loading = false; _error = 'Invalid QR code'; });
    }
  }

  Future<void> _pairWithCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    HapticFeedback.mediumImpact();

    final auth = context.read<AuthService>();
    final err = await auth.pairDevice(code);
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      widget.onConnected();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _showManual ? _buildManual() : _buildScanner(),
      ),
    );
  }

  Widget _buildScanner() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 30, color: AppColors.text),
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms),

            const SizedBox(height: 20),

            const Text('Connect Desktop',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.5),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 6),

            const Text('Scan the QR code from your terminal',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

            const SizedBox(height: 32),

            // Scanner card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _loading
                    ? Container(
                        width: 280, height: 280,
                        color: AppColors.surface,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 24, height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)),
                              SizedBox(height: 12),
                              Text('Pairing...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        width: 280, height: 280,
                        child: MobileScanner(onDetect: _handleBarcode),
                      ),
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.06, end: 0, delay: 250.ms),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.red),
                    const SizedBox(width: 6),
                    Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() { _showManual = true; _error = null; });
              },
              child: const Text('Enter code manually',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildManual() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.pin_rounded, size: 30, color: AppColors.text),
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms),

            const SizedBox(height: 20),

            const Text('Enter Pair Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.5),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 6),

            const Text('From your desktop terminal',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

            const SizedBox(height: 36),

            // Code input card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: 14),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '------',
                      hintStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w700,
                        color: AppColors.textMuted.withValues(alpha: 0.2), letterSpacing: 14),
                      filled: true, fillColor: AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.textMuted, width: 1)),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _pairWithCode(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.red),
                        const SizedBox(width: 6),
                        Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  GestureDetector(
                    onTapDown: _loading ? null : (_) => setState(() => _pressed = true),
                    onTapUp: _loading ? null : (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    onTap: _loading ? null : _pairWithCode,
                    child: AnimatedScale(
                      scale: _pressed ? 0.97 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: _loading ? AppColors.surfaceLight : AppColors.text,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted))
                              : const Text('Connect', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.bg)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.06, end: 0, delay: 250.ms),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() { _showManual = false; _error = null; });
              },
              child: const Text('Scan QR instead',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }
}
