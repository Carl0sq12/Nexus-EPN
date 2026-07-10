import 'package:flutter/material.dart';

/// Colores de la paleta "Coastal Wave" y gradiente primario.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF0FFFE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF1D6FA4);
  static const Color primaryMid = Color(0xFF2EC4B6);
  static const Color primaryLight = Color(0xFFA8EDEA);
  static const Color primarySoft = Color(0xFFedf4ff);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF0a1d2d);
  static const Color secondary = Color(0xFF4A7A85);
  static const Color outline = Color(0xFFc0c7d0);
  static const Color outlineVariant = Color(0xFFe3efff);
  static const Color error = Color(0xFFba1a1a);
  static const Color success = Color(0xFF2EC4B6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color textSecondary = Color(0xFF4a6b7d);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryMid, primaryLight],
  );
}
