import 'package:flutter/material.dart';

/// Centralized color palette for CameraCoach.
/// All colors are referenced via these tokens — no hardcoded hex values elsewhere.
class AppColors {
  AppColors._();

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0D0F14); // Main scaffold background
  static const Color surface = Color(0xFF161A22); // Card / panel background
  static const Color lightSurface =
      Color(0xFF1F2430); // Controls (ISO/SS circles)
  static const Color border = Color(0xFF2A2F3C); // Subtle separator

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color primaryText = Color(0xFFF5F6F7);
  static const Color secondaryText = Color(0xFFA1A6B2);
  static const Color tertiaryText = Color(0xFF6B7280);
  static const Color disabledText = Color(0xFF3A3F4B);

  // ── Silver Gradient (Start Coaching button + shutter) ────────────────────
  static const Color silverTop = Color(0xFFF2F2F4);
  static const Color silverMid = Color(0xFFC8C9CE);
  static const Color silverBot = Color(0xFFA5A7AD);

  // ── Brand Accents ─────────────────────────────────────────────────────────
  static const Color yellow = Color(0xFFFFC107); // PRO mode / zoom / grid
  static const Color green = Color(0xFF22C55E); // Done / success
  static const Color aiGlow = Color(0xFFFFF6CC); // AI pose outline glow

  // ── Functional States ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}
