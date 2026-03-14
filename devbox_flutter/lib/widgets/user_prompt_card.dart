import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_state.dart';
import '../theme/colors.dart';

class UserPromptCard extends StatelessWidget {
  final CardData card;

  const UserPromptCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(
          card.text,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.text, height: 1.5),
        ),
      ),
    );
  }
}
