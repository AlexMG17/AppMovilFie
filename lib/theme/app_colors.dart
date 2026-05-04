import 'package:flutter/material.dart';

/// Paleta de colores oficial de la aplicación Sentry.
/// Usar siempre estas constantes en lugar de valores hardcodeados.
class AppColors {
  AppColors._(); // no instanciable

  // ── Paleta principal ────────────────────────────────────────────
  static const Color sentryNavy = Color(0xFF0D2B6B); // Azul oscuro
  static const Color sentryBlue = Color(0xFF1565C0); // Azul medio
  static const Color sentryCyan = Color(0xFF29B6F6); // Celeste claro
  static const Color sentryGrey = Color(0xFF8FA3B1); // Gris azulado
  static const Color sentryBg   = Color(0xFFEDF2F7); // Fondo gris muy claro

  // ── Colores semánticos derivados ────────────────────────────────
  /// Texto principal sobre fondos claros
  static const Color textPrimary   = sentryNavy;
  /// Texto secundario / subtítulos
  static const Color textSecondary = sentryGrey;
  /// Fondo general de la app
  static const Color background    = sentryBg;
  /// Color de acento / interactivo principal
  static const Color accent        = sentryCyan;

  // ── Colores de estado (se mantienen neutros para el dashboard) ──
  static const Color success = Color(0xFF22C55E); // verde
  static const Color warning = Color(0xFFF59E0B); // amarillo
  static const Color error   = Color(0xFFEF4444); // rojo

  // ── Superficie de tarjetas (light mode) ─────────────────────────
  static const Color cardBackground = Colors.white;
  static const Color cardBorder     = Color(0xFFE2E8F0);
  static const Color divider        = Color(0xFFE2E8F0);
}
