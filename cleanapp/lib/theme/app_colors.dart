import 'package:flutter/material.dart';

class AppColors {
  // Main Theme Colors
  static const Color primary = Color(0xFF2196F3); // Blue
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);
  
  static const Color secondary = Color(0xFF4CAF50); // Green
  static const Color secondaryDark = Color(0xFF388E3C);
  static const Color secondaryLight = Color(0xFFC8E6C9);

  // Background and Surfaces
  static const Color background = Color(0xFFF5F7FA); // Clean off-white
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFE53935); // Red

  // Text Colors
  static const Color textPrimary = Color(0xFF263238); // Dark Grey/Blue
  static const Color textSecondary = Color(0xFF546E7A); // Medium Grey/Blue
  static const Color textHint = Color(0xFF90A4AE); // Light Grey/Blue

  // Card & Element Styling
  static const Color divider = Color(0xFFCFD8DC);
  static const Color shadow = Color(0x1F000000);

  // Advanced Gradients
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
    ],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE3F2FD),
      Color(0xFFF5F7FA),
    ],
  );
}
