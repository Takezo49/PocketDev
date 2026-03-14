import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_state.dart';
import '../theme/colors.dart';

class SessionHeader extends StatelessWidget {
  final SessionState state;
  final VoidCallback onModelTap;

  const SessionHeader({
    super.key,
    required this.state,
    required this.onModelTap,
  });

  @override
  Widget build(BuildContext context) {
    final model = state.currentModel;
    final cost = state.cumulativeCost;
    final effort = state.currentEffort;
    final queue = state.queueLength;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          if (model.isNotEmpty)
            GestureDetector(
              onTap: onModelTap,
              child: Text(
                _formatModel(model),
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.accent),
              ),
            ),
          if (effort.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(effort, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textTertiary)),
          ],
          if (queue > 0) ...[
            const SizedBox(width: 12),
            Text('$queue queued', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textTertiary)),
          ],
          const Spacer(),
          if (cost > 0)
            Text(
              '\$${cost.toStringAsFixed(4)}',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }

  String _formatModel(String model) {
    if (model.contains('opus')) return 'Opus';
    if (model.contains('sonnet')) return 'Sonnet';
    if (model.contains('haiku')) return 'Haiku';
    return model;
  }
}

class ContextBar extends StatelessWidget {
  final double ratio;

  const ContextBar({super.key, required this.ratio});

  @override
  Widget build(BuildContext context) {
    if (ratio <= 0) return const SizedBox.shrink();

    return Container(
      height: 2,
      color: AppColors.border,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio.clamp(0, 1),
        child: Container(color: AppColors.accent),
      ),
    );
  }
}
