import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection.dart';
import '../theme/colors.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onScan;
  final VoidCallback onSession;

  const HomeScreen({super.key, required this.onScan, required this.onSession});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _autoTried = false;

  @override
  void initState() {
    super.initState();
    _tryAutoConnect();
  }

  Future<void> _tryAutoConnect() async {
    if (_autoTried) return;
    _autoTried = true;
    final conn = context.read<DevBoxConnection>();
    final ok = await conn.autoConnect();
    if (ok) {
      conn.addListener(_checkPaired);
    }
  }

  void _checkPaired() {
    final conn = context.read<DevBoxConnection>();
    if (conn.status == ConnectionStatus.paired) {
      conn.removeListener(_checkPaired);
      widget.onSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DevBoxConnection>(
      builder: (_, conn, __) {
        final paired = conn.status == ConnectionStatus.paired;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('DevBox',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 8),
                const Text('Control Claude from your phone',
                    style: TextStyle(fontSize: 15, color: AppColors.textMuted)),

                const SizedBox(height: 64),

                // Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: paired ? AppColors.green : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      paired
                          ? 'Connected to ${conn.hostname.isNotEmpty ? conn.hostname : "desktop"}'
                          : conn.status == ConnectionStatus.connecting
                              ? 'Connecting...'
                              : 'Not connected',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                if (paired) ...[
                  _button('Open Session', true, widget.onSession),
                  const SizedBox(height: 12),
                  _button('Disconnect', false, () => conn.disconnect()),
                ] else
                  _button('Scan QR to Connect', true, widget.onScan),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _button(String text, bool primary, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: primary ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: primary ? null : Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(text,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primary ? AppColors.bg : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}
