import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/connection.dart';
import '../theme/colors.dart';

class AiTool {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final bool comingSoon;

  const AiTool({required this.id, required this.name, required this.subtitle, required this.icon, this.comingSoon = false});
}

const _tools = [
  AiTool(id: 'claude', name: 'Claude Code', subtitle: 'AI coding agent by Anthropic', icon: Icons.terminal_rounded),
  AiTool(id: 'antigravity', name: 'Antigravity', subtitle: 'Full-stack AI assistant', icon: Icons.rocket_launch_rounded, comingSoon: true),
  AiTool(id: 'aider', name: 'Aider', subtitle: 'AI pair programming in terminal', icon: Icons.code_rounded, comingSoon: true),
  AiTool(id: 'codex', name: 'Codex CLI', subtitle: 'OpenAI coding agent', icon: Icons.auto_awesome_rounded, comingSoon: true),
];

class DashboardScreen extends StatelessWidget {
  final void Function(String toolId) onSelectTool;
  final VoidCallback onDisconnect;

  const DashboardScreen({super.key, required this.onSelectTool, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final conn = context.watch<DevBoxConnection>();
    final isOnline = conn.status == ConnectionStatus.paired || conn.status == ConnectionStatus.connected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text('DevBox',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.5)),
                    ),
                    // Profile avatar
                    GestureDetector(
                      onTap: () => _showSettings(context, auth),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceLight,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            (auth.email ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // Device card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Device icon with status ring
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surfaceLight,
                          border: Border.all(
                            color: isOnline ? AppColors.green.withValues(alpha: 0.4) : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(Icons.laptop_mac_rounded, size: 22,
                          color: isOnline ? AppColors.text : AppColors.textMuted),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(auth.deviceHostname ?? 'Desktop',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 7, height: 7,
                                  decoration: BoxDecoration(shape: BoxShape.circle,
                                    color: isOnline ? AppColors.green : AppColors.textMuted),
                                ),
                                const SizedBox(width: 6),
                                Text(isOnline ? 'Connected' : 'Offline',
                                  style: TextStyle(fontSize: 12,
                                    color: isOnline ? AppColors.textSecondary : AppColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Connection indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.green.withValues(alpha: 0.1) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(isOnline ? 'Live' : 'Off',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: isOnline ? AppColors.green : AppColors.textMuted)),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.05, end: 0),
            ),

            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('AI Tools',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                    ),
                    Text('${_tools.where((t) => !t.comingSoon).length} available',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
            ),

            // Tool cards
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final tool = _tools[i];
                    final canOpen = !tool.comingSoon && isOnline;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ToolCard(
                        tool: tool,
                        canOpen: canOpen,
                        onTap: canOpen ? () {
                          HapticFeedback.mediumImpact();
                          onSelectTool(tool.id);
                        } : null,
                      ),
                    ).animate()
                      .fadeIn(delay: (250 + i * 80).ms, duration: 300.ms)
                      .slideY(begin: 0.08, end: 0, delay: (250 + i * 80).ms, duration: 300.ms);
                  },
                  childCount: _tools.length,
                ),
              ),
            ),

            // Bottom spacer
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              // User info
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceLight,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text((auth.email ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.email ?? '', style: const TextStyle(fontSize: 15, color: AppColors.text)),
                        Text(auth.deviceHostname ?? 'No device',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _settingsBtn('Unpair device', Icons.link_off_rounded, () {
                Navigator.pop(context);
                onDisconnect();
              }),
              const SizedBox(height: 8),
              _settingsBtn('Sign out', Icons.logout_rounded, () {
                Navigator.pop(context);
                auth.logout();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  final AiTool tool;
  final bool canOpen;
  final VoidCallback? onTap;

  const _ToolCard({required this.tool, required this.canOpen, this.onTap});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.canOpen ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.canOpen ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.canOpen ? AppColors.border : AppColors.border.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.canOpen ? AppColors.surfaceLight : AppColors.surface,
                ),
                child: Icon(widget.tool.icon, size: 24,
                  color: widget.canOpen ? AppColors.text : AppColors.textMuted.withValues(alpha: 0.4)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.tool.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: widget.canOpen ? AppColors.text : AppColors.textMuted.withValues(alpha: 0.5))),
                    const SizedBox(height: 3),
                    Text(widget.tool.subtitle,
                      style: TextStyle(fontSize: 12,
                        color: widget.canOpen ? AppColors.textSecondary : AppColors.textMuted.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.tool.comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('Soon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                )
              else
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.canOpen ? AppColors.text : AppColors.surfaceLight,
                  ),
                  child: Icon(Icons.arrow_forward_rounded, size: 16,
                    color: widget.canOpen ? AppColors.bg : AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
