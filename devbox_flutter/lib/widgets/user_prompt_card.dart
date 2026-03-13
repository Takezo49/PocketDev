import 'package:flutter/material.dart';
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
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(
          card.text,
          style: const TextStyle(fontSize: 15, color: AppColors.text, height: 1.5),
        ),
      ),
    );
  }
}
