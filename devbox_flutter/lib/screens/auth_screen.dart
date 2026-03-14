import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuth;
  final VoidCallback? onSkip;
  const AuthScreen({super.key, required this.onAuth, this.onSkip});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _showServer = false;
  String? _error;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  late final TextEditingController _serverCtrl;

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: context.read<AuthService>().relayUrl);
  }

  Future<void> _submit() async {
    final authSvc = context.read<AuthService>();
    final serverUrl = _serverCtrl.text.trim();
    if (serverUrl.isNotEmpty && serverUrl != authSvc.relayUrl) {
      await authSvc.setRelayUrl(serverUrl);
    }

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Fill in all fields');
      return;
    }

    setState(() { _loading = true; _error = null; });
    HapticFeedback.lightImpact();

    String? err;
    if (_isLogin) {
      err = await authSvc.login(email, pass);
    } else {
      err = await authSvc.register(email, pass, name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim());
    }

    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      widget.onAuth();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DotGridBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with glow
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          blurRadius: 24,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.accent,
                      ),
                      child: const Icon(Icons.code_rounded, size: 26, color: AppColors.bg),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text('PocketDev',
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w300, color: AppColors.text, letterSpacing: -0.5),
                  ),

                  const SizedBox(height: 4),

                  Text('Control AI from your pocket',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textFaint, letterSpacing: 0.5)),

                  const SizedBox(height: 8),

                  Text(_isLogin ? 'Welcome back' : 'Create your account',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary),
                  ),

                  const SizedBox(height: 32),

                  // Server URL (collapsible)
                  GestureDetector(
                    onTap: () => setState(() => _showServer = !_showServer),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_showServer ? Icons.expand_less : Icons.expand_more, size: 14, color: AppColors.textFaint),
                        const SizedBox(width: 4),
                        Text('Server', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textFaint)),
                      ],
                    ),
                  ),

                  if (_showServer) ...[
                    const SizedBox(height: 10),
                    _field(_serverCtrl, 'Server URL', TextInputType.url),
                  ],

                  const SizedBox(height: 16),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                      color: AppColors.surface.withValues(alpha: 0.5),
                    ),
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          _field(_nameCtrl, 'Name', TextInputType.name),
                          const SizedBox(height: 12),
                        ],
                        _field(_emailCtrl, 'Email', TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _field(_passCtrl, 'Password', TextInputType.visiblePassword, obscure: true),

                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: AppColors.red.withValues(alpha: 0.08),
                              border: Border.all(color: AppColors.red.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.red),
                                const SizedBox(width: 6),
                                Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.red))),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Submit
                        GestureDetector(
                          onTap: _loading ? null : _submit,
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
                                  : Text(_isLogin ? 'Sign in' : 'Create account',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.bg)),
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
                      setState(() { _isLogin = !_isLogin; _error = null; });
                    },
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
                        children: [
                          TextSpan(text: _isLogin ? "Don't have an account? " : 'Already have an account? '),
                          TextSpan(
                            text: _isLogin ? 'Sign up' : 'Sign in',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (widget.onSkip != null) ...[
                    const SizedBox(height: 28),
                    CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: DashedLinePainter(color: AppColors.borderSubtle),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: widget.onSkip,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_rounded, size: 14, color: AppColors.textFaint),
                          const SizedBox(width: 6),
                          Text('Skip — connect on same WiFi',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textFaint)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5)),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}
