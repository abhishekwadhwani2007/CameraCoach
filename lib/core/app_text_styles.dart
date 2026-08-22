import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography system for CameraCoach. All styles use the bundled Inter font.
/// Usage: Text('Hello', style: AppTextStyles.mainTitle)
class AppTextStyles {
  AppTextStyles._();

  // ── Screen Titles ─────────────────────────────────────────────────────────

  /// Home screen: "CameraCoach AI" — Inter SemiBold 28px
  static const TextStyle mainTitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.2,
  );

  /// Section / page header — Inter Medium 20px
  static const TextStyle pageTitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    height: 1.3,
  );

  /// Card header — Inter Medium 20px (same weight as pageTitle)
  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    height: 1.3,
  );

  // ── Body ──────────────────────────────────────────────────────────────────

  /// Primary body text — Inter Regular 15px
  static const TextStyle primaryBody = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.5,
  );

  /// Secondary / supporting body text — Inter Regular 13px
  static const TextStyle secondaryBody = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.5,
  );

  /// Caption / tip — Inter Regular Italic 11px
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: AppColors.tertiaryText,
    height: 1.4,
  );

  // ── Camera / Pro Mode ─────────────────────────────────────────────────────

  /// Camera setting label (ISO, SS, WB…) — Inter Medium 12px
  static const TextStyle cameraLabel = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    letterSpacing: 0.4,
  );

  /// Camera setting value (400, 1/125…) — Inter SemiBold 14px
  static const TextStyle cameraValue = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
  );

  /// Mode tab label (PHOTO / PRO / VIDEO) — Inter Medium 12px + letter-spacing
  static const TextStyle modeTab = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
  );

  // ── Buttons ───────────────────────────────────────────────────────────────

  /// Primary action button label — Inter SemiBold 16px
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
  );

  /// Secondary / subtle button text — Inter Medium 13px
  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );
}
