import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class AppColors {
  // Backgrounds — true black
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const surfaceLight = Color(0xFF141414);
  static const surfaceElevated = Color(0xFF1A1A1A);
  static const border = Color(0xFF262626);

  // Text — white
  static const text = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA0A0A0);
  static const textMuted = Color(0xFF666666);

  // Single accent
  static const accent = Color(0xFFFFFFFF);
  static const accentLight = Color(0xFFE0E0E0);
  static const accentBlue = Color(0xFF666666);

  // Status — muted, only when needed
  static const green = Color(0xFF4ADE80);
  static const red = Color(0xFFF87171);
  static const yellow = Color(0xFFFACC15);
  static const purple = Color(0xFFA78BFA);
}

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.text,
    secondary: AppColors.textSecondary,
    error: AppColors.red,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.bg,
    elevation: 0,
  ),
  fontFamily: 'sans-serif',
  extensions: [
    GptMarkdownThemeData(
      brightness: Brightness.dark,
      h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.3),
      h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.3),
      h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
      h4: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
      h5: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
      h6: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.3),
      linkColor: AppColors.textSecondary,
      highlightColor: AppColors.surfaceLight,
      hrLineColor: AppColors.border,
      hrLineThickness: 1.0,
    ),
  ],
);
