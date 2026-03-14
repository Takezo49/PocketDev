import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

      if (payload['host'] != null && payload['port'] != null && payload['secret'] != null) {
        await auth.saveDirectConnection(
          payload['host'] as String,
          (payload['port'] is int) ? payload['port'] as int : int.parse(payload['port'].toString()),
          payload['secret'] as String,
        );
        if (!mounted) return;
        widget.onConnected();
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
      body: DotGridBackground(
        child: SafeArea(
          child: _showManual ? _buildManual() : _buildScanner(),
        ),
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 24)],
              ),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.accent,
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, size: 24, color: AppColors.bg),
              ),
            ),

            const SizedBox(height: 20),

            Text('Connect Desktop',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w300, color: AppColors.text, letterSpacing: -0.5),
            ),

            const SizedBox(height: 6),

            Text('Scan the QR code from your terminal',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary),
            ),

            const SizedBox(height: 32),

            // Scanner
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _loading
                    ? Container(
                        width: 260, height: 260,
                        color: AppColors.surface,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textTertiary)),
                              const SizedBox(height: 12),
                              Text('Pairing...', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        width: 260, height: 260,
                        child: MobileScanner(onDetect: _handleBarcode),
                      ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.red),
                    const SizedBox(width: 6),
                    Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.red)),
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
              child: Text('Enter code manually',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary)),
            ),
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 24)],
              ),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.accent,
                ),
                child: const Icon(Icons.pin_rounded, size: 24, color: AppColors.bg),
              ),
            ),

            const SizedBox(height: 20),

            Text('Enter Pair Code',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w300, color: AppColors.text, letterSpacing: -0.5),
            ),

            const SizedBox(height: 6),

            Text('From your desktop terminal',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary),
            ),

            const SizedBox(height: 36),

            // Code input
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.text, letterSpacing: 12),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '------',
                      hintStyle: GoogleFonts.jetBrainsMono(fontSize: 32, fontWeight: FontWeight.w400,
                        color: AppColors.textFaint, letterSpacing: 12),
                      filled: true, fillColor: AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.textTertiary, width: 0.5)),
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
                        Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.red)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: _loading ? null : _pairWithCode,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _loading ? AppColors.surfaceLight : AppColors.text,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textTertiary))
                            : Text('Connect', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.bg)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() { _showManual = false; _error = null; });
              },
              child: Text('Scan QR instead',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }
}
