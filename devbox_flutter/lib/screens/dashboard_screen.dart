import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
      body: DotGridBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Top bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo mark with glow
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              blurRadius: 16,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.accent,
                          ),
                          child: const Icon(Icons.code_rounded, size: 16, color: AppColors.bg),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('PocketDev',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w300, color: AppColors.text, letterSpacing: -0.5)),
                      ),
                      // Profile avatar
                      GestureDetector(
                        onTap: () => _showSettings(context, auth),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceLight,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: Text(
                              (auth.email ?? 'U')[0].toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Device card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isOnline ? AppColors.accent.withValues(alpha: 0.2) : AppColors.border),
                      color: isOnline ? AppColors.accentGlow : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isOnline ? AppColors.accentBg : AppColors.surfaceLight,
                          ),
                          child: Icon(Icons.laptop_mac_rounded, size: 20,
                            color: isOnline ? AppColors.accent : AppColors.textTertiary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(auth.deviceHostname ?? 'Desktop',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(shape: BoxShape.circle,
                                      color: isOnline ? AppColors.accent : AppColors.textTertiary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(isOnline ? 'Connected' : 'Offline',
                                    style: GoogleFonts.inter(fontSize: 12,
                                      color: isOnline ? AppColors.textMuted : AppColors.textTertiary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: isOnline ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                            border: Border.all(color: isOnline ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border),
                          ),
                          child: Text(isOnline ? 'Live' : 'Off',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600,
                              color: isOnline ? AppColors.accent : AppColors.textTertiary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Dashed divider + section label
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                  child: Column(
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 1),
                        painter: DashedLinePainter(color: AppColors.border),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text('AI TOOLS',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2.5)),
                          ),
                          Text('${_tools.where((t) => !t.comingSoon).length} available',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.accent.withValues(alpha: 0.6))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Tool cards
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final tool = _tools[i];
                      final canOpen = !tool.comingSoon && isOnline;
                      final isActive = !tool.comingSoon;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ToolCard(
                          tool: tool,
                          canOpen: canOpen,
                          isActive: isActive,
                          onTap: canOpen ? () {
                            HapticFeedback.mediumImpact();
                            onSelectTool(tool.id);
                          } : null,
                        ),
                      );
                    },
                    childCount: _tools.length,
                  ),
                ),
              ),

              // Footer
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 1),
                        painter: DashedLinePainter(color: AppColors.borderSubtle),
                      ),
                      const SizedBox(height: 16),
                      Text('v0.1.0',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textFaint)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: AppColors.border),
            left: BorderSide(color: AppColors.border),
            right: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 32, height: 3,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceLight,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text((auth.email ?? 'U')[0].toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.email ?? '', style: GoogleFonts.inter(fontSize: 14, color: AppColors.text)),
                          Text(auth.deviceHostname ?? 'No device',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: DashedLinePainter(color: AppColors.border),
                ),
                const SizedBox(height: 16),
                _settingsBtn('Unpair device', Icons.link_off_rounded, () {
                  Navigator.pop(context);
                  onDisconnect();
                }),
                const SizedBox(height: 6),
                _settingsBtn('Sign out', Icons.logout_rounded, () {
                  Navigator.pop(context);
                  auth.logout();
                }),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  final AiTool tool;
  final bool canOpen;
  final bool isActive;
  final VoidCallback? onTap;

  const _ToolCard({required this.tool, required this.canOpen, required this.isActive, this.onTap});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final comingSoon = widget.tool.comingSoon;

    return GestureDetector(
      onTapDown: widget.canOpen ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.canOpen ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.surfaceLight
              : active
                  ? AppColors.surface
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _pressed
                ? AppColors.accent.withValues(alpha: 0.25)
                : active
                    ? AppColors.border
                    : AppColors.borderSubtle.withValues(alpha: 0.3),
          ),
        ),
        child: Opacity(
          opacity: comingSoon ? 0.3 : 1.0,
          child: Row(
            children: [
              // Icon with accent bg for active
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: active ? AppColors.accentBg : Colors.transparent,
                ),
                child: Icon(widget.tool.icon, size: 20,
                  color: active ? AppColors.accent : AppColors.textFaint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.tool.name,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500,
                        color: active ? AppColors.text : AppColors.textTertiary)),
                    const SizedBox(height: 2),
                    Text(widget.tool.subtitle,
                      style: GoogleFonts.inter(fontSize: 12,
                        color: active ? AppColors.textSecondary : AppColors.textFaint)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('Soon', style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textFaint)),
                )
              else
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.text,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.bg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
