import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        // Connection banner
        if (!paired)
          GestureDetector(
            onTap: widget.onNeedsPairing,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: conn.status == ConnectionStatus.connecting
                          ? AppColors.textMuted
                          : AppColors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    conn.status == ConnectionStatus.connecting
                        ? 'Connecting...'
                        : 'Not connected',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),

        // Top bar: back + sessions + settings
        Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                GestureDetector(
                  onTap: widget.onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textSecondary),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...state.sessions.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => state.setActiveSession(s.id),
                              child: Text(
                                s.tool,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: s.id == state.activeSessionId ? FontWeight.w600 : FontWeight.w400,
                                  color: s.id == state.activeSessionId ? AppColors.text : AppColors.textMuted,
                                ),
                              ),
                            ),
                          )),
                      GestureDetector(
                        onTap: paired ? () => state.createSession('claude') : null,
                        child: Text('+',
                            style: TextStyle(fontSize: 18, color: paired ? AppColors.text : AppColors.textMuted)),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: paired ? () => showModelPicker(context, state) : null,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.tune_rounded, size: 20, color: paired ? AppColors.textSecondary : AppColors.textMuted),
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
                    style: const TextStyle(fontSize: 15, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.textMuted),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.stop_rounded, color: AppColors.text, size: 20),
                        ),
                      )
                    : GestureDetector(
                        onTap: paired ? _handleSend : null,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: paired ? AppColors.text : AppColors.surfaceLight,
                          ),
                          child: Icon(Icons.arrow_upward_rounded,
                              color: paired ? AppColors.bg : AppColors.textMuted, size: 20),
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
                width: 52, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.link_off_rounded, size: 24, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              const Text('Not connected', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              const Text('Tap to reconnect', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text('Claude Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text('What do you want to build?', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),

          const SizedBox(height: 40),

          // Model
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('MODEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
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
          ).animate().fadeIn(delay: 100.ms, duration: 200.ms),

          const SizedBox(height: 24),

          // Effort
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('EFFORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
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
          ).animate().fadeIn(delay: 200.ms, duration: 200.ms),

          const SizedBox(height: 40),

          // Quick actions
          _action('New session', () {
            HapticFeedback.lightImpact();
            state.createSession('claude');
            Future.delayed(const Duration(milliseconds: 300), () {
              state.setSessionConfig(model: _selectedModel, effort: _selectedEffort);
            });
          }),
        ].animate(interval: 30.ms).fadeIn(duration: 150.ms),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.text : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.text : AppColors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.bg : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.bg)),
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
