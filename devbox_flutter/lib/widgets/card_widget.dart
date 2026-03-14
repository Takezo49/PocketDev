import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
    );
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
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Thinking...', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        if (text.isNotEmpty) ...[
          GptMarkdown(
            text,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text, height: 1.6),
          ),
          if (isStreaming)
            Text(' \u2588', style: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.accent)),
        ],
      ],
    );
  }

  Widget _diffCard(BuildContext context) {
    final hunks = card.raw['hunks'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(card.file, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: line['type'] == 'add'
                          ? AppColors.green
                          : line['type'] == 'remove'
                              ? AppColors.red
                              : AppColors.textTertiary,
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
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.text)),
                if (card.output.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    card.output,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isStreaming)
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textTertiary))
          else
            const Icon(Icons.check, size: 14, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _approvalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        color: AppColors.accentGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPROVAL NEEDED', style: GoogleFonts.jetBrainsMono(
            fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.accent, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          SelectableText(card.prompt, style: GoogleFonts.inter(fontSize: 13, color: AppColors.text)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.mediumImpact(); onApprove(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('Allow', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.bg))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.mediumImpact(); onReject(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(child: Text('Deny', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textTertiary))),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${card.passed} passed', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.green)),
              if (card.failed > 0) ...[
                Text('  ·  ', style: GoogleFonts.inter(color: AppColors.textTertiary)),
                Text('${card.failed} failed', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.red)),
              ],
            ],
          ),
          if (card.summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(card.summary, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
      ),
      child: SelectableText(
        card.raw['message'] ?? 'Unknown error',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.red),
      ),
    );
  }
}
