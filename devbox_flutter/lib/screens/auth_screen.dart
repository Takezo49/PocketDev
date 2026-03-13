import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuth;
  const AuthScreen({super.key, required this.onAuth});

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
  bool _pressed = false;

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.developer_mode_rounded, size: 30, color: AppColors.text),
                ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms, curve: Curves.easeOut),

                const SizedBox(height: 20),

                const Text('DevBox',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.5),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: 6),

                Text(_isLogin ? 'Welcome back' : 'Create your account',
                  style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                const SizedBox(height: 36),

                // Server URL (collapsible)
                GestureDetector(
                  onTap: () => setState(() => _showServer = !_showServer),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_showServer ? Icons.expand_less : Icons.expand_more, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      const Text('Server', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

                if (_showServer) ...[
                  const SizedBox(height: 10),
                  _field(_serverCtrl, 'Server URL', TextInputType.url, icon: Icons.dns_outlined),
                ],

                const SizedBox(height: 16),

                // Form card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      if (!_isLogin) ...[
                        _field(_nameCtrl, 'Name', TextInputType.name, icon: Icons.person_outline_rounded),
                        const SizedBox(height: 12),
                      ],
                      _field(_emailCtrl, 'Email', TextInputType.emailAddress, icon: Icons.email_outlined),
                      const SizedBox(height: 12),
                      _field(_passCtrl, 'Password', TextInputType.visiblePassword, obscure: true, icon: Icons.lock_outline_rounded),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.red),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red))),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Submit button with press animation
                      GestureDetector(
                        onTapDown: _loading ? null : (_) => setState(() => _pressed = true),
                        onTapUp: _loading ? null : (_) => setState(() => _pressed = false),
                        onTapCancel: () => setState(() => _pressed = false),
                        onTap: _loading ? null : _submit,
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
                                  : Text(_isLogin ? 'Sign in' : 'Create account',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.bg)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.06, end: 0, delay: 250.ms, duration: 400.ms),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() { _isLogin = !_isLogin; _error = null; });
                  },
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      children: [
                        TextSpan(text: _isLogin ? "Don't have an account? " : 'Already have an account? '),
                        TextSpan(
                          text: _isLogin ? 'Sign up' : 'Sign in',
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type, {bool obscure = false, IconData? icon}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: AppColors.textMuted) : null,
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textMuted, width: 1)),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}
