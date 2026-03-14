import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/connection.dart';
import '../services/session_state.dart';
import '../widgets/card_widget.dart';
import '../widgets/session_header.dart';
import '../widgets/model_picker.dart';
import '../theme/colors.dart';

class SessionScreen extends StatefulWidget {
  final VoidCallback? onNeedsPairing;
  final VoidCallback? onBack;

  const SessionScreen({super.key, this.onNeedsPairing, this.onBack});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  String _selectedModel = 'sonnet';
  String _selectedEffort = 'high';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) {
        final atBottom = _scrollCtrl.offset >=
            _scrollCtrl.position.maxScrollExtent - 50;
        _autoScroll = atBottom;
      }
    });
  }

  void _handleSend() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    final state = context.read<SessionState>();
    if (state.activeSessionId == null) {
      state.createSession('claude');
      Future.delayed(const Duration(milliseconds: 300), () {
        state.setSessionConfig(model: _selectedModel, effort: _selectedEffort);
      });
    }
    state.sendPrompt(text);
    _inputCtrl.clear();
    _autoScroll = true;
    _scrollToBottom();
  }

  void _handleCancel() {
    HapticFeedback.mediumImpact();
    context.read<SessionState>().cancelSession();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<DevBoxConnection>();
    final state = context.watch<SessionState>();
    final paired = conn.status == ConnectionStatus.paired;
    final cardList = state.cards;
    final hasSession = state.activeSessionId != null;

    if (state.isStreaming && _autoScroll && _scrollCtrl.hasClients) {
      final maxScroll = _scrollCtrl.position.maxScrollExtent;
      if (_scrollCtrl.offset < maxScroll) {
        _scrollCtrl.jumpTo(maxScroll);
      }
    }

    return Column(
      children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                GestureDetector(
                  onTap: widget.onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textTertiary),
                  ),
                ),
              const SizedBox(width: 4),
              // Tool branding + session tabs
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (state.sessions.isEmpty)
                        Row(
                          children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: AppColors.accentBg,
                              ),
                              child: const Icon(Icons.terminal_rounded, size: 11, color: AppColors.accent),
                            ),
                            const SizedBox(width: 8),
                            Text('Claude Code',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                          ],
                        )
                      else
                        ...state.sessions.map((s) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => state.setActiveSession(s.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: s.id == state.activeSessionId ? AppColors.surfaceLight : Colors.transparent,
                                    border: s.id == state.activeSessionId
                                        ? Border.all(color: AppColors.border)
                                        : null,
                                  ),
                                  child: Text(
                                    s.tool,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: s.id == state.activeSessionId ? FontWeight.w500 : FontWeight.w400,
                                      color: s.id == state.activeSessionId ? AppColors.text : AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                      GestureDetector(
                        onTap: paired ? () => state.createSession('claude') : null,
                        child: Container(
                          width: 22, height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: paired ? AppColors.border : AppColors.borderSubtle, width: 0.5),
                          ),
                          child: Icon(Icons.add_rounded, size: 13,
                            color: paired ? AppColors.textTertiary : AppColors.textFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Connection dot
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: paired ? AppColors.accent : (conn.status == ConnectionStatus.connecting ? AppColors.textTertiary : AppColors.red),
                ),
              ),
              GestureDetector(
                onTap: paired ? () => showModelPicker(context, state) : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.tune_rounded, size: 18, color: paired ? AppColors.textTertiary : AppColors.textFaint),
                ),
              ),
            ],
          ),
        ),

        // Session header
        if (hasSession)
          SessionHeader(state: state, onModelTap: () => showModelPicker(context, state)),

        if (state.contextUsedRatio > 0)
          ContextBar(ratio: state.contextUsedRatio),

        // Content
        Expanded(
          child: hasSession && cardList.isNotEmpty
              ? ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: cardList.length,
                  itemBuilder: (_, i) => CardWidget(
                    card: cardList[i],
                    onApprove: () => state.sendApproval(true),
                    onReject: () => state.sendApproval(false),
                  ),
                )
              : _buildEmptyState(paired, state),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    enabled: paired,
                    maxLines: 4,
                    minLines: 1,
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: paired ? 'What do you want to build?' : 'Not connected',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                state.isStreaming
                    ? GestureDetector(
                        onTap: _handleCancel,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.stop_rounded, color: AppColors.red, size: 18),
                        ),
                      )
                    : GestureDetector(
                        onTap: paired ? _handleSend : null,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: paired ? AppColors.accent : AppColors.surfaceLight,
                          ),
                          child: Icon(Icons.arrow_upward_rounded,
                              color: paired ? AppColors.bg : AppColors.textFaint, size: 18),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool paired, SessionState state) {
    if (!paired) {
      return GestureDetector(
        onTap: widget.onNeedsPairing,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.link_off_rounded, size: 20, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 14),
              Text('Not connected', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary)),
              const SizedBox(height: 4),
              Text('Tap to reconnect', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textFaint)),
            ],
          ),
        ),
      );
    }

    return DotGridBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Terminal icon with glow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.accentBg,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.terminal_rounded, size: 24, color: AppColors.accent),
              ),
            ),

            const SizedBox(height: 20),

            Text('New Session',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w300, color: AppColors.text, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text('Configure and start coding',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary)),

            const SizedBox(height: 28),

            CustomPaint(
              size: const Size(double.infinity, 1),
              painter: DashedLinePainter(color: AppColors.border),
            ),

            const SizedBox(height: 24),

            // Model
            Align(
              alignment: Alignment.centerLeft,
              child: Text('MODEL', style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _chip('Opus', 'opus', _selectedModel == 'opus'),
                const SizedBox(width: 8),
                _chip('Sonnet', 'sonnet', _selectedModel == 'sonnet'),
                const SizedBox(width: 8),
                _chip('Haiku', 'haiku', _selectedModel == 'haiku'),
              ],
            ),

            const SizedBox(height: 24),

            // Effort
            Align(
              alignment: Alignment.centerLeft,
              child: Text('EFFORT', style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _chip('Low', 'low', _selectedEffort == 'low', isEffort: true),
                const SizedBox(width: 8),
                _chip('Medium', 'medium', _selectedEffort == 'medium', isEffort: true),
                const SizedBox(width: 8),
                _chip('High', 'high', _selectedEffort == 'high', isEffort: true),
              ],
            ),

            const SizedBox(height: 28),

            CustomPaint(
              size: const Size(double.infinity, 1),
              painter: DashedLinePainter(color: AppColors.border),
            ),

            const SizedBox(height: 20),

            // Config summary
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_selectedModel[0].toUpperCase() + _selectedModel.substring(1),
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.accent)),
                Text('  ·  ', style: GoogleFonts.inter(color: AppColors.textFaint)),
                Text('${_selectedEffort[0].toUpperCase()}${_selectedEffort.substring(1)} effort',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),

            const SizedBox(height: 20),

            // Start session
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                state.createSession('claude');
                Future.delayed(const Duration(milliseconds: 300), () {
                  state.setSessionConfig(model: _selectedModel, effort: _selectedEffort);
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.text,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('Start session', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.bg)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, bool selected, {bool isEffort = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (isEffort) {
              _selectedEffort = value;
            } else {
              _selectedModel = value;
            }
          });
          final state = context.read<SessionState>();
          if (state.activeSessionId != null) {
            if (isEffort) {
              state.setSessionConfig(effort: value);
            } else {
              state.setSessionConfig(model: value);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.text : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.text : AppColors.border,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.bg : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
