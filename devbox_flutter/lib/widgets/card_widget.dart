import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../services/session_state.dart';
import '../theme/colors.dart';
import 'tool_result_card.dart';
import 'user_prompt_card.dart';

class CardWidget extends StatelessWidget {
  final CardData card;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const CardWidget({
    super.key,
    required this.card,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: _buildCard(context),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildCard(BuildContext context) {
    switch (card.type) {
      case 'message':
        return _messageCard(context);
      case 'diff':
        return _diffCard(context);
      case 'command':
        return _commandCard(context);
      case 'approval':
        return _approvalCard(context);
      case 'test':
        return _testCard(context);
      case 'error':
        return _errorCard(context);
      case 'tool_result':
        return ToolResultCard(card: card);
      case 'user_prompt':
        return UserPromptCard(card: card);
      default:
        return _messageCard(context);
    }
  }

  Widget _messageCard(BuildContext context) {
    final isStreaming = card.raw['streaming'] == true;
    final text = card.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStreaming && text.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Thinking...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        if (text.isNotEmpty) ...[
          // Render markdown properly
          GptMarkdown(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5),
          ),
          if (isStreaming)
            const Text(' \u2588', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ],
      ],
    );
  }

  Widget _diffCard(BuildContext context) {
    final hunks = card.raw['hunks'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(card.file, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'monospace')),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final hunk in hunks)
                for (final line in (hunk['lines'] as List? ?? []))
                  SelectableText(
                    '${line['type'] == 'add' ? '+' : line['type'] == 'remove' ? '-' : ' '} ${line['content']}',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: line['type'] == 'add'
                          ? AppColors.green
                          : line['type'] == 'remove'
                              ? AppColors.red
                              : AppColors.textMuted,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commandCard(BuildContext context) {
    final isStreaming = card.raw['streaming'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.command,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                if (card.output.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    card.output,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isStreaming)
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textMuted))
          else
            const Icon(Icons.check, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _approvalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval needed', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          SelectableText(card.prompt, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.mediumImpact(); onApprove(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Text('Allow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.bg))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.mediumImpact(); onReject(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(child: Text('Deny', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _testCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${card.passed} passed', style: const TextStyle(fontSize: 13, color: AppColors.green)),
              if (card.failed > 0) ...[
                const Text('  ·  ', style: TextStyle(color: AppColors.textMuted)),
                Text('${card.failed} failed', style: const TextStyle(fontSize: 13, color: AppColors.red)),
              ],
            ],
          ),
          if (card.summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(card.summary, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: SelectableText(
        card.raw['message'] ?? 'Unknown error',
        style: const TextStyle(fontSize: 14, color: AppColors.red),
      ),
    );
  }
}
