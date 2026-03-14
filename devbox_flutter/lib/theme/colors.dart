import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class AppColors {
  // Backgrounds — matches landing page #05080A
  static const bg = Color(0xFF05080A);
  static const surface = Color(0xFF0B0E14);       // white ~2%
  static const surfaceLight = Color(0xFF111620);   // white ~5%
  static const surfaceElevated = Color(0xFF171C28); // white ~8%
  static const border = Color(0xFF1C2130);         // white ~10%
  static const borderSubtle = Color(0xFF12151E);   // white ~5%

  // Text — white at opacity levels (landing page style)
  static const text = Color(0xFFFFFFFF);           // white
  static const textSecondary = Color(0xFFB3B3B3);  // white/70
  static const textMuted = Color(0xFF999999);      // white/60
  static const textTertiary = Color(0xFF666666);   // white/40
  static const textFaint = Color(0xFF4D4D4D);      // white/30

  // Accent — lime green (same as landing)
  static const accent = Color(0xFFC6F91F);
  static const accentDim = Color(0xFF9AC415);
  static const accentBg = Color(0x19C6F91F);       // 10%
  static const accentGlow = Color(0x14C6F91F);     // ~8%

  // Status — muted, only when needed
  static const green = Color(0xFF4ADE80);
  static const red = Color(0xFFF87171);
  static const yellow = Color(0xFFFACC15);
  static const purple = Color(0xFFA78BFA);
}

/// Subtle dot grid background matching landing page
class DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    const radius = 0.8;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dashed horizontal line painter
class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const dashWidth = 4.0;
    const gapWidth = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + dashWidth, size.width), 0), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wraps a child with the dot grid background
class DotGridBackground extends StatelessWidget {
  final Widget child;
  const DotGridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
        child,
      ],
    );
  }
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
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  fontFamily: GoogleFonts.inter().fontFamily,
  extensions: [
    GptMarkdownThemeData(
      brightness: Brightness.dark,
      h1: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
      h2: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
      h3: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.3),
      h4: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.3),
      h5: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.3),
      h6: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.3),
      linkColor: AppColors.accent,
      highlightColor: AppColors.surfaceLight,
      hrLineColor: AppColors.border,
      hrLineThickness: 1.0,
    ),
  ],
);
