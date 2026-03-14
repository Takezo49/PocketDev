import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_state.dart';
import '../theme/colors.dart';

class ToolResultCard extends StatefulWidget {
  final CardData card;

  const ToolResultCard({super.key, required this.card});

  @override
  State<ToolResultCard> createState() => _ToolResultCardState();
}

class _ToolResultCardState extends State<ToolResultCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.card.contentType == 'diff';
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.card.content;
    final hasContent = content.isNotEmpty;
    final lineCount = content.split('\n').length;
    final preview = content.length > 200 ? '${content.substring(0, 200)}...' : content;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: hasContent ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.card.toolName,
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                  ),
                  if (hasContent) ...[
                    Text('$lineCount lines', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textTertiary)),
                    const SizedBox(width: 4),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: AppColors.textTertiary),
                  ],
                ],
              ),
            ),
          ),

          // Preview when collapsed
          if (hasContent && !_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textTertiary, height: 1.3),
              ),
            ),

          // Full content when expanded
          if (hasContent && _expanded) ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: widget.card.contentType == 'diff'
                      ? _diffContent(content)
                      : _plainContent(content),
                ),
              ),
            ),
            // Copy button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: content));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied', style: GoogleFonts.inter(color: AppColors.text, fontSize: 12)),
                      backgroundColor: AppColors.surfaceLight,
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  );
                },
                child: Text('Copy', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _diffContent(String content) {
    final lines = content.split('\n');
    int lineNum = 0;

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final isHeader = line.startsWith('---') || line.startsWith('+++');
          if (!isHeader) lineNum++;

          Color color;
          Color? bgColor;
          if (isHeader) {
            color = AppColors.textSecondary;
          } else if (line.startsWith('+')) {
            color = AppColors.green;
            bgColor = AppColors.green.withValues(alpha: 0.06);
          } else if (line.startsWith('-')) {
            color = AppColors.red;
            bgColor = AppColors.red.withValues(alpha: 0.06);
          } else {
            color = AppColors.textTertiary;
          }

          final numStr = isHeader ? '   ' : '${lineNum}'.padLeft(3);

          return Container(
            color: bgColor,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(numStr,
                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppColors.textFaint, height: 1.4)),
                ),
                const SizedBox(width: 4),
                Text(line,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: color, height: 1.4),
                  softWrap: false,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _plainContent(String content) {
    final lines = content.split('\n');

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines.length, (i) {
          final numStr = '${i + 1}'.padLeft(3);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(numStr,
                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppColors.textFaint, height: 1.4)),
                ),
                const SizedBox(width: 4),
                Text(lines[i],
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.text, height: 1.4),
                  softWrap: false,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
